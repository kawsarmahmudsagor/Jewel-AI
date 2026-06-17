"""Robust extraction of a single JSON object from an LLM response.

LLMs frequently wrap JSON in markdown fences, prepend a sentence of preamble,
or append commentary after the closing brace. A naive json.loads(raw) then
fails with errors like "Extra data: line N column M". This helper locates the
first balanced top-level JSON object (or array) in the text and parses only that,
ignoring anything before or after it.
"""

import json
from typing import Any


def _strip_code_fences(text: str) -> str:
    """Remove a leading/trailing markdown code fence if present.

    Handles ```json ... ``` and ``` ... ``` whether or not the closing
    fence is on its own line.
    """
    t = text.strip()
    if not t.startswith("```"):
        return t
    # drop the opening fence line (which may carry a language tag, e.g. ```json)
    newline = t.find("\n")
    if newline == -1:
        return t
    t = t[newline + 1 :]
    # drop a trailing fence if present
    fence = t.rfind("```")
    if fence != -1:
        t = t[:fence]
    return t.strip()


def _find_balanced_span(text: str) -> str | None:
    """Return the substring covering the first balanced {..} or [..] block.

    Brace counting is string-aware so braces inside JSON string values (and
    escaped quotes) do not throw off the balance.
    """
    start = None
    opener = None
    closer = None
    for i, ch in enumerate(text):
        if ch in "{[":
            start = i
            opener = ch
            closer = "}" if ch == "{" else "]"
            break
    if start is None:
        return None

    depth = 0
    in_string = False
    escape = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == opener:
            depth += 1
        elif ch == closer:
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    return None  # unbalanced / truncated


def parse_llm_json(raw: str) -> Any:
    """Parse a JSON object/array from a raw LLM response, tolerating fences,
    preamble and trailing commentary.

    Raises ValueError with a helpful message if no valid JSON can be recovered.
    """
    if raw is None:
        raise ValueError("LLM returned no content.")

    candidates = []

    fenced = _strip_code_fences(raw)
    candidates.append(fenced)

    # try the balanced-span extraction on both the fenced and the raw text
    for source in (fenced, raw):
        span = _find_balanced_span(source)
        if span is not None:
            candidates.append(span)

    last_err = None
    for cand in candidates:
        cand = cand.strip()
        if not cand:
            continue
        try:
            return json.loads(cand)
        except json.JSONDecodeError as e:
            last_err = e
            continue

    snippet = raw.strip()[:300]
    raise ValueError(
        f"Could not parse JSON from LLM response ({last_err}). "
        f"First 300 chars:\n{snippet}"
    )