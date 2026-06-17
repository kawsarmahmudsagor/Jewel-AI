import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import scad_render  # noqa: E402
from scad_render import render_to_png  # noqa: E402

ARTIFACTS = Path(__file__).resolve().parent / "_artifacts"


class TestRenderToPng(unittest.TestCase):
    def test_valid_scad_renders_successfully(self):
        result = render_to_png("cube([4,4,4]);", workdir=ARTIFACTS, basename="valid")
        self.assertTrue(result.success)
        self.assertEqual(result.exit_code, 0)
        self.assertTrue(result.png_bytes)
        self.assertGreater(len(result.png_bytes), 0)

    def test_malformed_scad_fails_cleanly(self):
        result = render_to_png("cube([4,4,4]", workdir=ARTIFACTS, basename="malformed")
        self.assertFalse(result.success)
        self.assertNotEqual(result.exit_code, 0)
        self.assertIsNone(result.png_bytes)
        self.assertIn("ERROR", result.stderr.upper())

    def test_missing_binary_returns_failed_result_not_exception(self):
        original = scad_render.find_openscad_binary
        scad_render.find_openscad_binary = lambda: (_ for _ in ()).throw(
            FileNotFoundError("no openscad")
        )
        try:
            result = render_to_png("cube([1,1,1]);", workdir=ARTIFACTS, basename="nobinary")
            self.assertFalse(result.success)
            self.assertEqual(result.exit_code, -1)
            self.assertIn("no openscad", result.stderr)
        finally:
            scad_render.find_openscad_binary = original


if __name__ == "__main__":
    unittest.main()
