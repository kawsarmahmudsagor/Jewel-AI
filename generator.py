import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from openai import OpenAI
from dotenv import load_dotenv

from json_utils import parse_llm_json
from image_utils import encode_image_data_url
from scad_render import RenderResult, render_to_png

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
    result = parse_llm_json(raw)
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


def _call_llm_visual_critique(
    system_prompt: str,
    analysis: dict,
    scad_code: str,
    render_png: bytes,
    image_bytes: bytes,
    content_type: str,
) -> dict:
    render_url = encode_image_data_url(render_png, "image/png")
    photo_url = encode_image_data_url(image_bytes, content_type)
    user_content = [
        {
            "type": "text",
            "text": (
                "The procedurally-generated OpenSCAD draft below rendered successfully. Compare "
                "the RENDERED PREVIEW against the REFERENCE PHOTO and decide whether it is "
                "faithful enough to ship, or needs revision.\n\n"
                f"DRAFT SCAD CODE:\n{scad_code}\n\n"
                f"RING ANALYSIS JSON:\n{json.dumps(analysis, indent=2)}"
            ),
        },
        {"type": "text", "text": "RENDERED PREVIEW (from the draft SCAD):"},
        {"type": "image_url", "image_url": {"url": render_url}},
        {"type": "text", "text": "REFERENCE PHOTO (ground truth):"},
        {"type": "image_url", "image_url": {"url": photo_url}},
    ]
    return _call_llm(system_prompt, user_content)


def refine(
    analysis: dict,
    procedural_scad: str,
    image_bytes: bytes,
    content_type: str,
    *,
    max_rounds: int = 3,
    run_id: Optional[str] = None,
    artifacts_dir: Optional[Path] = None,
) -> RefineResult:
    """Render -> fix-error or visual-critique -> loop, capped at max_rounds shared
    across both round kinds. Always returns the last successfully-rendered version
    if the cap is hit without acceptance; never raises on LLM/render failure."""
    system_prompt = _load_prompt()
    artifacts_dir = artifacts_dir or Path("output") / (run_id or "tmp")

    current_scad = procedural_scad
    rounds: list[RoundLog] = []
    last_good_scad: Optional[str] = None
    last_good_png: Optional[bytes] = None
    last_section_9: Optional[dict] = None

    for round_number in range(1, max_rounds + 1):
        render = render_to_png(
            current_scad, workdir=artifacts_dir, basename=f"round_{round_number}"
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

        result = _call_llm_visual_critique(
            system_prompt, analysis, current_scad, render.png_bytes, image_bytes, content_type
        )
        status = result.get("status") if result.get("status") in ("final", "revise") else "revise"
        last_section_9 = result.get("section_9") or last_section_9

        rounds.append(
            RoundLog(
                round_number=round_number,
                kind="visual_critique",
                scad_code=current_scad,
                render=render,
                llm_status=status,
                notes=result.get("notes"),
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
