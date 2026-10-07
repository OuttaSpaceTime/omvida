"""Wiki search through qmd, the study repo's local search engine (AGENTS.md, Search).

Two speeds. `fast` is qmd's BM25 keyword search, about 0.2s, quick enough to
run as you type. `deep` is the hybrid query (keyword plus vector, with query
expansion and no LLM re-rank), about 6s warm, so it only runs when asked for.
Re-ranking stays off, as the skills keep it off for lookups: it adds about 8s
per call, every call.

qmd keeps its index in the study repo (`.qmd/`), so it runs with that repo as
its working directory.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import threading
from pathlib import Path
from typing import Any

QMD_FILE = re.compile(r"^qmd://wiki/(.+)\.md$")
HUNK = re.compile(r"^@@[^@]*@@[^\n]*\n+")


def qmd_argv(query: str, mode: str, limit: int) -> list[str]:
    if mode == "deep":
        return ["qmd", "query", "--no-rerank", "--format", "json", "-n", str(limit), "-c", "wiki", query]
    return ["qmd", "search", "--format", "json", "-n", str(limit), "-c", "wiki", query]


def parse_qmd(stdout: str) -> list[dict[str, Any]]:
    """qmd prints progress lines before the JSON on some commands; take the array."""
    start = stdout.find("[")
    if start == -1:
        return []
    try:
        rows = json.loads(stdout[start:])
    except json.JSONDecodeError:
        return []
    out = []
    for r in rows if isinstance(rows, list) else []:
        m = QMD_FILE.match(str(r.get("file", "")))
        if not m:
            continue
        snippet = HUNK.sub("", str(r.get("snippet", ""))).strip()
        out.append({
            "path": m.group(1),
            "title": r.get("title") or m.group(1),
            "score": r.get("score", 0),
            "line": r.get("line"),
            "snippet": re.sub(r"\s+", " ", snippet)[:240],
        })
    return out


# The search in flight. A new one kills it: typing spawns a search per pause,
# and only the newest answer is wanted.
_running: subprocess.Popen | None = None
_lock = threading.Lock()


def search(study_dir: Path, query: str, mode: str = "fast", limit: int = 8) -> dict[str, Any]:
    global _running
    query = query.strip()
    if not query:
        return {"results": [], "error": None}
    if shutil.which("qmd") is None:
        return {"results": [], "error": "qmd is not installed (npm install -g @tobilu/qmd)"}
    proc = subprocess.Popen(
        qmd_argv(query, mode, limit),
        cwd=study_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env={**os.environ, "NO_COLOR": "1"},
    )
    with _lock:
        if _running is not None and _running.poll() is None:
            _running.kill()
        _running = proc
    try:
        stdout, stderr = proc.communicate(timeout=60 if mode == "deep" else 15)
    except subprocess.TimeoutExpired:
        proc.kill()
        return {"results": [], "error": "search timed out"}
    if proc.returncode != 0 and not stdout.strip():
        if proc.returncode < 0:
            return {"results": [], "error": None}  # superseded by a newer search
        first = (stderr.strip().split("\n") or [""])[0]
        return {"results": [], "error": first or f"qmd exited {proc.returncode}"}
    return {"results": parse_qmd(stdout), "error": None}
