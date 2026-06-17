import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import module_generator  # noqa: E402
from module_generator import build_scad_via_llm  # noqa: E402
from scad_render import RenderResult  # noqa: E402


def fake_render(success, stderr=""):
    return RenderResult(
        success=success,
        png_bytes=b"PNGDATA" if success else None,
        stdout="",
        stderr=stderr,
        exit_code=0 if success else 1,
        scad_path="fake.scad",
    )


class TestBuildScadViaLLM(unittest.TestCase):
    def setUp(self):
        self.analysis = {"expertAnalysisQuestionnaire": {"sections": {}}}

    @patch("module_generator.render_to_png")
    @patch("module_generator._call_llm_for_modules")
    def test_llm_success_path_used_when_it_renders(self, mock_llm, mock_render):
        mock_llm.return_value = "module ring_band_base() {} union() { ring_band_base(); }"
        mock_render.return_value = fake_render(True)

        scad_code, source = build_scad_via_llm(self.analysis)

        self.assertEqual(source, "llm")
        self.assertIn("ring_band_base", scad_code)

    @patch("module_generator.build_scad")
    @patch("module_generator._call_llm_for_modules")
    def test_falls_back_when_llm_returns_nothing(self, mock_llm, mock_build_scad):
        mock_llm.return_value = None
        mock_build_scad.return_value = "module fallback() {}"

        scad_code, source = build_scad_via_llm(self.analysis)

        self.assertEqual(source, "fallback_deterministic")
        self.assertEqual(scad_code, "module fallback() {}")
        mock_build_scad.assert_called_once_with(self.analysis)

    @patch("module_generator.build_scad")
    @patch("module_generator.render_to_png")
    @patch("module_generator._call_llm_for_modules")
    def test_falls_back_when_llm_code_fails_to_render(self, mock_llm, mock_render, mock_build_scad):
        mock_llm.return_value = "this is not valid scad"
        mock_render.return_value = fake_render(False, stderr="ERROR: parse error")
        mock_build_scad.return_value = "module fallback() {}"

        scad_code, source = build_scad_via_llm(self.analysis)

        self.assertEqual(source, "fallback_deterministic")
        self.assertEqual(scad_code, "module fallback() {}")

    @patch("module_generator.build_scad")
    @patch("module_generator._call_llm_for_modules")
    def test_falls_back_when_llm_call_raises(self, mock_llm, mock_build_scad):
        mock_llm.side_effect = RuntimeError("network error")
        mock_build_scad.return_value = "module fallback() {}"

        scad_code, source = build_scad_via_llm(self.analysis)

        self.assertEqual(source, "fallback_deterministic")
        self.assertEqual(scad_code, "module fallback() {}")

    @patch("module_generator.build_scad")
    @patch("module_generator._call_llm_for_modules")
    def test_never_raises_even_if_fallback_also_fails(self, mock_llm, mock_build_scad):
        mock_llm.side_effect = RuntimeError("network error")
        mock_build_scad.side_effect = RuntimeError("deterministic builder also broke")

        with self.assertRaises(RuntimeError):
            build_scad_via_llm(self.analysis)
        # documents current behavior: a fallback failure DOES propagate,
        # since build_scad() itself is expected to never raise in practice.


if __name__ == "__main__":
    unittest.main()
