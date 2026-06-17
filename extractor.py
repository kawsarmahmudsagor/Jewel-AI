import base64
import json
import os
from pathlib import Path

from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

_client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.getenv("OPENROUTER_API_KEY"),
)
_model = os.getenv("OPENROUTER_MODEL", "minimax/minimax-m3")

_schema_path = Path(__file__).parent / "schema" / "questionnaire.json"
_prompt_path = Path(__file__).parent / "prompts" / "extraction.txt"


def _load_schema() -> dict:
    with open(_schema_path, "r", encoding="utf-8") as f:
        return json.load(f)


def _load_prompt() -> str:
    with open(_prompt_path, "r", encoding="utf-8") as f:
        return f.read()


def _encode_image(image_bytes: bytes, content_type: str) -> str:
    encoded = base64.b64encode(image_bytes).decode("utf-8")
    return f"data:{content_type};base64,{encoded}"


def extract(image_bytes: bytes, content_type: str) -> dict:
    schema = _load_schema()
    system_prompt = _load_prompt()
    image_url = _encode_image(image_bytes, content_type)

    response = _client.chat.completions.create(
        model=_model,
        messages=[
            {
                "role": "system",
                "content": system_prompt,
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": (
                            "Analyze this ring image and fill sections 1 through 8 of the schema below.\n\n"
                            f"SCHEMA:\n{json.dumps(schema, indent=2)}"
                        ),
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": image_url},
                    },
                ],
            },
        ],
        temperature=0.2,
    )

    raw = response.choices[0].message.content.strip()

    # strip markdown code fences if the model wraps the response
    if raw.startswith("```"):
        lines = raw.splitlines()
        raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])

    return json.loads(raw)
