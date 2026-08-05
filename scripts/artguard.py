#!/usr/bin/env python3
"""Never overwrite art a human has touched.

THE PROBLEM THIS EXISTS FOR. Almost every sprite in this project is GENERATED - derived
from the game's own render, or produced by PixelLab and post-processed. Regenerating is
cheap and will happen often. But the whole point of shipping PNGs on a pixel grid with a
locked palette is that Louis can open one in Aseprite and nudge it, and a generator that
silently clobbers a hand edit turns that from a feature into a trap. The edit does not
error, it just quietly disappears, and it disappears at the exact moment someone re-runs
a script for an unrelated reason.

HOW IT WORKS. Every guarded write records the SHA-256 of the bytes it wrote in
Assets/.generated.json. Before the next write, the file on disk is hashed again:

  - hash matches what we last wrote  -> nobody has touched it, overwrite freely
  - hash differs                     -> a human edited it, SKIP and say so
  - no record at all                 -> unknown provenance, treat as hand-made, SKIP

The last case is deliberately conservative. An unrecorded file is more likely to be
something drawn by hand than something a generator forgot to record, and the cost of
being wrong in that direction is one --force flag, against losing work in the other.

  scripts/... --force        overwrite regardless, and re-record
  scripts/... --relock       do not write, just record what is on disk as canonical
                             (use after deliberately hand-editing a generated file, so
                             the guard stops warning about it and starts protecting it)
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "Assets" / ".generated.json"


def _load() -> dict:
    if LEDGER.exists():
        try:
            return json.loads(LEDGER.read_text())
        except json.JSONDecodeError:
            return {}
    return {}


def _save(d: dict) -> None:
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    LEDGER.write_text(json.dumps(dict(sorted(d.items())), indent=2) + "\n")


def _sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def rel(path: Path) -> str:
    return str(Path(path).resolve().relative_to(ROOT))


def is_hand_edited(path: Path) -> bool:
    """True if the file exists and is not byte-identical to what we last wrote."""
    p = Path(path)
    if not p.exists():
        return False
    return _load().get(rel(p)) != _sha(p.read_bytes())


def save_guarded(path: Path, save_fn, force: bool = False) -> str:
    """Write via save_fn(tmp_path), unless the target was hand-edited.

    Returns one of "written", "skipped", "forced". save_fn takes the destination path so
    callers keep using PIL's own save and nothing has to marshal bytes by hand.
    """
    p = Path(path)
    edited = is_hand_edited(p)
    if edited and not force:
        return "skipped"
    save_fn(p)
    d = _load()
    d[rel(p)] = _sha(p.read_bytes())
    _save(d)
    return "forced" if edited else "written"


def relock(paths) -> int:
    """Record whatever is currently on disk as canonical, writing nothing."""
    d = _load()
    n = 0
    for path in paths:
        p = Path(path)
        if p.exists():
            d[rel(p)] = _sha(p.read_bytes())
            n += 1
    _save(d)
    return n


def report(results: dict) -> None:
    skipped = [k for k, v in results.items() if v == "skipped"]
    if skipped:
        print(f"\n{len(skipped)} file(s) SKIPPED - they differ from what was last generated,")
        print("so they look hand-edited and were left alone:")
        for k in skipped:
            print(f"    {k}")
        print("  --force to overwrite them, or --relock to accept them as the new baseline.")


if __name__ == "__main__":
    # `python scripts/artguard.py --relock [paths...]` - record what is on disk as
    # canonical. With no paths it takes every PNG under Assets/, which is how the
    # ledger is seeded the first time (before it exists, EVERY file looks hand-made
    # and every generator refuses to write, which is correct but unhelpful on day one).
    import sys
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    paths = [Path(a) for a in args] or sorted((ROOT / "Assets").rglob("*.png"))
    print(f"locked {relock(paths)} file(s) into {rel(LEDGER)}")
