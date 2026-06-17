import json
import os
from pathlib import Path
from typing import Tuple

from openai import OpenAI
from dotenv import load_dotenv

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


def generate(analysis: dict) -> Tuple[dict, str]:
    """
    Takes the filled analysis JSON (sections 1-8) and returns
    (updated_analysis_with_section_9, scad_code_string).
    """
    system_prompt = _load_prompt()

    response = _client.chat.completions.create(
        model=_model,
        messages=[
            {
                "role": "system",
                "content": system_prompt,
            },
            {
                "role": "user",
                "content": (
                    "Here is the ring analysis JSON with sections 1–8 filled.\n"
                    "Fill section 9 and generate the OpenSCAD code.\n\n"
                    f"ANALYSIS:\n{json.dumps(analysis, indent=2)}"
                ),
            },
        ],
        temperature=0.1,
    )

    raw = response.choices[0].message.content.strip()

    # strip markdown code fences if the model wraps the response
    if raw.startswith("```"):
        lines = raw.splitlines()
        raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])

    result = json.loads(raw)

    section_9 = result.get("section_9", {})
    scad_code = result.get("scad_code", "")

    # merge section 9 into the analysis
    analysis.setdefault("expertAnalysisQuestionnaire", {}).setdefault("sections", {})[
        "9_cadReconstructionParameters"
    ] = section_9

    return analysis, scad_code
