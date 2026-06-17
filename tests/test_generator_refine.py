import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import generator  # noqa: E402
from generator import refine, RefineResult  # noqa: E402
from scad_render import RenderResult  # noqa: E402


def fake_render(success, scad_code, exit_code=0, stderr=""):
    return RenderResult(
        success=success,
        png_bytes=b"PNGDATA" if success else None,
        stdout="",
        stderr=stderr,
        exit_code=exit_code,
        scad_path="fake.scad",
    )


class TestRefineLoop(unittest.TestCase):
    def setUp(self):
        self.analysis = {"expertAnalysisQuestionnaire": {"sections": {}}}
        self.image_bytes = b"FAKEJPEG"
        self.content_type = "image/jpeg"

    @patch("generator.render_to_png")
    @patch("generator._call_llm_visual_critique")
    def test_immediate_accept(self, mock_critique, mock_render):
        mock_render.return_value = fake_render(True, "code_v0")
        mock_critique.return_value = {
            "status": "final", "scad_code": "code_v0",
            "section_9": {"note": "ok"}, "notes": "looks good",
        }

        result = refine(self.analysis, "code_v0", self.image_bytes, self.content_type, max_rounds=3)

        self.assertEqual(result.status, "accepted")
        self.assertEqual(result.scad_code, "code_v0")
        self.assertEqual(len(result.rounds), 1)
        self.assertEqual(
            result.analysis["expertAnalysisQuestionnaire"]["sections"]["9_cadReconstructionParameters"],
            {"note": "ok"},
        )

    @patch("generator.render_to_png")
    @patch("generator._call_llm_fix_error")
    @patch("generator._call_llm_visual_critique")
    def test_error_then_fix_then_final(self, mock_critique, mock_fix, mock_render):
        mock_render.side_effect = [
            fake_render(False, "broken", exit_code=1, stderr="ERROR: parse error"),
            fake_render(True, "fixed_code"),
        ]
        mock_fix.return_value = {"scad_code": "fixed_code", "notes": "fixed syntax"}
        mock_critique.return_value = {
            "status": "final", "scad_code": "fixed_code", "section_9": {}, "notes": "accepted",
        }

        result = refine(self.analysis, "broken", self.image_bytes, self.content_type, max_rounds=3)

        self.assertEqual(result.status, "accepted")
        self.assertEqual(result.scad_code, "fixed_code")
        self.assertEqual(len(result.rounds), 2)
        self.assertEqual(result.rounds[0].kind, "fix_error")
        self.assertEqual(result.rounds[1].kind, "visual_critique")

    @patch("generator.render_to_png")
    @patch("generator._call_llm_visual_critique")
    def test_cap_reached_returns_last_rendered_not_dangling_revision(self, mock_critique, mock_render):
        mock_render.side_effect = [
            fake_render(True, "code_v0"),
            fake_render(True, "code_v1"),
        ]
        mock_critique.side_effect = [
            {"status": "revise", "scad_code": "code_v1", "section_9": {}, "notes": "tweak prongs"},
            {"status": "revise", "scad_code": "code_v2_never_rendered", "section_9": {}, "notes": "tweak more"},
        ]

        result = refine(self.analysis, "code_v0", self.image_bytes, self.content_type, max_rounds=2)

        self.assertEqual(result.status, "cap_reached")
        # must be code_v1 (the last code that actually rendered), not the
        # unrendered code_v2 the second critique round returned
        self.assertEqual(result.scad_code, "code_v1")
        self.assertEqual(len(result.rounds), 2)

    @patch("generator.render_to_png")
    @patch("generator._call_llm_fix_error")
    def test_no_successful_render_ever(self, mock_fix, mock_render):
        mock_render.return_value = fake_render(False, "broken", exit_code=1, stderr="ERROR")
        mock_fix.return_value = {"scad_code": "still_broken", "notes": "tried"}

        result = refine(self.analysis, "broken", self.image_bytes, self.content_type, max_rounds=2)

        self.assertEqual(result.status, "no_successful_render")
        self.assertIsNone(result.final_png)
        self.assertEqual(len(result.rounds), 2)


if __name__ == "__main__":
    unittest.main()
