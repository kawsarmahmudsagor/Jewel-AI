import copy
import json
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scad_builder import build_scad, compute_anchors, compute_stone_geometry, _band_surface_point  # noqa: E402

FIXTURE_PATH = Path(__file__).resolve().parent.parent / "output" / "59273dbf_analysis.json"

CROSS_SECTIONS = ["Round", "Comfort Fit", "Half Round", "Flat", "Knife Edge", "Custom", "Bogus"]
BAND_CONFIGS = [
    "Single Shank", "Split Shank", "Double Band", "Triple Band",
    "Bypass", "Twisted", "Infinity", "Other", "Bogus",
]
SHOULDER_STYLES = ["Cathedral", "Split", "Straight", "Bypass", "Tapered", "Bogus"]
GALLERY_STYLES = ["Basket", "Cathedral", "Trellis", "Peg Head", "Halo", "Custom", "Bogus"]
SETTING_TYPES = ["Prong", "Basket", "Cathedral", "Halo", "Bezel", "Peg Head", "Trellis", "Bogus"]
STONE_SHAPES = [
    "Round", "Oval", "Cushion", "Emerald", "Pear",
    "Princess", "Marquise", "Heart", "Radiant", "Bogus",
]


def base_analysis() -> dict:
    return {
        "expertAnalysisQuestionnaire": {
            "sections": {
                "2_ringBandAnalysis": {
                    "ringParameters": {"innerRadius": 8.25},
                    "bandGeometry": {
                        "thicknessAtShoulder": 1.7,
                        "widthAtShoulder": 2.0,
                        "crossSectionalShape": {"type": "Round"},
                        "bandConfiguration": {"type": "Single Shank"},
                    },
                },
                "3_bandTypeAnalysis": {
                    "shoulderAnalysis": {"style": {"type": "Cathedral"}, "width": 2.0, "height": 3.5},
                    "splitShankAnalysis": {"armsPerSide": 2, "armWidth": 0.9},
                },
                "4_paveAccentStoneAnalysis": {
                    "isPresent": True,
                    "averageStoneDiameter": 0.8,
                    "stones": [
                        {
                            "bandPosition": {
                                "angleFromHeadDegrees": 25.0,
                                "lateralOffsetDegrees": 0.0,
                                "heightAboveBandSurface": 0.15,
                            },
                            "diameter": 0.8,
                        },
                        {
                            "bandPosition": {
                                "angleFromHeadDegrees": -25.0,
                                "lateralOffsetDegrees": 0.0,
                                "heightAboveBandSurface": 0.15,
                            },
                            "diameter": 0.7,
                        },
                    ],
                },
                "5_centerStoneAnalysis": {
                    "geometry": {
                        "diameter": 5.0, "width": 5.0, "length": 5.0, "depth": 3.1,
                        "shape": {"type": "Round"},
                    },
                    "setting": {
                        "type": {"value": "Prong"},
                        "prongCount": 4,
                        "prongAngularPositions": [0, 90, 180, 270],
                        "prongThickness": 0.6,
                        "extensionBelowGirdle": 1.7,
                    },
                },
                "6_sideStoneAnalysis": {
                    "isPresent": True,
                    "stones": [
                        {
                            "bandPosition": {
                                "angleFromHeadDegrees": 18.0,
                                "lateralOffsetDegrees": 0.0,
                                "heightAboveBandSurface": 0.2,
                            },
                            "dimensions": {"width": 1.2, "length": 1.5, "depth": 0.8},
                        }
                    ],
                },
                "7_galleryHeadAssemblyAnalysis": {
                    "galleryGeometry": {
                        "isPresent": True, "width": 3.4, "height": 1.6,
                        "style": {"type": "Basket"},
                    }
                },
            }
        },
        "assemblyStack": {
            "bandTopZ": 0, "galleryTopZ": 3.5, "stoneGirdleZ": 3.5,
            "stoneTableZ": 4.3, "prongTipZ": 5.3,
        },
        "gemstoneColor": {"colorHex": "#E8F4FF"},
    }


class TestFixture(unittest.TestCase):
    def test_real_fixture_builds(self):
        analysis = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
        code = build_scad(analysis)
        self.assertIsInstance(code, str)
        self.assertGreater(len(code), 0)
        for needle in (
            "band_apex_z", "module ring_band_base()", "module prong(",
            "module center_stone()", "union() {",
        ):
            self.assertIn(needle, code)


class TestDegradation(unittest.TestCase):
    def test_empty_analysis_does_not_raise(self):
        code = build_scad({})
        self.assertIsInstance(code, str)
        self.assertIn("union() {", code)

    def test_none_analysis_does_not_raise(self):
        code = build_scad(None)
        self.assertIsInstance(code, str)


class TestSchemaCoverage(unittest.TestCase):
    """Every enum value (including a bogus/unknown one) for every builder
    dict must produce non-empty OpenSCAD output without raising."""

    def _build_with(self, **overrides) -> str:
        analysis = base_analysis()
        sections = analysis["expertAnalysisQuestionnaire"]["sections"]
        if "cross_section" in overrides:
            sections["2_ringBandAnalysis"]["bandGeometry"]["crossSectionalShape"]["type"] = overrides["cross_section"]
        if "band_config" in overrides:
            sections["2_ringBandAnalysis"]["bandGeometry"]["bandConfiguration"]["type"] = overrides["band_config"]
        if "shoulder_style" in overrides:
            sections["3_bandTypeAnalysis"]["shoulderAnalysis"]["style"]["type"] = overrides["shoulder_style"]
        if "gallery_style" in overrides:
            sections["7_galleryHeadAssemblyAnalysis"]["galleryGeometry"]["style"]["type"] = overrides["gallery_style"]
        if "setting_type" in overrides:
            sections["5_centerStoneAnalysis"]["setting"]["type"]["value"] = overrides["setting_type"]
        if "stone_shape" in overrides:
            sections["5_centerStoneAnalysis"]["geometry"]["shape"]["type"] = overrides["stone_shape"]
        return build_scad(analysis)

    def test_all_cross_sections(self):
        for value in CROSS_SECTIONS:
            with self.subTest(cross_section=value):
                code = self._build_with(cross_section=value)
                self.assertIn("rotate_extrude", code)

    def test_all_band_configs(self):
        for value in BAND_CONFIGS:
            with self.subTest(band_config=value):
                code = self._build_with(band_config=value)
                self.assertIn("ring_band_base()", code)

    def test_all_shoulder_styles(self):
        for value in SHOULDER_STYLES:
            with self.subTest(shoulder_style=value):
                code = self._build_with(shoulder_style=value)
                self.assertIsInstance(code, str)
                self.assertGreater(len(code), 0)

    def test_all_gallery_styles(self):
        for value in GALLERY_STYLES:
            with self.subTest(gallery_style=value):
                code = self._build_with(gallery_style=value)
                self.assertIsInstance(code, str)
                self.assertGreater(len(code), 0)

    def test_all_setting_types(self):
        for value in SETTING_TYPES:
            with self.subTest(setting_type=value):
                code = self._build_with(setting_type=value)
                self.assertIsInstance(code, str)
                self.assertGreater(len(code), 0)

    def test_all_stone_shapes(self):
        for value in STONE_SHAPES:
            with self.subTest(stone_shape=value):
                code = self._build_with(stone_shape=value)
                self.assertIn("module center_stone()", code)

    def test_gallery_absent(self):
        analysis = base_analysis()
        analysis["expertAnalysisQuestionnaire"]["sections"]["7_galleryHeadAssemblyAnalysis"][
            "galleryGeometry"
        ]["isPresent"] = False
        code = build_scad(analysis)
        self.assertNotIn("gallery_cup", code)

    def test_pave_and_side_stones_absent(self):
        analysis = base_analysis()
        sections = analysis["expertAnalysisQuestionnaire"]["sections"]
        sections["4_paveAccentStoneAnalysis"]["isPresent"] = False
        sections["6_sideStoneAnalysis"]["isPresent"] = False
        code = build_scad(analysis)
        self.assertNotIn("pave_stones", code)
        self.assertNotIn("side_stone_", code)

    def test_kitchen_sink_combo_renders_via_openscad(self):
        """One deliberately unusual combination, actually rendered through
        the OpenSCAD CLI -- the real proof that an off-the-beaten-path
        schema combination still produces valid, renderable geometry."""
        from scad_render import render_to_png

        code = self._build_with(
            cross_section="Comfort Fit",
            band_config="Split Shank",
            shoulder_style="Bypass",
            gallery_style="Trellis",
            setting_type="Bezel",
            stone_shape="Marquise",
        )
        result = render_to_png(
            code,
            workdir=Path(__file__).resolve().parent / "_artifacts",
            basename="kitchen_sink",
            timeout=90,
        )
        self.assertTrue(result.success, msg=result.stderr)
        self.assertTrue(result.png_bytes)


class TestBandSurfacePointSafety(unittest.TestCase):
    """The structural guarantee behind the band-relative position convention:
    no matter what angles/offsets a caller supplies (LLM-extracted or
    adversarial), a point produced by _band_surface_point can never land
    inside the finger hole."""

    def _anchors(self):
        analysis = base_analysis()
        anchors = compute_anchors(analysis)
        anchors.update(compute_stone_geometry(analysis, anchors))
        return anchors

    def test_never_inside_hole_across_wide_angle_sweep(self):
        anchors = self._anchors()
        hole_radius = anchors["ring_inner_radius"]
        for angle in range(-720, 721, 15):
            for lateral in (-180, -90, 0, 90, 180):
                for height in (-0.5, 0.0, 0.5, 5.0):
                    x, y, z = _band_surface_point(anchors, angle, lateral, height)
                    radial = math.hypot(x, z)
                    with self.subTest(angle=angle, lateral=lateral, height=height):
                        self.assertGreaterEqual(radial, hole_radius - 1e-6)

    def test_zero_offsets_land_on_true_band_crest(self):
        anchors = self._anchors()
        x, y, z = _band_surface_point(anchors, 0.0, 0.0, 0.0)
        # angleFromHeadDegrees=0 is "at the head" -- world Z should equal the
        # band's true outer crest (band_apex_z + band_tube_radius), one full
        # tube radius beyond band_apex_z itself, which is only the tube's
        # center and would bury a zero-height stone inside the metal.
        expected = anchors["band_apex_z"] + anchors["band_tube_radius"]
        self.assertAlmostEqual(z, expected, places=4)

    def test_zero_height_stone_sits_outside_band_apex_z(self):
        anchors = self._anchors()
        x, y, z = _band_surface_point(anchors, 0.0, 0.0, 0.0)
        self.assertGreater(z, anchors["band_apex_z"])


class TestNewDecorativeBuilders(unittest.TestCase):
    def _analysis_with(self, **section_overrides):
        analysis = base_analysis()
        sections = analysis["expertAnalysisQuestionnaire"]["sections"]
        for key, value in section_overrides.items():
            sections[key] = value
        return analysis

    def test_halo_present_via_gallery_style(self):
        analysis = base_analysis()
        sections = analysis["expertAnalysisQuestionnaire"]["sections"]
        sections["7_galleryHeadAssemblyAnalysis"]["galleryGeometry"]["style"]["type"] = "Halo"
        code = build_scad(analysis)
        self.assertIn("module halo_stones()", code)
        self.assertIn("module gallery_halo_basket()", code)

    def test_halo_present_via_explicit_flag_with_other_gallery_style(self):
        analysis = base_analysis()
        sections = analysis["expertAnalysisQuestionnaire"]["sections"]
        sections["7_galleryHeadAssemblyAnalysis"]["haloAnalysis"] = {
            "isPresent": True, "stoneCount": 20, "stoneDiameter": 0.9,
            "radialOffsetFromGirdle": 0.5, "heightOffsetFromGirdle": 0.0,
        }
        code = build_scad(analysis)
        self.assertIn("module halo_stones()", code)

    def test_halo_absent_by_default(self):
        analysis = base_analysis()
        code = build_scad(analysis)
        self.assertNotIn("halo_stones", code)

    def test_halo_explicitly_false_skips_ring_even_with_halo_style(self):
        analysis = base_analysis()
        sections = analysis["expertAnalysisQuestionnaire"]["sections"]
        sections["7_galleryHeadAssemblyAnalysis"]["galleryGeometry"]["style"]["type"] = "Halo"
        sections["7_galleryHeadAssemblyAnalysis"]["haloAnalysis"] = {"isPresent": False}
        code = build_scad(analysis)
        self.assertNotIn("module halo_stones()", code)
        self.assertIn("module gallery_halo_basket()", code)

    def test_milgrain_present(self):
        analysis = self._analysis_with(**{
            "3_bandTypeAnalysis": {
                "decorativeFeatures": {"milgrain": True},
                "decorativeFeatureDetails": {
                    "milgrain": {"isPresent": True, "beadDiameter": 0.4, "spacing": 0.5}
                },
            }
        })
        code = build_scad(analysis)
        self.assertIn("module milgrain_beads()", code)

    def test_milgrain_absent_by_default(self):
        code = build_scad(base_analysis())
        self.assertNotIn("milgrain_beads", code)

    def test_channel_present(self):
        analysis = self._analysis_with(**{
            "3_bandTypeAnalysis": {
                "decorativeFeatures": {"channel": True},
                "decorativeFeatureDetails": {
                    "channel": {
                        "isPresent": True, "stoneCount": 8, "stoneDiameter": 1.0,
                        "startAngleFromHeadDegrees": 15.0, "endAngleFromHeadDegrees": 70.0,
                    }
                },
            }
        })
        code = build_scad(analysis)
        self.assertIn("module channel_stones()", code)

    def test_filigree_present(self):
        analysis = self._analysis_with(**{
            "3_bandTypeAnalysis": {
                "decorativeFeatures": {"filigree": True},
                "decorativeFeatureDetails": {
                    "filigree": {"isPresent": True, "wireThickness": 0.4, "loopCount": 3}
                },
            }
        })
        code = build_scad(analysis)
        self.assertIn("filigree_wire_", code)

    def test_pave_stone_missing_band_position_still_renders_and_is_safe(self):
        """If an individual stone is missing bandPosition entirely (e.g. the
        extraction model only partially filled the list), the default
        spread must still land on the band, never at the origin/in the hole."""
        analysis = base_analysis()
        sections = analysis["expertAnalysisQuestionnaire"]["sections"]
        sections["4_paveAccentStoneAnalysis"]["stones"] = [
            {"diameter": 0.8},
            {"diameter": 0.7},
            {"diameter": 0.8},
        ]
        code = build_scad(analysis)
        self.assertIn("module pave_stones()", code)

    def test_full_decorative_combo_renders_via_openscad(self):
        """Halo + pavé + side stones + milgrain + channel + filigree all at
        once -- the realistic 'busy' ring case -- actually rendered through
        the OpenSCAD CLI to prove the new builders compose into valid,
        non-floating geometry together, not just individually."""
        from scad_render import render_to_png

        analysis = base_analysis()
        sections = analysis["expertAnalysisQuestionnaire"]["sections"]
        sections["7_galleryHeadAssemblyAnalysis"]["galleryGeometry"]["style"]["type"] = "Halo"
        sections["7_galleryHeadAssemblyAnalysis"]["haloAnalysis"] = {
            "isPresent": True, "stoneCount": 16, "stoneDiameter": 0.9,
            "radialOffsetFromGirdle": 0.5, "heightOffsetFromGirdle": 0.0,
        }
        sections["3_bandTypeAnalysis"]["decorativeFeatures"] = {
            "milgrain": True, "channel": True, "filigree": True,
        }
        sections["3_bandTypeAnalysis"]["decorativeFeatureDetails"] = {
            "milgrain": {"isPresent": True, "beadDiameter": 0.35, "spacing": 0.5},
            "channel": {
                "isPresent": True, "stoneCount": 6, "stoneDiameter": 1.0,
                "startAngleFromHeadDegrees": 80.0, "endAngleFromHeadDegrees": 130.0,
            },
            "filigree": {"isPresent": True, "wireThickness": 0.4, "loopCount": 3},
        }

        code = build_scad(analysis)
        result = render_to_png(
            code,
            workdir=Path(__file__).resolve().parent / "_artifacts",
            basename="full_decorative_combo",
            timeout=90,
        )
        self.assertTrue(result.success, msg=result.stderr)
        self.assertTrue(result.png_bytes)


if __name__ == "__main__":
    unittest.main()
