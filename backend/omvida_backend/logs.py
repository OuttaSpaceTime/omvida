"""Study session entries in the study repo's daily logs (AGENTS.md, Session Logs).

`logs/MM/YYYY-MM-DD.md`, append-only. A new day's file starts with
`# YYYY-MM-DD`. Sessions are `## Session N — Study (HH:MM)`, where N counts
every session type that day, so it is read off the file just before appending.
The entry follows /study's Phase 4 template, so /progress and /reflect read
app sessions and chat sessions alike.
"""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Any

SESSION = re.compile(r"^## Session (\d+)\b", re.M)


def log_path(study_dir: Path, now: datetime) -> Path:
    return study_dir / "logs" / f"{now.month:02d}" / f"{now:%Y-%m-%d}.md"


def next_session_number(text: str) -> int:
    nums = [int(n) for n in SESSION.findall(text)]
    return max(nums) + 1 if nums else 1


def format_entry(n: int, now: datetime, e: dict[str, Any]) -> str:
    lines = [f"## Session {n} — Study ({now:%H:%M})"]
    reviewed = e.get("cardsReviewed", 0)
    repeats = e.get("repeats", 0)
    lines.append(f"- **Cards reviewed:** {reviewed}" + (f" (+{repeats} intra-day repeats)" if repeats else ""))
    if e.get("accuracy") is not None:
        lines.append(f"- **Accuracy:** {round(e['accuracy'] * 100)}%")
    if e.get("calibration"):
        lines.append(f"- **Calibration:** {e['calibration']}")
    lapses = e.get("lapses") or []
    lines.append("- **Lapses:** " + (", ".join(lapses) if lapses else "none"))
    if e.get("leeches"):
        lines.append("- **Leeches:** " + "; ".join(e["leeches"]))
    if e.get("overrides"):
        lines.append(f"- **Rating overrides:** {e['overrides']} (suggested rating changed by hand)")
    if e.get("duration"):
        lines.append(f"- **Duration:** {e['duration']}")
    if e.get("wikiExplored"):
        lines.append("- **Wiki explored:** " + ", ".join(f"[[{p}]]" for p in e["wikiExplored"]))
    lines.append("- **Surface:** Omvida app")
    return "\n".join(lines) + "\n"


def append_session(study_dir: Path, entry: dict[str, Any], now: datetime | None = None) -> dict[str, Any]:
    now = now or datetime.now()
    path = log_path(study_dir, now)
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text(encoding="utf-8") if path.exists() else ""
    n = next_session_number(existing)
    chunk = ""
    if not existing:
        chunk = f"# {now:%Y-%m-%d}\n\n"
    elif not existing.endswith("\n\n"):
        chunk = "\n" if existing.endswith("\n") else "\n\n"
    chunk += format_entry(n, now, entry)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(chunk)
    return {"path": str(path), "session": n}
