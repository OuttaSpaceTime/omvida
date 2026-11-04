"""Which wiki pages to offer: after a study session, and on the home screen.

Two orders, on purpose (the /study skill explains the difference):
- after a session every card came from that session, so recency is uniform
  and how many of its cards a page covers is the only signal. A page tied to
  a lapsed card ranks above one tied to an easy hit;
- the home screen spans weeks, where "when did I last touch this" is what
  helps, so it ranks by the latest review first and coverage second (the
  viewer's app/lib.ts).
"""

from __future__ import annotations

from typing import Any


def related_pages(
    pages: list[dict[str, Any]],
    studied: list[dict[str, Any]],
    limit: int = 3,
) -> list[dict[str, Any]]:
    """Pages for the cards a session served, /study Phase 4.

    `studied`: [{id, tags, lapsed}]. Matches on the pages' flashcard_ids first;
    only when nothing matches does it fall back to tag overlap, which is a
    weaker signal and would otherwise drown the direct matches.
    """
    ids = {c["id"] for c in studied}
    lapsed = {c["id"] for c in studied if c.get("lapsed")}
    scored = []
    for p in pages:
        hits = [i for i in p.get("flashcardIds", []) if i in ids]
        if hits:
            scored.append({
                "path": p["path"],
                "title": p["title"],
                "cards": len(hits),
                "lapsed": sum(1 for i in hits if i in lapsed),
                "via": "cards",
            })
    if not scored:
        tag_lapsed: dict[str, bool] = {}
        for c in studied:
            for t in c.get("tags", []):
                tag_lapsed[t.lower()] = tag_lapsed.get(t.lower(), False) or bool(c.get("lapsed"))
        for p in pages:
            shared = [t for t in p.get("tags", []) if t.lower() in tag_lapsed]
            if shared:
                scored.append({
                    "path": p["path"],
                    "title": p["title"],
                    "cards": len(shared),
                    "lapsed": sum(1 for t in shared if tag_lapsed[t.lower()]),
                    "via": "tags",
                })
    scored.sort(key=lambda s: (-s["lapsed"], -s["cards"], s["title"].lower()))
    return scored[:limit]


def pages_of_card(pages: list[dict[str, Any]], card_id: str) -> list[dict[str, Any]]:
    """The pages a card belongs to, by their flashcard_ids: what rating it touches.

    No tag fallback and no limit, unlike related_pages. That offers a session's best few at its
    end; this is asked per card and its answers pile up in a list kept until cleared, where
    every page sharing a tag with a card would soon bury the pages the cards actually came from.
    """
    return [{"path": p["path"], "title": p["title"]} for p in pages if card_id in p.get("flashcardIds", [])]


def recently_studied_pages(
    pages: list[dict[str, Any]],
    studied: list[dict[str, Any]],
    limit: int = 8,
) -> list[dict[str, Any]]:
    """Home screen's Last studied: `studied` is [{id, at: YYYY-MM-DD}]."""
    at = {s["id"]: s["at"] for s in studied}
    out = []
    for p in pages:
        dates = [at[i] for i in p.get("flashcardIds", []) if i in at]
        if dates:
            out.append({"path": p["path"], "title": p["title"], "folder": p.get("folder", ""),
                        "cards": len(dates), "lastStudied": max(dates)})
    out.sort(key=lambda e: (e["lastStudied"], e["cards"]), reverse=True)
    return out[:limit]
