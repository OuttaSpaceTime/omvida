"""Omvida's wiki service: newline-delimited JSON over stdio, like the deck server.

    -> {"id": 1, "method": "page", "params": {"path": "security/csrf"}}
    <- {"id": 1, "result": {...}}     or {"id": 1, "error": {"message": "..."}}

and {"ready": true} once at start. The app keeps one running for its whole
life (JsonLineClient.qml). Requests are handled one at a time except the
methods in Service.concurrent.

The study repo is OMVIDA_STUDY_DIR, which bin/omvida sets.
"""

from __future__ import annotations

import json
import os
import sys
import threading
from collections.abc import Callable
from pathlib import Path
from typing import Any

from . import logs, rank, render, search, wiki


class Service:
    # Methods that run in a thread of their own: a deep qmd query takes seconds,
    # and the page clicked meanwhile shouldn't wait behind it.
    concurrent = frozenset({"search"})

    def __init__(self, study_dir: Path):
        self.study_dir = study_dir
        self.wiki_root = study_dir / "wiki"
        self._index: dict[str, Any] | None = None
        self._resolver: wiki.Resolver | None = None

    def _rebuild(self) -> dict:
        self._index = wiki.build_index(self.wiki_root)
        self._resolver = wiki.Resolver(self._index)
        return self._index

    def index(self, _p: dict) -> dict:
        return self._rebuild()

    def stamp(self, _p: dict) -> dict:
        return {"stamp": wiki.stamp(self.wiki_root)}

    def _current(self) -> tuple[dict, wiki.Resolver]:
        """The index and its resolver, rebuilt when a page changed on disk."""
        if self._index is None or self._index["stamp"] != wiki.stamp(self.wiki_root):
            self._rebuild()
        assert self._index is not None and self._resolver is not None
        return self._index, self._resolver

    def page(self, p: dict) -> dict | None:
        path = str(p.get("path", ""))
        file = wiki.safe_page_file(self.wiki_root, path)
        if file is None or not file.exists():
            return None
        idx, resolver = self._current()
        meta = next((x for x in idx["pages"] if x["path"] == path), None)
        if meta is None:
            return None
        _, body = wiki.read_page(file.read_text(encoding="utf-8"))
        return {"meta": meta, "blocks": render.render_blocks(body.strip(), resolver)}

    def markdown(self, p: dict) -> dict:
        """Any markdown (an Ask answer) rendered the way a page is, links resolved."""
        _, resolver = self._current()
        return {"blocks": render.render_blocks(str(p.get("text", "")), resolver)}

    def search(self, p: dict) -> dict:
        return search.search(self.study_dir, str(p.get("query", "")), str(p.get("mode", "fast")),
                             int(p.get("limit", 8)))

    def related(self, p: dict) -> list:
        return rank.related_pages(self._current()[0]["pages"], list(p.get("studied", [])),
                                  int(p.get("limit", 3)))

    def recent(self, p: dict) -> list:
        return rank.recently_studied_pages(self._current()[0]["pages"], list(p.get("studied", [])),
                                           int(p.get("limit", 8)))

    def log_session(self, p: dict) -> dict:
        return logs.append_session(self.study_dir, dict(p.get("entry", {})))

    def handlers(self) -> dict[str, Callable[[dict], Any]]:
        return {
            "index": self.index,
            "stamp": self.stamp,
            "page": self.page,
            "markdown": self.markdown,
            "search": self.search,
            "related": self.related,
            "recent": self.recent,
            "logSession": self.log_session,
        }


NOT_JSON = json.dumps({"id": None, "error": {"message": "request is not JSON"}})


def respond(handlers: dict[str, Callable[[dict], Any]], req: Any) -> str:
    """The response line for one parsed request."""
    rid = req.get("id") if isinstance(req, dict) else None
    method = req.get("method") if isinstance(req, dict) else None
    handler = handlers.get(method) if isinstance(method, str) else None
    if handler is None:
        return json.dumps({"id": rid, "error": {"message": f"unknown method: {method}"}})
    params = req.get("params") if isinstance(req.get("params"), dict) else {}
    try:
        return json.dumps({"id": rid, "result": handler(params)}, ensure_ascii=False)
    except Exception as exc:  # noqa: BLE001 - every failure goes back to the caller
        return json.dumps({"id": rid, "error": {"message": f"{type(exc).__name__}: {exc}"}})


def main() -> None:
    study = Path(os.environ.get("OMVIDA_STUDY_DIR", str(Path.home() / "Code" / "study"))).expanduser()
    svc = Service(study)
    handlers = svc.handlers()
    lock = threading.Lock()

    def write(s: str) -> None:
        with lock:
            sys.stdout.write(s + "\n")
            sys.stdout.flush()

    write(json.dumps({"ready": True}))
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            write(NOT_JSON)
            continue
        if isinstance(req, dict) and req.get("method") in svc.concurrent:
            threading.Thread(target=lambda r=req: write(respond(handlers, r)), daemon=True).start()
        else:
            write(respond(handlers, req))


if __name__ == "__main__":
    main()
