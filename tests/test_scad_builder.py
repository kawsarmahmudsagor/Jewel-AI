import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scad_builder import build_scad  # noqa: E402

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
                        {"position": {"x": 3.0, "y": 1.0, "z": 9.5}, "diameter": 0.8},
                        {"position": {"x": -3.0, "y": -1.0, "z": 9.5}, "diameter": 0.7},
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
                            "position": {"x": 9.0, "y": 3.0, "z": 9.1},
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


if __name__ == "__main__":
    unittest.main()
