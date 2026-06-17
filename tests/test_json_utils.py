import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from json_utils import parse_llm_json  # noqa: E402


class TestParseLlmJson(unittest.TestCase):
    def test_plain_json(self):
        self.assertEqual(parse_llm_json('{"a": 1}'), {"a": 1})

    def test_markdown_fenced_json(self):
        raw = '```json\n{"a": 1}\n```'
        self.assertEqual(parse_llm_json(raw), {"a": 1})

    def test_preamble_and_trailing_commentary(self):
        raw = 'Sure, here is the JSON:\n{"a": 1}\nLet me know if you need changes.'
        self.assertEqual(parse_llm_json(raw), {"a": 1})

    def test_literal_control_character_inside_string_value(self):
        """Reproduces a real failure: the model emitted a literal raw
        newline inside scad_code instead of the requested \\n escape.
        Strict JSON rejects this outright even though the structure is
        otherwise valid -- this must still parse."""
        raw = '{"status": "final", "scad_code": "line one\nline two"}'
        result = parse_llm_json(raw)
        self.assertEqual(result["status"], "final")
        self.assertIn("line one", result["scad_code"])
        self.assertIn("line two", result["scad_code"])

    def test_literal_control_character_deep_in_long_payload(self):
        """Same bug class as above, but reproduced closer to the actual
        production failure: a large multi-field payload with a sizable
        code string containing several literal raw newlines."""
        code_with_raw_newlines = (
            "/*\n   Procedural Ring Model\n*/\nmodule ring_band() {\n    "
            "cube([1,1,1]);\n}\n"
        )
        raw = (
            '{\n'
            '  "checklist": {"band_style_matches": true},\n'
            '  "status": "final",\n'
            f'  "scad_code": "{code_with_raw_newlines}",\n'
            '  "notes": "looks good"\n'
            '}'
        )
        result = parse_llm_json(raw)
        self.assertEqual(result["status"], "final")
        self.assertIn("module ring_band()", result["scad_code"])

    def test_unparseable_raises_value_error_with_snippet(self):
        with self.assertRaises(ValueError):
            parse_llm_json("not json at all, just prose")


if __name__ == "__main__":
    unittest.main()
