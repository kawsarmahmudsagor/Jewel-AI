import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from openai import OpenAI
from dotenv import load_dotenv

from json_utils import parse_llm_json
from image_utils import encode_image_data_url
from scad_render import RenderResult, render_to_png, render_named_angles, photo_matching_camera_eye

load_dotenv()

_client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.getenv("OPENROUTER_API_KEY"),
)
_model = os.getenv("OPENROUTER_MODEL", "minimax/minimax-m3")

_prompt_path = Path(__file__).parent / "prompts" / "generation.txt"


def _load_prompt() -> str:
    with open(_prompt_path, "r", encoding="utf-8") as f:
        return f.read()


@dataclass
class RoundLog:
    round_number: int
    kind: str  # "fix_error" | "visual_critique"
    scad_code: str
    render: RenderResult
    llm_status: Optional[str] = None
    notes: Optional[str] = None
    checklist: Optional[dict] = None


def _checklist_passed(checklist) -> bool:
    """A missing/empty/non-dict checklist counts as NOT passed -- fail
    toward more iteration rather than trusting an unverifiable claim."""
    if not isinstance(checklist, dict) or not checklist:
        return False
    return all(bool(v) for v in checklist.values())


@dataclass
class RefineResult:
    analysis: dict
    scad_code: str
    final_png: Optional[bytes]
    rounds: list[RoundLog]
    status: str  # "accepted" | "cap_reached" | "no_successful_render"


def _merge_section_9(analysis: dict, section_9: Optional[dict]) -> dict:
    if section_9:
        analysis.setdefault("expertAnalysisQuestionnaire", {}).setdefault("sections", {})[
            "9_cadReconstructionParameters"
        ] = section_9
    return analysis


def _call_llm(system_prompt: str, user_content: list) -> dict:
    response = _client.chat.completions.create(
        model=_model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ],
        temperature=0.1,
    )
    raw = response.choices[0].message.content
    try:
        result = parse_llm_json(raw)
    except ValueError:
        # A response that's unparseable even after parse_llm_json's own
        # recovery attempts must not crash the whole request -- an empty
        # dict here flows into the same "missing status/checklist defaults
        # to revise" fallback every other caller already handles.
        return {}
    return result if isinstance(result, dict) else {}


def _call_llm_fix_error(
    system_prompt: str,
    analysis: dict,
    scad_code: str,
    stderr: str,
    image_bytes: bytes,
    content_type: str,
) -> dict:
    photo_url = encode_image_data_url(image_bytes, content_type)
    user_content = [
        {
            "type": "text",
            "text": (
                "The procedurally-generated OpenSCAD draft below FAILED TO RENDER. Fix the "
                "syntax/logic error so it renders, while keeping it faithful to the attached "
                "reference photo.\n\n"
                f"OPENSCAD ERROR OUTPUT:\n{stderr}\n\n"
                f"DRAFT SCAD CODE:\n{scad_code}\n\n"
                f"RING ANALYSIS JSON:\n{json.dumps(analysis, indent=2)}"
            ),
        },
        {"type": "image_url", "image_url": {"url": photo_url}},
    ]
    return _call_llm(system_prompt, user_content)


_ANGLE_LABELS = {
    "matching_photo_angle": "RENDERED PREVIEW -- camera angle matching the reference photo (primary comparison)",
    "top": "RENDERED PREVIEW -- top view",
    "front": "RENDERED PREVIEW -- front view",
    "left": "RENDERED PREVIEW -- left view",
}


def _call_llm_visual_critique(
    system_prompt: str,
    analysis: dict,
    scad_code: str,
    angle_images: dict[str, bytes],
    image_bytes: bytes,
    content_type: str,
) -> dict:
    photo_url = encode_image_data_url(image_bytes, content_type)
    user_content = [
        {
            "type": "text",
            "text": (
                "The procedurally-generated OpenSCAD draft below rendered successfully. You are "
                "shown it from multiple camera angles -- one matching the reference photo's own "
                "angle (the primary comparison) plus top/front/left for additional coverage (a "
                "ring is symmetric enough that back/right add little over their mirror "
                "counterparts), since some defects (floating geometry, a stone buried in the "
                "band, asymmetric prongs) are invisible from a single angle. Compare all of them "
                "against the REFERENCE PHOTO and decide whether the draft is faithful enough to "
                "ship, or needs revision.\n\n"
                f"DRAFT SCAD CODE:\n{scad_code}\n\n"
                f"RING ANALYSIS JSON:\n{json.dumps(analysis, indent=2)}"
            ),
        },
    ]
    for name, png_bytes in angle_images.items():
        label = _ANGLE_LABELS.get(name, f"RENDERED PREVIEW -- {name} view")
        user_content.append({"type": "text", "text": f"{label}:"})
        user_content.append(
            {"type": "image_url", "image_url": {"url": encode_image_data_url(png_bytes, "image/png")}}
        )
    user_content.append({"type": "text", "text": "REFERENCE PHOTO (ground truth):"})
    user_content.append({"type": "image_url", "image_url": {"url": photo_url}})
    return _call_llm(system_prompt, user_content)


def refine(
    analysis: dict,
    procedural_scad: str,
    image_bytes: bytes,
    content_type: str,
    *,
    max_rounds: int = 3,
    min_rounds: int = 1,
    run_id: Optional[str] = None,
    artifacts_dir: Optional[Path] = None,
) -> RefineResult:
    """Render -> fix-error or visual-critique -> loop, capped at max_rounds shared
    across both round kinds. Always returns the last successfully-rendered version
    if the cap is hit without acceptance; never raises on LLM/render failure.

    "final" is only honored once TWO things hold, both decided in code rather
    than trusted from the LLM's word alone: every item in the LLM's own
    checklist is true (see _checklist_passed), AND at least min_rounds
    visual-critique rounds have happened. A round where the LLM claims
    "final" before min_rounds is reached is forced back to "revise" --
    same scad_code, but it gets looked at again rather than accepted on
    the first glance."""
    system_prompt = _load_prompt()
    artifacts_dir = artifacts_dir or Path("output") / (run_id or "tmp")
    photo_context = analysis.get("photoContext") if isinstance(analysis, dict) else None
    matching_eye = photo_matching_camera_eye(photo_context)

    current_scad = procedural_scad
    rounds: list[RoundLog] = []
    last_good_scad: Optional[str] = None
    last_good_png: Optional[bytes] = None
    last_section_9: Optional[dict] = None
    visual_critique_count = 0

    for round_number in range(1, max_rounds + 1):
        render = render_to_png(
            current_scad,
            workdir=artifacts_dir,
            basename=f"round_{round_number}",
            camera_eye=matching_eye,
        )

        if not render.success:
            result = _call_llm_fix_error(
                system_prompt, analysis, current_scad, render.stderr, image_bytes, content_type
            )
            current_scad = result.get("scad_code") or current_scad
            last_section_9 = result.get("section_9") or last_section_9
            rounds.append(
                RoundLog(
                    round_number=round_number,
                    kind="fix_error",
                    scad_code=current_scad,
                    render=render,
                    llm_status=result.get("status"),
                    notes=result.get("notes"),
                )
            )
            continue

        last_good_scad = current_scad
        last_good_png = render.png_bytes

        secondary_renders = render_named_angles(
            current_scad, workdir=artifacts_dir, basename_prefix=f"round_{round_number}"
        )
        angle_images = {"matching_photo_angle": render.png_bytes}
        for name, secondary in secondary_renders.items():
            if secondary.success and secondary.png_bytes:
                angle_images[name] = secondary.png_bytes

        result = _call_llm_visual_critique(
            system_prompt, analysis, current_scad, angle_images, image_bytes, content_type
        )
        visual_critique_count += 1
        raw_status = result.get("status") if result.get("status") in ("final", "revise") else "revise"
        checklist = result.get("checklist")
        checklist_passed = _checklist_passed(checklist)
        status = (
            "final"
            if (raw_status == "final" and checklist_passed and visual_critique_count >= min_rounds)
            else "revise"
        )
        last_section_9 = result.get("section_9") or last_section_9

        rounds.append(
            RoundLog(
                round_number=round_number,
                kind="visual_critique",
                scad_code=current_scad,
                render=render,
                llm_status=status,
                notes=result.get("notes"),
                checklist=checklist,
            )
        )

        if status == "final":
            analysis = _merge_section_9(analysis, last_section_9)
            return RefineResult(
                analysis=analysis,
                scad_code=current_scad,
                final_png=render.png_bytes,
                rounds=rounds,
                status="accepted",
            )

        current_scad = result.get("scad_code") or current_scad

    analysis = _merge_section_9(analysis, last_section_9)
    if last_good_scad is not None:
        return RefineResult(
            analysis=analysis,
            scad_code=last_good_scad,
            final_png=last_good_png,
            rounds=rounds,
            status="cap_reached",
        )
    return RefineResult(
        analysis=analysis,
        scad_code=current_scad,
        final_png=None,
        rounds=rounds,
        status="no_successful_render",
    )
