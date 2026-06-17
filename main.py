import json
import os
import uuid
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

from extractor import extract
from scad_builder import build_scad
from generator import refine

load_dotenv()

app = FastAPI(title="Jewel-AI", description="Ring image → OpenSCAD code pipeline")

OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
REFINE_MAX_ROUNDS = int(os.getenv("REFINE_MAX_ROUNDS", "3"))


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
    run_dir = OUTPUT_DIR / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    try:
        analysis = extract(image_bytes, image.content_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"VLM extraction failed: {e}")

    try:
        draft_scad = build_scad(analysis)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Procedural SCAD build failed: {e}")

    draft_path = run_dir / "draft.scad"
    draft_path.write_text(draft_scad, encoding="utf-8")

    try:
        result = refine(
            analysis,
            draft_scad,
            image_bytes,
            image.content_type,
            max_rounds=REFINE_MAX_ROUNDS,
            run_id=run_id,
            artifacts_dir=run_dir,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Refine pass failed: {e}")

    analysis_path = run_dir / "analysis.json"
    scad_path = run_dir / "ring.scad"
    preview_path = run_dir / "ring_preview.png"

    analysis_path.write_text(json.dumps(result.analysis, indent=2), encoding="utf-8")
    scad_path.write_text(result.scad_code, encoding="utf-8")

    saved_preview_png = None
    if result.final_png:
        preview_path.write_bytes(result.final_png)
        saved_preview_png = str(preview_path)

    return JSONResponse(
        content={
            "run_id": run_id,
            "status": result.status,
            "rounds_used": len(result.rounds),
            "analysis": result.analysis,
            "scad_code": result.scad_code,
            "saved_analysis": str(analysis_path),
            "saved_scad": str(scad_path),
            "saved_preview_png": saved_preview_png,
            "saved_draft_scad": str(draft_path),
        }
    )


@app.get("/health")
async def health():
    return {"status": "ok"}
