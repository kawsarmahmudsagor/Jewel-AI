"""OpenSCAD CLI wrapper -- renders .scad source to a PNG for the refine loop.

Never raises: timeouts, missing-binary, and non-zero exits are all surfaced
as a failed RenderResult so callers (generator.refine) can always branch
on .success without wrapping every call in try/except.
"""

import math
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

_DEFAULT_WINDOWS_PATH = r"C:\Program Files\OpenSCAD\openscad.exe"

# World convention shared with scad_builder.py: Z up, Y is the finger-hole
# axis, X is lateral. A generously large fixed eye distance works for any
# realistic ring size because --viewall auto-fits the zoom regardless of
# the literal camera distance -- only the eye DIRECTION matters here.
CAMERA_EYE_DISTANCE = 100.0

NAMED_CAMERA_EYES: dict[str, tuple[float, float, float]] = {
    "top": (0.0, 0.0, CAMERA_EYE_DISTANCE),
    "front": (0.0, -CAMERA_EYE_DISTANCE, 0.0),
    "back": (0.0, CAMERA_EYE_DISTANCE, 0.0),
    "left": (-CAMERA_EYE_DISTANCE, 0.0, 0.0),
    "right": (CAMERA_EYE_DISTANCE, 0.0, 0.0),
}


def photo_matching_camera_eye(photo_context: dict | None) -> tuple[float, float, float]:
    """Maps photoContext (viewAngle + estimatedTiltDegrees, from extraction)
    onto a camera eye position on the same world axes as ring_band_base().
    tilt=0 is a pure top-down view, tilt=90 is eye-level (front) -- the eye
    is interpolated as a point on a sphere between those. face_on/side_profile/
    top_down get a straight-on azimuth (0); three_quarter/oblique get a 35
    degree azimuth offset to approximate the angled framing those views
    actually have. Defaults to a generic 3/4 angle when photoContext is
    missing/incomplete rather than guessing a more specific one."""
    photo_context = photo_context or {}
    view_angle = photo_context.get("viewAngle")
    tilt = photo_context.get("estimatedTiltDegrees")
    if tilt is None:
        tilt = 60.0
    azimuth = 0.0 if view_angle in ("face_on", "side_profile", "top_down") else 35.0

    tilt_r = math.radians(tilt)
    azimuth_r = math.radians(azimuth)
    x = CAMERA_EYE_DISTANCE * math.sin(tilt_r) * math.sin(azimuth_r)
    y = -CAMERA_EYE_DISTANCE * math.sin(tilt_r) * math.cos(azimuth_r)
    z = CAMERA_EYE_DISTANCE * math.cos(tilt_r)
    return (x, y, z)


def _fmt_num(x: float) -> str:
    s = f"{x:.4f}".rstrip("0").rstrip(".")
    return s if s not in ("", "-") else "0"


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


def _run_openscad(
    scad_path: Path,
    png_path: Path,
    *,
    imgsize: tuple[int, int],
    render_mode: str | None,
    camera_eye: tuple[float, float, float] | None,
    timeout: int,
) -> RenderResult:
    """Invokes the OpenSCAD CLI against an already-written .scad file. Shared
    by render_to_png and render_named_angles so rendering several camera
    angles of the same model only writes that .scad file once."""
    render_mode = render_mode or os.getenv("OPENSCAD_RENDER_MODE", "render")

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
    ]
    if camera_eye is not None:
        ex, ey, ez = camera_eye
        cmd.append(f"--camera={_fmt_num(ex)},{_fmt_num(ey)},{_fmt_num(ez)},0,0,0")
    cmd.append(str(scad_path))

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


def render_to_png(
    scad_code: str,
    *,
    imgsize: tuple[int, int] = (800, 800),
    render_mode: str | None = None,
    camera_eye: tuple[float, float, float] | None = None,
    timeout: int = 60,
    workdir: Path | None = None,
    basename: str = "render",
) -> RenderResult:
    workdir = workdir or Path(".")
    workdir.mkdir(parents=True, exist_ok=True)

    scad_path = workdir / f"{basename}.scad"
    png_path = workdir / f"{basename}.png"
    scad_path.write_text(scad_code, encoding="utf-8")

    return _run_openscad(
        scad_path, png_path, imgsize=imgsize, render_mode=render_mode,
        camera_eye=camera_eye, timeout=timeout,
    )


def render_named_angles(
    scad_code: str,
    *,
    angles: tuple[str, ...] = ("top", "front", "left"),
    imgsize: tuple[int, int] = (600, 600),
    timeout: int = 40,
    workdir: Path | None = None,
    basename_prefix: str = "angle",
) -> dict[str, RenderResult]:
    """Renders the same already-known-good SCAD from a few fixed angles
    using fast --preview mode (these are supplementary context for the
    critique LLM, not the primary comparison, so speed is prioritized over
    full render fidelity). Defaults to top/front/left only -- a ring is
    left-right and front-back symmetric enough that back/right add little
    over their mirror counterparts, so they're skipped by default (pass
    angles= explicitly to render any of the 5 presets in NAMED_CAMERA_EYES).
    The .scad file is written ONCE and reused for every angle -- only the
    camera and output PNG differ per invocation. A failure on any individual
    angle is just omitted by the caller -- it isn't grounds to fail the
    round, since the geometry already proved renderable via the primary
    render."""
    workdir = workdir or Path(".")
    workdir.mkdir(parents=True, exist_ok=True)
    scad_path = workdir / f"{basename_prefix}.scad"
    scad_path.write_text(scad_code, encoding="utf-8")

    results = {}
    for name in angles:
        eye = NAMED_CAMERA_EYES.get(name)
        if eye is None:
            continue
        png_path = workdir / f"{basename_prefix}_{name}.png"
        results[name] = _run_openscad(
            scad_path, png_path, imgsize=imgsize, render_mode="preview",
            camera_eye=eye, timeout=timeout,
        )
    return results
