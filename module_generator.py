import json
import os
from pathlib import Path
from typing import Optional

from openai import OpenAI
from dotenv import load_dotenv

from json_utils import parse_llm_json
from scad_builder import build_scad
from scad_render import render_to_png

load_dotenv()

_client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.getenv("OPENROUTER_API_KEY"),
)
_model = os.getenv("OPENROUTER_MODEL", "minimax/minimax-m3")

_prompt_path = Path(__file__).parent / "prompts" / "module_generation.txt"


def _load_prompt() -> str:
    with open(_prompt_path, "r", encoding="utf-8") as f:
        return f.read()


def _call_llm_for_modules(analysis: dict) -> Optional[str]:
    system_prompt = _load_prompt()
    response = _client.chat.completions.create(
        model=_model,
        messages=[
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": f"RING ANALYSIS JSON:\n{json.dumps(analysis, indent=2)}",
            },
        ],
        temperature=0.1,
    )
    raw = response.choices[0].message.content
    result = parse_llm_json(raw)
    if not isinstance(result, dict):
        return None
    scad_code = result.get("scad_code")
    return scad_code if isinstance(scad_code, str) and scad_code.strip() else None


def build_scad_via_llm(analysis: dict, *, workdir: Optional[Path] = None) -> tuple[str, str]:
    """Tries LLM-authored module generation first; falls back to the
    deterministic scad_builder.build_scad() if the LLM call fails, its
    response doesn't parse, or the resulting code fails to render.

    Returns (scad_code, source) where source is "llm" or "fallback_deterministic".
    Any failure in the LLM path (network error, bad JSON, failed render) is
    swallowed and the deterministic builder is used instead -- which is
    itself tested to never raise, so this function doesn't raise either in
    practice."""
    workdir = workdir or Path("output") / "_module_gen_tmp"

    try:
        scad_code = _call_llm_for_modules(analysis)
        if not scad_code:
            raise ValueError("LLM response missing scad_code")

        render = render_to_png(scad_code, workdir=workdir, basename="llm_module_check")
        if not render.success:
            raise ValueError(f"LLM-generated SCAD failed to render: {render.stderr}")

        return scad_code, "llm"
    except Exception:
        return build_scad(analysis), "fallback_deterministic"
