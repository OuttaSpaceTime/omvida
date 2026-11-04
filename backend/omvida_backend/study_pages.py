"""The wiki pages study has touched, kept until they are cleared (the wiki panel's "From study").

A file of the app's own, not the study repo's: the list is where one reader has got to, not
study material, so it has no place in the repo's git history or in the deck. It is all this
service writes outside the study repo.

Under `~/.local/state/omvida`, spelled from HOME and never from XDG_STATE_HOME: bin/sandbox
moves HOME, and this laptop's session sets XDG_STATE_HOME, so honouring it would have the tests
and screenshots write over the real list.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

FILE = "study-pages.json"


def default_dir() -> Path:
    return Path.home() / ".local" / "state" / "omvida"


def load(state_dir: Path, pages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """The saved list as the wiki now stands: `pages` is the index's.

    A page renamed or deleted since cannot be opened, so it is left out, and a title takes the
    page's current one. A file that doesn't parse, or an entry of the wrong shape, reads as
    nothing: this is a reading list, nothing to stop the app over, and the next change writes
    a good one.
    """
    try:
        saved = json.loads((state_dir / FILE).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    if not isinstance(saved, list):
        return []
    titles = {p["path"]: p["title"] for p in pages}
    out = []
    for entry in saved:
        path = entry.get("path") if isinstance(entry, dict) else None
        if isinstance(path, str) and path in titles:
            lapsed = entry.get("lapsed")
            out.append({"path": path, "title": titles[path], "lapsed": lapsed if isinstance(lapsed, list) else []})
    return out


def save(state_dir: Path, entries: list[dict[str, Any]]) -> dict[str, Any]:
    """Replace the list. Through a rename, so an app killed mid-write leaves the old list whole."""
    state_dir.mkdir(parents=True, exist_ok=True)
    tmp = state_dir / (FILE + ".tmp")
    tmp.write_text(json.dumps(entries, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    os.replace(tmp, state_dir / FILE)
    return {"saved": len(entries)}
