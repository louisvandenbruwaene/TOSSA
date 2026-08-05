#!/usr/bin/env python3
"""Fail if any text call in Game.gd passes a font size that skips ps().

WHY THIS IS A CHECK AND NOT A CONVENTION. The pixel font is only crisp at multiples
of 4 (ps() in Game.gd carries the engine-rendered sweep this was measured from). A
call that passes a raw size still draws - it just draws with uneven stems, so "220"
comes out as "ZZ0" and a D loses its bowl. That reads as a bad font rather than as a
bug, which means nobody goes looking for it. The only reliable moment to catch it is
when the call site is added.

WHY IT IS PYTHON AND NOT GREP. A line-based grep reports 45 false positives on this
file, because these calls wrap across lines and the size argument routinely sits on
the continuation line. Arguments have to be split with paren balancing, the same way
the original transform did it, or the check is noise and gets ignored.

Uses only the standard library, so it runs on the system python3 with no venv.
Exit 0 clean, 1 with findings.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# call name -> zero-based index of the font-size argument
TARGETS = {
    "draw_string": 5,
    "draw_multiline_string": 5,
    "get_string_size": 3,
    "get_multiline_string_size": 3,
    "get_ascent": 0,
    "get_descent": 0,
}


def split_args(s: str, open_idx: int):
    depth = 0
    spans = []
    start = open_idx + 1
    i = open_idx
    while i < len(s):
        ch = s[i]
        if ch in "\"'":
            q = ch
            i += 1
            while i < len(s) and s[i] != q:
                i += 2 if s[i] == "\\" else 1
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                spans.append((start, i))
                return spans
        elif ch == "," and depth == 1:
            spans.append((start, i))
            start = i + 1
        i += 1
    return None


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "Game.gd")
    src = path.read_text(encoding="utf-8")
    names = "|".join(sorted(TARGETS, key=len, reverse=True))
    pat = re.compile(r"\b(" + names + r")\s*\(")

    bad = []
    for m in pat.finditer(src):
        line_start = src.rfind("\n", 0, m.start()) + 1
        if src[line_start:m.start()].lstrip().startswith("func "):
            continue
        spans = split_args(src, m.end() - 1)
        if not spans:
            continue
        idx = TARGETS[m.group(1)]
        if idx >= len(spans):
            continue
        arg = src[spans[idx][0]:spans[idx][1]].strip()
        if not arg or arg.startswith("ps("):
            continue
        bad.append((src.count("\n", 0, m.start()) + 1, m.group(1), arg[:48]))

    if not bad:
        return 0
    print(f"{len(bad)} text call(s) pass a raw font size - wrap the size argument in ps():")
    for line, name, arg in bad[:15]:
        print(f"    {path.name}:{line}  {name}(... {arg} ...)")
    if len(bad) > 15:
        print(f"    ... and {len(bad) - 15} more")
    return 1


if __name__ == "__main__":
    sys.exit(main())
