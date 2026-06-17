"""Deterministic OpenSCAD generator.

Builds a complete OpenSCAD program directly from the filled analysis JSON
(sections 1-8 + assemblyStack + gemstoneColor), with no LLM involved. Every
schema enum option has a registered builder; unknown/null/"Other"/"Custom"
values degrade to a safe default rather than raising. This module never
raises on malformed input -- it always returns a renderable .scad string.

The anchor math (band_apex_z, world_z offsets) and the bent 3-point prong
claw are encoded here as literal Python logic because they are mechanical
and must always hold. Visual judgment (does this look right next to the
photo) is explicitly NOT this module's job -- that happens in the LLM
refine pass in generator.py, which may rewrite this output freely.
"""

import math
from typing import Callable

Point = tuple

# ---------------------------------------------------------------------------
# generic helpers
# ---------------------------------------------------------------------------


def _safe(d, *path, default=None):
    cur = d
    for key in path:
        if not isinstance(cur, dict) or key not in cur or cur[key] is None:
            return default
        cur = cur[key]
    return cur if cur is not None else default


def _pick(builders: dict, key, default_key):
    if key and key in builders:
        return builders[key]
    return builders[default_key]


def _fmt(x) -> str:
    if isinstance(x, float):
        s = f"{x:.4f}".rstrip("0").rstrip(".")
        return s if s not in ("", "-") else "0"
    return str(x)


def _arr(points) -> str:
    rows = ", ".join("[" + ", ".join(_fmt(c) for c in p) + "]" for p in points)
    return f"[{rows}]"


def _linspace(a, b, n):
    if n <= 1:
        return [a]
    step = (b - a) / (n - 1)
    return [a + step * i for i in range(n)]


def _section(analysis: dict, key: str) -> dict:
    return _safe(analysis, "expertAnalysisQuestionnaire", "sections", key, default={}) or {}


# ---------------------------------------------------------------------------
# anchors (band_apex_z + world-Z stack)
# ---------------------------------------------------------------------------


def compute_anchors(analysis: dict) -> dict:
    band = _section(analysis, "2_ringBandAnalysis")
    stack = _safe(analysis, "assemblyStack", default={}) or {}

    ring_inner_radius = _safe(band, "ringParameters", "innerRadius", default=8.25) or 8.25
    thickness_shoulder = _safe(band, "bandGeometry", "thicknessAtShoulder", default=1.7) or 1.7
    band_tube_radius = thickness_shoulder / 2.0
    band_apex_z = ring_inner_radius + band_tube_radius

    band_top_z = stack.get("bandTopZ", 0) or 0

    def world_z(stack_key, default):
        val = stack.get(stack_key)
        if val is None:
            val = default
        return band_apex_z + (val - band_top_z)

    gallery_top_z = world_z("galleryTopZ", 3.5)
    stone_girdle_z = world_z("stoneGirdleZ", stack.get("galleryTopZ", 3.5))
    stone_table_z = world_z("stoneTableZ", 4.3)
    prong_tip_z = world_z("prongTipZ", 5.3)

    return {
        "ring_inner_radius": ring_inner_radius,
        "thickness_shoulder": thickness_shoulder,
        "band_tube_radius": band_tube_radius,
        "band_apex_z": band_apex_z,
        "gallery_top_z": gallery_top_z,
        "stone_girdle_z": stone_girdle_z,
        "stone_table_z": stone_table_z,
        "prong_tip_z": prong_tip_z,
    }


# ---------------------------------------------------------------------------
# band cross-section profiles -- each returns an OpenSCAD 2D-shape snippet
# usable as the direct child of rotate_extrude(). Coordinates are
# (radial, width-axis); radial >= 0 always, as rotate_extrude requires.
# ---------------------------------------------------------------------------


def _profile_round(inner_r, thickness, width):
    r = thickness / 2.0
    cx = inner_r + r
    return f"translate([{_fmt(cx)}, 0]) circle(r={_fmt(r)}, $fn=48);"


def _profile_flat(inner_r, thickness, width):
    half_w = width / 2.0
    pts = [
        (inner_r, -half_w),
        (inner_r + thickness, -half_w),
        (inner_r + thickness, half_w),
        (inner_r, half_w),
    ]
    return f"polygon({_arr(pts)});"


def _profile_knife_edge(inner_r, thickness, width):
    half_w = width / 2.0
    pts = [(inner_r, -half_w), (inner_r + thickness, 0.0), (inner_r, half_w)]
    return f"polygon({_arr(pts)});"


def _profile_half_round(inner_r, thickness, width, n=20):
    half_w = width / 2.0
    arc = [
        (inner_r + thickness * math.cos(math.radians(t)), half_w * math.sin(math.radians(t)))
        for t in _linspace(-90, 90, n)
    ]
    return f"polygon({_arr(arc)});"


def _profile_comfort_fit(inner_r, thickness, width, n=20, inner_curv_r=17.0):
    half_w = width / 2.0
    outer = [
        (inner_r + thickness * math.cos(math.radians(t)), half_w * math.sin(math.radians(t)))
        for t in _linspace(-90, 90, n)
    ]
    sag = (half_w ** 2) / (2 * inner_curv_r) if inner_curv_r else 0.0
    inner = [
        (inner_r - sag * math.cos(math.radians(t)), half_w * math.sin(math.radians(t)))
        for t in _linspace(90, -90, n)
    ]
    return f"polygon({_arr(outer + inner)});"


CROSS_SECTION_BUILDERS: dict[str, Callable] = {
    "Round": _profile_round,
    "Comfort Fit": _profile_comfort_fit,
    "Half Round": _profile_half_round,
    "Flat": _profile_flat,
    "Knife Edge": _profile_knife_edge,
    "Custom": _profile_half_round,
}
_CROSS_SECTION_DEFAULT = "Round"


# ---------------------------------------------------------------------------
# shared sphere-hull-chain helper -- used by cathedral/split-shank arms,
# trellis wires, and band style accents. One literal array assignment,
# never reassigned -- no OpenSCAD mutability issues possible.
# ---------------------------------------------------------------------------


def _sphere_hull_chain(name: str, points_radii, color_var: str) -> str:
    """points_radii: list of (x, y, z, r) tuples describing a chain of spheres
    to be hull()'d pairwise-consecutively into one continuous arched solid."""
    arr = _arr(points_radii)
    return f"""
module {name}() {{
    color({color_var})
    {{
        pts = {arr};
        for (i = [0 : len(pts) - 2]) {{
            hull() {{
                translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
                translate([pts[i+1][0], pts[i+1][1], pts[i+1][2]]) sphere(r = pts[i+1][3], $fn = 16);
            }}
        }}
    }}
}}
"""


def _arch_points(side_sign, x_outer, x_inner, z_start, z_end, r_start, r_end, arch_boost, n=12):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = x_outer * (1 - t) + x_inner * t
        z = z_start * (1 - t) + z_end * t + arch_boost * math.sin(t * math.pi / 2)
        r = r_start * (1 - t) + r_end * t
        pts.append((side_sign * x, 0.0, z, r))
    return pts


# ---------------------------------------------------------------------------
# band assembly (shank configuration)
# ---------------------------------------------------------------------------


def _band_base_module(anchors, profile_code) -> str:
    return f"""
module ring_band_base() {{
    color(ring_color)
    rotate([90, 0, 0])
        rotate_extrude(angle = 360)
            {profile_code}
}}
"""


def _band_accent_parallel(anchors, width, gap=0.9, thin_factor=0.55) -> str:
    """A thinner second (or third) torus offset along the width axis --
    used to suggest double/triple/bypass/twisted/infinity bands without
    risking a non-manifold custom sweep. Always renders, never floats
    (it's a complete torus on its own)."""
    r = anchors["band_tube_radius"] * thin_factor
    cx = anchors["ring_inner_radius"] + r
    offset = width / 2.0 + gap
    return f"""
module ring_band_accent() {{
    color(ring_color)
    rotate([90, 0, 0]) {{
        translate([0, {_fmt(offset)}, 0])
            rotate_extrude(angle = 360) translate([{_fmt(cx)}, 0]) circle(r = {_fmt(r)}, $fn = 32);
        translate([0, {_fmt(-offset)}, 0])
            rotate_extrude(angle = 360) translate([{_fmt(cx)}, 0]) circle(r = {_fmt(r)}, $fn = 32);
    }}
}}
"""


def _band_split_arms(anchors, split_info) -> str:
    arms_per_side = split_info.get("armsPerSide") or 1
    arm_width = split_info.get("armWidth") or 0.9
    half_w = arm_width / 2.0
    apex = anchors["band_apex_z"]
    gallery_foot_z = apex - 0.2
    fragments = []
    for side in (1, -1):
        for k in range(arms_per_side):
            spread = (k - (arms_per_side - 1) / 2.0) * (half_w * 1.4)
            pts = _arch_points(
                side_sign=side,
                x_outer=anchors["ring_inner_radius"] + anchors["band_tube_radius"] * 1.4,
                x_inner=anchors["ring_inner_radius"] * 0.55,
                z_start=apex - 0.3,
                z_end=gallery_foot_z,
                r_start=half_w,
                r_end=half_w * 0.8,
                arch_boost=0.6,
            )
            pts = [(p[0], p[1] + spread, p[2], p[3]) for p in pts]
            name = f"split_arm_{side if side > 0 else 0}_{k}"
            fragments.append(_sphere_hull_chain(name, pts, "ring_color"))
    calls = "\n    ".join(
        f"{f.split('module ')[1].split('(')[0]}();" for f in fragments
    )
    return "\n".join(fragments) + f"\nmodule split_arms() {{\n    {calls}\n}}\n"


def _band_single(ctx) -> tuple[str, list[str]]:
    return ctx["base_module"], ["ring_band_base()"]


def _band_double(ctx) -> tuple[str, list[str]]:
    accent = _band_accent_parallel(ctx["anchors"], ctx["width"])
    return ctx["base_module"] + accent, ["ring_band_base()", "ring_band_accent()"]


def _band_triple(ctx) -> tuple[str, list[str]]:
    accent = _band_accent_parallel(ctx["anchors"], ctx["width"], gap=1.6)
    accent2 = _band_accent_parallel(ctx["anchors"], ctx["width"], gap=0.0).replace(
        "ring_band_accent", "ring_band_accent2"
    )
    return (
        ctx["base_module"] + accent + accent2,
        ["ring_band_base()", "ring_band_accent()", "ring_band_accent2()"],
    )


def _band_bypass(ctx) -> tuple[str, list[str]]:
    accent = _band_accent_parallel(ctx["anchors"], ctx["width"], gap=0.4, thin_factor=0.7)
    return ctx["base_module"] + accent, ["ring_band_base()", "ring_band_accent()"]


def _band_twisted(ctx) -> tuple[str, list[str]]:
    accent = _band_accent_parallel(ctx["anchors"], ctx["width"], gap=0.2, thin_factor=0.5)
    return ctx["base_module"] + accent, ["ring_band_base()", "ring_band_accent()"]


def _band_infinity(ctx) -> tuple[str, list[str]]:
    accent = _band_accent_parallel(ctx["anchors"], ctx["width"], gap=0.5, thin_factor=0.45)
    return ctx["base_module"] + accent, ["ring_band_base()", "ring_band_accent()"]


def _band_split_shank(ctx) -> tuple[str, list[str]]:
    split_info = ctx.get("split_info") or {}
    arms_code = _band_split_arms(ctx["anchors"], split_info)
    return ctx["base_module"] + arms_code, ["ring_band_base()", "split_arms()"]


BAND_CONFIG_BUILDERS: dict[str, Callable] = {
    "Single Shank": _band_single,
    "Split Shank": _band_split_shank,
    "Double Band": _band_double,
    "Triple Band": _band_triple,
    "Bypass": _band_bypass,
    "Twisted": _band_twisted,
    "Infinity": _band_infinity,
    "Other": _band_single,
}
_BAND_CONFIG_DEFAULT = "Single Shank"


def build_band_modules(analysis: dict, anchors: dict) -> tuple[str, list[str]]:
    band = _section(analysis, "2_ringBandAnalysis")
    geom = _safe(band, "bandGeometry", default={}) or {}

    cross_type = _safe(geom, "crossSectionalShape", "type")
    profile_fn = _pick(CROSS_SECTION_BUILDERS, cross_type, _CROSS_SECTION_DEFAULT)
    width = geom.get("widthAtShoulder") or 2.0
    profile_code = profile_fn(anchors["ring_inner_radius"], anchors["thickness_shoulder"], width)
    base_module = _band_base_module(anchors, profile_code)

    band_type_section = _section(analysis, "3_bandTypeAnalysis")
    split_info = _safe(band_type_section, "splitShankAnalysis", default={}) or {}
    config_type = _safe(geom, "bandConfiguration", "type")
    builder = _pick(BAND_CONFIG_BUILDERS, config_type, _BAND_CONFIG_DEFAULT)

    ctx = {
        "anchors": anchors,
        "width": width,
        "base_module": base_module,
        "split_info": split_info,
    }
    return builder(ctx)


# ---------------------------------------------------------------------------
# shoulders (cathedral / split / straight / bypass / tapered)
# ---------------------------------------------------------------------------


def _shoulder_arch(ctx) -> tuple[str, list[str]]:
    anchors = ctx["anchors"]
    shoulder = ctx["shoulder"]
    width = shoulder.get("width") or 2.0
    apex = anchors["band_apex_z"]
    gallery_foot_z = anchors["gallery_top_z"] - 1.6

    fragments = []
    for side in (1, -1):
        pts = _arch_points(
            side_sign=side,
            x_outer=anchors["ring_inner_radius"] * 0.3 + width * 1.1,
            x_inner=width * 0.55,
            z_start=apex - 0.3,
            z_end=gallery_foot_z,
            r_start=width * 0.28,
            r_end=width * 0.22,
            arch_boost=0.5,
        )
        name = f"shoulder_{'r' if side > 0 else 'l'}"
        fragments.append(_sphere_hull_chain(name, pts, "ring_color"))
    calls = ["shoulder_r()", "shoulder_l()"]
    return "\n".join(fragments), calls


def _shoulder_none(ctx) -> tuple[str, list[str]]:
    return "", []


SHOULDER_STYLE_BUILDERS: dict[str, Callable] = {
    "Cathedral": _shoulder_arch,
    "Split": _shoulder_arch,
    "Bypass": _shoulder_arch,
    "Tapered": _shoulder_arch,
    "Straight": _shoulder_none,
}
_SHOULDER_DEFAULT = "Straight"


def build_shoulder_modules(analysis: dict, anchors: dict, skip: bool) -> tuple[str, list[str]]:
    if skip:
        return "", []
    band_type_section = _section(analysis, "3_bandTypeAnalysis")
    shoulder = _safe(band_type_section, "shoulderAnalysis", default={}) or {}
    style = _safe(shoulder, "style", "type")
    builder = _pick(SHOULDER_STYLE_BUILDERS, style, _SHOULDER_DEFAULT)
    return builder({"anchors": anchors, "shoulder": shoulder})


# ---------------------------------------------------------------------------
# gallery / head assembly
# ---------------------------------------------------------------------------


def _gallery_cup(ctx) -> tuple[str, list[str]]:
    anchors = ctx["anchors"]
    gallery = ctx["gallery"]
    cup_top_z = anchors["gallery_top_z"]
    cup_height = max(gallery.get("height") or 1.6, 0.6)
    cup_base_z = cup_top_z - cup_height
    base_outer_r = max((gallery.get("width") or 3.4) / 2.0 * 0.6, 1.2)
    top_outer_r = max((gallery.get("width") or 3.4) / 2.0, base_outer_r + 0.5)
    top_inner_r = max(anchors.get("gem_radius", top_outer_r - 0.3), 0.5)
    wall = 0.3
    return (
        f"""
module gallery_cup() {{
    color(ring_color)
    difference() {{
        translate([0, 0, {_fmt(cup_base_z)}])
            cylinder(r1 = {_fmt(base_outer_r)}, r2 = {_fmt(top_outer_r)}, h = {_fmt(cup_height + 0.2)}, $fn = 48);
        translate([0, 0, {_fmt(cup_base_z - 0.1)}])
            cylinder(r1 = {_fmt(base_outer_r - wall)}, r2 = {_fmt(top_inner_r)}, h = {_fmt(cup_height + 0.4)}, $fn = 48);
    }}
}}
""",
        ["gallery_cup()"],
    )


def _gallery_trellis(ctx) -> tuple[str, list[str]]:
    anchors = ctx["anchors"]
    top_z = anchors["gallery_top_z"]
    base_z = top_z - 1.8
    r = max(anchors.get("gem_radius", 2.0) * 0.8, 1.0)
    fragments = []
    names = []
    for i, angle in enumerate((45, 135, 225, 315)):
        x = r * math.cos(math.radians(angle))
        y = r * math.sin(math.radians(angle))
        pts = [(0.0, 0.0, base_z, 0.35), (x, y, top_z, 0.22)]
        name = f"trellis_wire_{i}"
        fragments.append(_sphere_hull_chain(name, pts, "ring_color"))
        names.append(f"{name}()")
    return "\n".join(fragments), names


def _gallery_peg(ctx) -> tuple[str, list[str]]:
    anchors = ctx["anchors"]
    top_z = anchors["gallery_top_z"]
    base_z = anchors["band_apex_z"] - 0.2
    return (
        f"""
module gallery_peg() {{
    color(ring_color)
    translate([0, 0, {_fmt(base_z)}])
        cylinder(r1 = {_fmt(anchors["band_tube_radius"] * 0.6)}, r2 = 0.9, h = {_fmt(top_z - base_z)}, $fn = 32);
}}
""",
        ["gallery_peg()"],
    )


def _gallery_none(ctx) -> tuple[str, list[str]]:
    return "", []


GALLERY_STYLE_BUILDERS: dict[str, Callable] = {
    "Basket": _gallery_cup,
    "Cathedral": _gallery_cup,
    "Trellis": _gallery_trellis,
    "Peg Head": _gallery_peg,
    "Halo": _gallery_cup,
    "Custom": _gallery_cup,
}
_GALLERY_DEFAULT = "Basket"


def build_gallery_modules(analysis: dict, anchors: dict) -> tuple[str, list[str]]:
    section = _section(analysis, "7_galleryHeadAssemblyAnalysis")
    gallery = _safe(section, "galleryGeometry", default={}) or {}
    is_present = gallery.get("isPresent")
    if is_present is False:
        return _gallery_none({})
    style = _safe(gallery, "style", "type")
    builder = _pick(GALLERY_STYLE_BUILDERS, style, _GALLERY_DEFAULT)
    return builder({"anchors": anchors, "gallery": gallery})


# ---------------------------------------------------------------------------
# center stone geometry
# ---------------------------------------------------------------------------

LW_RATIO_DEFAULTS = {
    "Round": 1.0,
    "Princess": 1.0,
    "Radiant": 1.0,
    "Heart": 1.0,
    "Cushion": 1.08,
    "Emerald": 1.4,
    "Oval": 1.4,
    "Pear": 1.6,
    "Marquise": 2.0,
}

TABLE_PCT_DEFAULTS = {
    "Round": 56.0,
    "Princess": 75.0,
    "Radiant": 68.0,
    "Heart": 56.0,
    "Cushion": 60.0,
    "Emerald": 62.0,
    "Oval": 56.0,
    "Pear": 56.0,
    "Marquise": 56.0,
}

_STONE_SHAPE_DEFAULT = "Round"


def compute_stone_geometry(analysis: dict, anchors: dict) -> dict:
    center = _section(analysis, "5_centerStoneAnalysis")
    geometry = _safe(center, "geometry", default={}) or {}

    shape = _safe(geometry, "shape", "type") or _STONE_SHAPE_DEFAULT
    if shape not in LW_RATIO_DEFAULTS:
        shape = _STONE_SHAPE_DEFAULT

    diameter = geometry.get("diameter") or geometry.get("width") or 5.0
    width = geometry.get("width") or diameter
    length = geometry.get("length") or diameter
    depth = geometry.get("depth") or diameter * 0.62

    lw_ratio = LW_RATIO_DEFAULTS[shape]
    if width and length and width > 0:
        lw_ratio = length / width

    table_pct = TABLE_PCT_DEFAULTS[shape]

    gem_radius = diameter / 2.0
    gem_table_radius = gem_radius * (table_pct / 100.0)
    gem_crown_height = depth * 0.27
    gem_pavilion_depth = depth * 0.73
    pavilion_tip_z = anchors["stone_girdle_z"] - gem_pavilion_depth

    return {
        "shape": shape,
        "lw_ratio": lw_ratio,
        "gem_radius": gem_radius,
        "gem_table_radius": gem_table_radius,
        "gem_crown_height": gem_crown_height,
        "gem_pavilion_depth": gem_pavilion_depth,
        "pavilion_tip_z": pavilion_tip_z,
    }


def build_stone_module(analysis: dict, anchors: dict) -> tuple[str, list[str]]:
    girdle_z = anchors["stone_girdle_z"]
    table_z = girdle_z + anchors["gem_crown_height"]
    pavilion_tip_z = anchors["pavilion_tip_z"]
    gem_r = anchors["gem_radius"]
    table_r = anchors["gem_table_radius"]
    lw_ratio = anchors["lw_ratio"]

    code = f"""
module center_stone() {{
    color(stone_color)
    scale([{_fmt(lw_ratio)}, 1, 1])
    union() {{
        translate([0, 0, {_fmt(girdle_z)}])
            cylinder(r1 = {_fmt(gem_r)}, r2 = {_fmt(table_r)}, h = {_fmt(table_z - girdle_z)}, $fn = 64);
        translate([0, 0, {_fmt(pavilion_tip_z)}])
            cylinder(r1 = 0.01, r2 = {_fmt(gem_r)}, h = {_fmt(girdle_z - pavilion_tip_z)}, $fn = 64);
    }}
}}
"""
    return code, ["center_stone()"]


# ---------------------------------------------------------------------------
# setting / prongs (bent 3-point claw -- the fix from the prong-spike bug)
# ---------------------------------------------------------------------------


def _setting_prong(ctx) -> tuple[str, list[str]]:
    anchors = ctx["anchors"]
    setting = ctx["setting"]

    prong_count = setting.get("prongCount") or 4
    positions = setting.get("prongAngularPositions") or [
        i * (360.0 / prong_count) for i in range(prong_count)
    ]
    thickness = setting.get("prongThickness") or 0.6
    base_radius = thickness / 2.0
    tip_radius = max(base_radius * 0.65, 0.18)
    bend_radius = (base_radius + tip_radius) / 2.0

    gem_r = anchors["gem_radius"]
    table_r = anchors["gem_table_radius"]
    girdle_z = anchors["stone_girdle_z"]
    crown_height = anchors["gem_crown_height"]
    prong_tip_z = anchors["prong_tip_z"]

    base_radial = gem_r + 0.2
    bend_radial = gem_r
    tip_radial = min(table_r * 0.85, table_r - 0.1)
    tip_radial = max(tip_radial, 0.1)

    extension_below_girdle = setting.get("extensionBelowGirdle") or 1.7
    base_z = girdle_z - extension_below_girdle
    bend_z = girdle_z + 0.6 * crown_height

    code = f"""
module prong(base_angle) {{
    color(prong_color)
    rotate([0, 0, base_angle])
    {{
        hull() {{
            translate([{_fmt(base_radial)}, 0, {_fmt(base_z)}]) sphere(r = {_fmt(base_radius)}, $fn = 16);
            translate([{_fmt(bend_radial)}, 0, {_fmt(bend_z)}]) sphere(r = {_fmt(bend_radius)}, $fn = 16);
        }}
        hull() {{
            translate([{_fmt(bend_radial)}, 0, {_fmt(bend_z)}]) sphere(r = {_fmt(bend_radius)}, $fn = 16);
            translate([{_fmt(tip_radial)}, 0, {_fmt(prong_tip_z)}]) sphere(r = {_fmt(tip_radius)}, $fn = 16);
        }}
    }}
}}
"""
    calls = [f"rotate([0, 0, {_fmt(a)}]) prong({_fmt(a)})" for a in positions]
    code += "\nmodule prongs() {\n    " + "\n    ".join(f"{c};" for c in calls) + "\n}\n"
    return code, ["prongs()"]


def _setting_bezel(ctx) -> tuple[str, list[str]]:
    anchors = ctx["anchors"]
    gem_r = anchors["gem_radius"]
    girdle_z = anchors["stone_girdle_z"]
    crown_height = anchors["gem_crown_height"]
    wall = 0.5
    height = crown_height + 0.6
    code = f"""
module bezel_collar() {{
    color(prong_color)
    difference() {{
        translate([0, 0, {_fmt(girdle_z - 0.3)}])
            cylinder(r = {_fmt(gem_r + wall)}, h = {_fmt(height)}, $fn = 64);
        translate([0, 0, {_fmt(girdle_z - 0.4)}])
            cylinder(r = {_fmt(gem_r)}, h = {_fmt(height + 0.2)}, $fn = 64);
    }}
}}
"""
    return code, ["bezel_collar()"]


SETTING_BUILDERS: dict[str, Callable] = {
    "Prong": _setting_prong,
    "Basket": _setting_prong,
    "Cathedral": _setting_prong,
    "Halo": _setting_prong,
    "Peg Head": _setting_prong,
    "Trellis": _setting_prong,
    "Bezel": _setting_bezel,
}
_SETTING_DEFAULT = "Prong"


def build_setting_modules(analysis: dict, anchors: dict) -> tuple[str, list[str]]:
    center = _section(analysis, "5_centerStoneAnalysis")
    setting = _safe(center, "setting", default={}) or {}
    setting_type = _safe(setting, "type", "value")
    builder = _pick(SETTING_BUILDERS, setting_type, _SETTING_DEFAULT)
    return builder({"anchors": anchors, "setting": setting})


# ---------------------------------------------------------------------------
# pave / accent stones and side stones
# ---------------------------------------------------------------------------


def build_pave_modules(analysis: dict, anchors: dict) -> tuple[str, list[str]]:
    pave = _section(analysis, "4_paveAccentStoneAnalysis")
    if not pave.get("isPresent"):
        return "", []
    stones = pave.get("stones") or []
    if not stones:
        return "", []

    default_d = pave.get("averageStoneDiameter") or 1.0
    pts = []
    for s in stones:
        pos = _safe(s, "position", default={}) or {}
        x = pos.get("x") if pos.get("x") is not None else 0.0
        y = pos.get("y") if pos.get("y") is not None else 0.0
        z = pos.get("z") if pos.get("z") is not None else anchors["band_apex_z"]
        d = s.get("diameter") or default_d
        pts.append((x, y, z, d / 2.0))

    code = f"""
module pave_stones() {{
    color(stone_color)
    {{
        pts = {_arr(pts)};
        for (i = [0 : len(pts) - 1]) {{
            translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
        }}
    }}
}}
"""
    return code, ["pave_stones()"]


def build_side_stone_modules(analysis: dict, anchors: dict) -> tuple[str, list[str]]:
    side = _section(analysis, "6_sideStoneAnalysis")
    if not side.get("isPresent"):
        return "", []
    stones = side.get("stones") or []
    if not stones:
        return "", []

    fragments = []
    names = []
    for i, s in enumerate(stones):
        pos = _safe(s, "position", default={}) or {}
        dims = _safe(s, "dimensions", default={}) or {}
        x = pos.get("x") if pos.get("x") is not None else (anchors["ring_inner_radius"] + anchors["band_tube_radius"])
        y = pos.get("y") if pos.get("y") is not None else 0.0
        z = pos.get("z") if pos.get("z") is not None else anchors["band_apex_z"]
        w = dims.get("width") or 1.2
        length = dims.get("length") or w
        d = dims.get("depth") or w * 0.6

        name = f"side_stone_{i}"
        fragments.append(
            f"""
module {name}() {{
    color(stone_color)
    translate([{_fmt(x)}, {_fmt(y)}, {_fmt(z)}])
        scale([{_fmt(length / w if w else 1.0)}, 1, {_fmt(d / w if w else 0.6)}])
            sphere(r = {_fmt(w / 2.0)}, $fn = 24);
}}
"""
        )
        names.append(f"{name}()")
    return "\n".join(fragments), names


# ---------------------------------------------------------------------------
# header / params + top-level assembly
# ---------------------------------------------------------------------------

_RING_METAL_COLOR_DEFAULT = "#D4AF37"


def _build_header(analysis: dict, anchors: dict) -> str:
    stone_color = _safe(analysis, "gemstoneColor", "colorHex", default="#E8F4FF") or "#E8F4FF"
    return f"""// Auto-generated procedural draft -- scad_builder.py
$fn = 64;

ring_color  = "{_RING_METAL_COLOR_DEFAULT}";
prong_color = "{_RING_METAL_COLOR_DEFAULT}";
stone_color = "{stone_color}";

ring_inner_radius   = {_fmt(anchors["ring_inner_radius"])};
band_tube_radius    = {_fmt(anchors["band_tube_radius"])};
band_apex_z         = {_fmt(anchors["band_apex_z"])};
gallery_top_z       = {_fmt(anchors["gallery_top_z"])};
stone_girdle_z      = {_fmt(anchors["stone_girdle_z"])};
stone_table_z       = {_fmt(anchors["stone_girdle_z"] + anchors["gem_crown_height"])};
prong_tip_z         = {_fmt(anchors["prong_tip_z"])};
gem_radius          = {_fmt(anchors["gem_radius"])};
gem_table_radius    = {_fmt(anchors["gem_table_radius"])};
gem_crown_height    = {_fmt(anchors["gem_crown_height"])};
gem_pavilion_depth  = {_fmt(anchors["gem_pavilion_depth"])};
pavilion_tip_z      = {_fmt(anchors["pavilion_tip_z"])};
"""


def build_scad(analysis: dict) -> str:
    """Pure, deterministic OpenSCAD generator. Never raises -- any missing,
    null, or unrecognized field degrades to a safe default so this always
    returns a renderable .scad string."""
    analysis = analysis or {}
    anchors = compute_anchors(analysis)
    anchors.update(compute_stone_geometry(analysis, anchors))

    parts: list[tuple[str, list[str]]] = [
        build_band_modules(analysis, anchors),
        build_shoulder_modules(analysis, anchors, skip=False),
        build_gallery_modules(analysis, anchors),
        build_setting_modules(analysis, anchors),
        build_stone_module(analysis, anchors),
        build_pave_modules(analysis, anchors),
        build_side_stone_modules(analysis, anchors),
    ]

    modules_code = []
    call_names = []
    for code, calls in parts:
        if code.strip():
            modules_code.append(code)
        call_names.extend(calls)

    assembly = "union() {\n    " + "\n    ".join(f"{c};" for c in call_names) + "\n}\n"

    return _build_header(analysis, anchors) + "\n".join(modules_code) + "\n" + assembly
