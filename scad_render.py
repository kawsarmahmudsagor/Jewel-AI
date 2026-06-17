"""OpenSCAD CLI wrapper -- renders .scad source to a PNG for the refine loop.

Never raises: timeouts, missing-binary, and non-zero exits are all surfaced
as a failed RenderResult so callers (generator.refine) can always branch
on .success without wrapping every call in try/except.
"""

import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

_DEFAULT_WINDOWS_PATH = r"C:\Program Files\OpenSCAD\openscad.exe"


@dataclass
class RenderResult:
    success: bool
    png_bytes: bytes | None
    stdout: str
    stderr: str
    exit_code: int
    scad_path: str


def find_openscad_binary() -> str:
    env_path = os.getenv("OPENSCAD_PATH")
    if env_path and Path(env_path).is_file():
        return env_path
    if Path(_DEFAULT_WINDOWS_PATH).is_file():
        return _DEFAULT_WINDOWS_PATH
    found = shutil.which("openscad")
    if found:
        return found
    raise FileNotFoundError(
        "OpenSCAD binary not found. Set OPENSCAD_PATH or install OpenSCAD."
    )


def render_to_png(
    scad_code: str,
    *,
    imgsize: tuple[int, int] = (800, 800),
    render_mode: str | None = None,
    timeout: int = 60,
    workdir: Path | None = None,
    basename: str = "render",
) -> RenderResult:
    render_mode = render_mode or os.getenv("OPENSCAD_RENDER_MODE", "render")
    workdir = workdir or Path(".")
    workdir.mkdir(parents=True, exist_ok=True)

    scad_path = workdir / f"{basename}.scad"
    png_path = workdir / f"{basename}.png"
    scad_path.write_text(scad_code, encoding="utf-8")

    try:
        binary = find_openscad_binary()
    except FileNotFoundError as exc:
        return RenderResult(
            success=False,
            png_bytes=None,
            stdout="",
            stderr=str(exc),
            exit_code=-1,
            scad_path=str(scad_path),
        )

    render_flag = "--render" if render_mode != "preview" else "--preview"
    cmd = [
        binary,
        "-o",
        str(png_path),
        f"--imgsize={imgsize[0]},{imgsize[1]}",
        render_flag,
        "--autocenter",
        "--viewall",
        str(scad_path),
    ]

    try:
        proc = subprocess.run(cmd, capture_output=True, timeout=timeout, text=True)
    except subprocess.TimeoutExpired as exc:
        return RenderResult(
            success=False,
            png_bytes=None,
            stdout=exc.stdout or "",
            stderr=(exc.stderr or "") + f"\nOpenSCAD render timed out after {timeout}s",
            exit_code=-1,
            scad_path=str(scad_path),
        )

    png_bytes = None
    if png_path.is_file() and png_path.stat().st_size > 0:
        png_bytes = png_path.read_bytes()

    success = proc.returncode == 0 and png_bytes is not None

    return RenderResult(
        success=success,
        png_bytes=png_bytes,
        stdout=proc.stdout or "",
        stderr=proc.stderr or "",
        exit_code=proc.returncode,
        scad_path=str(scad_path),
    )
