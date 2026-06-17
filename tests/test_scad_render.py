import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import scad_render  # noqa: E402
from scad_render import (  # noqa: E402
    render_to_png,
    render_named_angles,
    photo_matching_camera_eye,
    NAMED_CAMERA_EYES,
)

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

    def test_camera_eye_renders_successfully(self):
        result = render_to_png(
            "cube([4,4,4]);", workdir=ARTIFACTS, basename="with_camera",
            camera_eye=(0.0, -100.0, 0.0),
        )
        self.assertTrue(result.success)
        self.assertTrue(result.png_bytes)


class TestPhotoMatchingCameraEye(unittest.TestCase):
    def test_face_on_gives_pure_front_eye(self):
        eye = photo_matching_camera_eye({"viewAngle": "face_on", "estimatedTiltDegrees": 90})
        x, y, z = eye
        self.assertAlmostEqual(x, 0.0, places=4)
        self.assertLess(y, 0)
        self.assertAlmostEqual(z, 0.0, places=4)

    def test_top_down_gives_pure_top_eye_regardless_of_view_angle(self):
        eye = photo_matching_camera_eye({"viewAngle": "oblique", "estimatedTiltDegrees": 0})
        x, y, z = eye
        self.assertAlmostEqual(x, 0.0, places=4)
        self.assertAlmostEqual(y, 0.0, places=4)
        self.assertGreater(z, 0)

    def test_missing_photo_context_degrades_to_a_generic_three_quarter_angle(self):
        eye = photo_matching_camera_eye(None)
        x, y, z = eye
        # should not raise, and should not be a degenerate (0,0,0) eye
        self.assertGreater(x ** 2 + y ** 2 + z ** 2, 0)

    def test_three_quarter_gets_nonzero_azimuth_offset(self):
        face_on = photo_matching_camera_eye({"viewAngle": "face_on", "estimatedTiltDegrees": 90})
        three_quarter = photo_matching_camera_eye({"viewAngle": "three_quarter", "estimatedTiltDegrees": 90})
        self.assertNotEqual(face_on[0], three_quarter[0])


class TestRenderNamedAngles(unittest.TestCase):
    def test_default_angles_are_top_front_left_only(self):
        """Back/right are skipped by default -- a ring is symmetric enough
        that they add little over their mirror counterparts, and rendering
        them costs real time for marginal benefit."""
        results = render_named_angles("cube([4,4,4]);", workdir=ARTIFACTS, basename_prefix="named")
        self.assertEqual(set(results.keys()), {"top", "front", "left"})
        for name, result in results.items():
            with self.subTest(angle=name):
                self.assertTrue(result.success)
                self.assertTrue(result.png_bytes)

    def test_all_five_presets_still_available_when_explicitly_requested(self):
        results = render_named_angles(
            "cube([4,4,4]);", workdir=ARTIFACTS, basename_prefix="allfive",
            angles=tuple(NAMED_CAMERA_EYES.keys()),
        )
        self.assertEqual(set(results.keys()), set(NAMED_CAMERA_EYES.keys()))

    def test_subset_of_angles_only_renders_those(self):
        results = render_named_angles(
            "cube([4,4,4]);", workdir=ARTIFACTS, basename_prefix="subset", angles=("top", "front")
        )
        self.assertEqual(set(results.keys()), {"top", "front"})

    def test_scad_file_written_once_and_reused_across_angles(self):
        workdir = ARTIFACTS / "reuse_check"
        render_named_angles("cube([4,4,4]);", workdir=workdir, basename_prefix="shared")
        scad_files = list(workdir.glob("shared*.scad"))
        png_files = list(workdir.glob("shared*.png"))
        self.assertEqual(len(scad_files), 1)
        self.assertEqual(len(png_files), 3)


if __name__ == "__main__":
    unittest.main()
