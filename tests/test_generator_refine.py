import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import generator  # noqa: E402
from generator import refine, RefineResult, _call_llm  # noqa: E402
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


FULL_PASS_CHECKLIST = {
    "band_style_matches": True,
    "stone_shape_count_matches": True,
    "prong_count_and_style_matches": True,
    "decorative_features_match": True,
    "no_floating_or_buried_geometry": True,
}


class TestRefineLoop(unittest.TestCase):
    def setUp(self):
        self.analysis = {"expertAnalysisQuestionnaire": {"sections": {}}}
        self.image_bytes = b"FAKEJPEG"
        self.content_type = "image/jpeg"

    @patch("generator.render_named_angles")
    @patch("generator.render_to_png")
    @patch("generator._call_llm_visual_critique")
    def test_immediate_accept(self, mock_critique, mock_render, mock_secondary):
        mock_render.return_value = fake_render(True, "code_v0")
        mock_secondary.return_value = {}
        mock_critique.return_value = {
            "status": "final", "scad_code": "code_v0",
            "checklist": FULL_PASS_CHECKLIST,
            "section_9": {"note": "ok"}, "notes": "looks good",
        }

        result = refine(
            self.analysis, "code_v0", self.image_bytes, self.content_type,
            max_rounds=3, min_rounds=1,
        )

        self.assertEqual(result.status, "accepted")
        self.assertEqual(result.scad_code, "code_v0")
        self.assertEqual(len(result.rounds), 1)
        self.assertEqual(
            result.analysis["expertAnalysisQuestionnaire"]["sections"]["9_cadReconstructionParameters"],
            {"note": "ok"},
        )

    @patch("generator.render_named_angles")
    @patch("generator.render_to_png")
    @patch("generator._call_llm_fix_error")
    @patch("generator._call_llm_visual_critique")
    def test_error_then_fix_then_final(self, mock_critique, mock_fix, mock_render, mock_secondary):
        mock_render.side_effect = [
            fake_render(False, "broken", exit_code=1, stderr="ERROR: parse error"),
            fake_render(True, "fixed_code"),
        ]
        mock_secondary.return_value = {}
        mock_fix.return_value = {"scad_code": "fixed_code", "notes": "fixed syntax"}
        mock_critique.return_value = {
            "status": "final", "scad_code": "fixed_code",
            "checklist": FULL_PASS_CHECKLIST,
            "section_9": {}, "notes": "accepted",
        }

        result = refine(
            self.analysis, "broken", self.image_bytes, self.content_type,
            max_rounds=3, min_rounds=1,
        )

        self.assertEqual(result.status, "accepted")
        self.assertEqual(result.scad_code, "fixed_code")
        self.assertEqual(len(result.rounds), 2)
        self.assertEqual(result.rounds[0].kind, "fix_error")
        self.assertEqual(result.rounds[1].kind, "visual_critique")

    @patch("generator.render_named_angles")
    @patch("generator.render_to_png")
    @patch("generator._call_llm_visual_critique")
    def test_cap_reached_returns_last_rendered_not_dangling_revision(
        self, mock_critique, mock_render, mock_secondary
    ):
        mock_render.side_effect = [
            fake_render(True, "code_v0"),
            fake_render(True, "code_v1"),
        ]
        mock_secondary.return_value = {}
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

    @patch("generator.render_named_angles")
    @patch("generator.render_to_png")
    @patch("generator._call_llm_visual_critique")
    def test_missing_checklist_forces_revise_despite_status_final(
        self, mock_critique, mock_render, mock_secondary
    ):
        """A bare status:'final' with no checklist must NOT be trusted --
        this is exactly the rubber-stamping pattern that let the floating
        pavé/oversized-halo bugs ship before."""
        mock_render.return_value = fake_render(True, "code_v0")
        mock_secondary.return_value = {}
        mock_critique.return_value = {
            "status": "final", "scad_code": "code_v0",
            "section_9": {}, "notes": "looks good",
            # no "checklist" key at all
        }

        result = refine(
            self.analysis, "code_v0", self.image_bytes, self.content_type,
            max_rounds=2, min_rounds=1,
        )

        self.assertEqual(result.status, "cap_reached")
        self.assertEqual(len(result.rounds), 2)
        self.assertTrue(all(r.llm_status == "revise" for r in result.rounds))

    @patch("generator.render_named_angles")
    @patch("generator.render_to_png")
    @patch("generator._call_llm_visual_critique")
    def test_one_false_checklist_item_forces_revise(self, mock_critique, mock_render, mock_secondary):
        mock_render.return_value = fake_render(True, "code_v0")
        mock_secondary.return_value = {}
        bad_checklist = dict(FULL_PASS_CHECKLIST, prong_count_and_style_matches=False)
        mock_critique.return_value = {
            "status": "final", "scad_code": "code_v0",
            "checklist": bad_checklist,
            "section_9": {}, "notes": "prongs look like spikes",
        }

        result = refine(
            self.analysis, "code_v0", self.image_bytes, self.content_type,
            max_rounds=2, min_rounds=1,
        )

        self.assertEqual(result.status, "cap_reached")
        self.assertTrue(all(r.llm_status == "revise" for r in result.rounds))

    @patch("generator.render_named_angles")
    @patch("generator.render_to_png")
    @patch("generator._call_llm_visual_critique")
    def test_min_rounds_floor_forces_extra_look_before_accepting(
        self, mock_critique, mock_render, mock_secondary
    ):
        """Even a fully-passing checklist on round 1 must not finalize
        before min_rounds visual-critique rounds have happened."""
        mock_render.side_effect = [fake_render(True, "code_v0"), fake_render(True, "code_v0")]
        mock_secondary.return_value = {}
        mock_critique.return_value = {
            "status": "final", "scad_code": "code_v0",
            "checklist": FULL_PASS_CHECKLIST,
            "section_9": {}, "notes": "looks good",
        }

        result = refine(
            self.analysis, "code_v0", self.image_bytes, self.content_type,
            max_rounds=3, min_rounds=2,
        )

        self.assertEqual(result.status, "accepted")
        self.assertEqual(len(result.rounds), 2)
        self.assertEqual(result.rounds[0].llm_status, "revise")
        self.assertEqual(result.rounds[1].llm_status, "final")

    @patch("generator.render_named_angles")
    @patch("generator.render_to_png")
    @patch("generator._call_llm_visual_critique")
    def test_angle_images_includes_matching_plus_successful_secondary_only(
        self, mock_critique, mock_render, mock_secondary
    ):
        """The critique call must receive the primary (photo-matching)
        render plus every secondary angle that actually rendered, and
        must NOT include angles that failed -- a failed secondary angle
        is just omitted, not a reason to fail the round."""
        mock_render.return_value = fake_render(True, "code_v0")
        mock_secondary.return_value = {
            "top": fake_render(True, "code_v0"),
            "front": fake_render(True, "code_v0"),
            "back": fake_render(False, "code_v0", exit_code=1, stderr="ERROR"),
            "left": fake_render(True, "code_v0"),
            "right": fake_render(True, "code_v0"),
        }
        mock_critique.return_value = {
            "status": "final", "scad_code": "code_v0",
            "checklist": FULL_PASS_CHECKLIST,
            "section_9": {}, "notes": "looks good",
        }

        refine(
            self.analysis, "code_v0", self.image_bytes, self.content_type,
            max_rounds=3, min_rounds=1,
        )

        self.assertEqual(mock_critique.call_count, 1)
        angle_images = mock_critique.call_args[0][3]
        self.assertIn("matching_photo_angle", angle_images)
        self.assertIn("top", angle_images)
        self.assertIn("front", angle_images)
        self.assertIn("left", angle_images)
        self.assertIn("right", angle_images)
        self.assertNotIn("back", angle_images)


class TestCallLlmParseResilience(unittest.TestCase):
    """The exact bug class that produced a real 502: a response that
    parse_llm_json cannot recover must not crash the caller -- it should
    degrade to an empty dict, which every refine() branch already treats
    as 'missing status/checklist, default to revise'."""

    def _fake_response(self, content: str):
        return SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=content))]
        )

    @patch("generator._client")
    def test_unparseable_response_returns_empty_dict_not_raise(self, mock_client):
        mock_client.chat.completions.create.return_value = self._fake_response(
            "this is not JSON at all, just prose"
        )
        result = _call_llm("system prompt", [{"type": "text", "text": "hi"}])
        self.assertEqual(result, {})

    @patch("generator._client")
    def test_well_formed_response_still_parses_normally(self, mock_client):
        mock_client.chat.completions.create.return_value = self._fake_response(
            '{"status": "final"}'
        )
        result = _call_llm("system prompt", [{"type": "text", "text": "hi"}])
        self.assertEqual(result, {"status": "final"})


if __name__ == "__main__":
    unittest.main()
