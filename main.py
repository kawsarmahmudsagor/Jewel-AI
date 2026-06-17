import json
import uuid
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

from extractor import extract
from generator import generate

load_dotenv()

app = FastAPI(title="Jewel-AI", description="Ring image → OpenSCAD code pipeline")

OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


@app.post("/generate")
async def generate_scad(image: UploadFile = File(...)):
    if image.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported image type '{image.content_type}'. Use JPEG, PNG, or WebP.",
        )

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    run_id = uuid.uuid4().hex[:8]

    try:
        analysis = extract(image_bytes, image.content_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"VLM extraction failed: {e}")

    try:
        full_analysis, scad_code = generate(analysis)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"OpenSCAD generation failed: {e}")

    analysis_path = OUTPUT_DIR / f"{run_id}_analysis.json"
    scad_path = OUTPUT_DIR / f"{run_id}_ring.scad"

    analysis_path.write_text(json.dumps(full_analysis, indent=2), encoding="utf-8")
    scad_path.write_text(scad_code, encoding="utf-8")

    return JSONResponse(
        content={
            "run_id": run_id,
            "analysis": full_analysis,
            "scad_code": scad_code,
            "saved_analysis": str(analysis_path),
            "saved_scad": str(scad_path),
        }
    )


@app.get("/health")
async def health():
    return {"status": "ok"}
