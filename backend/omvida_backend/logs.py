"""Study session entries in the study repo's daily logs (AGENTS.md, Session Logs).

`logs/MM/YYYY-MM-DD.md`, append-only, written by the study repo's
scripts/session_log.py (path, `# YYYY-MM-DD` header, `## Session N — Study
(HH:MM)` numbering across every session type). This module only decides the
Study entry's fields, following /study's Phase 4 template, so /progress and
/reflect read app sessions and chat sessions alike.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

# The path, day header, numbering and append are the study repo's
# (scripts/session_log.py, the one writer of the logs); __init__ puts the
# study checkout on sys.path. Only the Study entry's fields are decided here.
from scripts.session_log import append_session as _append_session


def study_fields(e: dict[str, Any]) -> list[tuple[str, str]]:
    reviewed = e.get("cardsReviewed", 0)
    repeats = e.get("repeats", 0)
    fields = [("Cards reviewed", f"{reviewed}" + (f" (+{repeats} intra-day repeats)" if repeats else ""))]
    if e.get("accuracy") is not None:
        fields.append(("Accuracy", f"{round(e['accuracy'] * 100)}%"))
    if e.get("calibration"):
        fields.append(("Calibration", str(e["calibration"])))
    lapses = e.get("lapses") or []
    fields.append(("Lapses", ", ".join(lapses) if lapses else "none"))
    if e.get("leeches"):
        fields.append(("Leeches", "; ".join(e["leeches"])))
    if e.get("overrides"):
        fields.append(("Rating overrides", f"{e['overrides']} (suggested rating changed by hand)"))
    if e.get("duration"):
        fields.append(("Duration", str(e["duration"])))
    if e.get("wikiExplored"):
        fields.append(("Wiki explored", ", ".join(f"[[{p}]]" for p in e["wikiExplored"])))
    fields.append(("Surface", "Omvida app"))
    return fields


def append_session(study_dir: Path, entry: dict[str, Any], now: datetime | None = None) -> dict[str, Any]:
    path, n = _append_session("Study", study_fields(entry), now, study_dir)
    return {"path": str(path), "session": n}
