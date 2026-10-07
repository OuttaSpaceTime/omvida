"""The study wiki as data: pages, their links both ways, the folder tree, the graph.

A port of the Next.js viewer's lib/wiki.ts (~/Code/study/wiki-viewer), kept to
the same rules so the two surfaces never disagree about what links where:

- Wikilinks resolve by exact path first. A bare name with no slash falls back
  to the one page with that slug, the way Obsidian does. A path-qualified
  target that doesn't match exactly is broken, and is never folder-corrected.
- Links inside fenced or inline code, and `![[embeds]]`, are not links.
- MOC pages (`*-index.md`) are not content. They become graph hubs, a link to
  one opens its folder, and they are dropped from every page's inbound and
  outbound lists.
- `wiki/indexes/` and dot-entries are skipped.

The wiki is read straight off disk on every index call: 68 pages parse in a
few milliseconds, so a cache would only add a way to show stale pages after
a Claude session writes one.
"""

from __future__ import annotations

import hashlib
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

import yaml

# The study repo's own rules for frontmatter, sections and links (its
# scripts/wiki), so this app, lint and the index agree on what a page holds.
# __init__ puts the study checkout on sys.path.
from scripts.wiki.frontmatter import extract_h2s, parse_frontmatter
from scripts.wiki.links import link_targets

SKIP_DIRS = {"indexes"}


@dataclass
class PageMeta:
    path: str
    folder: str
    slug: str
    title: str
    aliases: list[str]
    tags: list[str]
    created: str
    updated: str
    flashcardIds: list[str]  # noqa: N815 - the QML side reads camelCase
    isIndex: bool  # noqa: N815
    sections: list[str]
    outbound: list[str] = field(default_factory=list)
    inbound: list[str] = field(default_factory=list)


def read_page(raw: str) -> tuple[dict[str, Any], str]:
    """Frontmatter and body. A page whose YAML doesn't parse still shows, with
    no metadata: one bad page must not take the whole index down (lint names it)."""
    try:
        return parse_frontmatter(raw)
    except yaml.YAMLError:
        return {}, raw


def _as_list(value: Any) -> list[str]:
    return [str(v) for v in value] if isinstance(value, list) else []


def markdown_files(root: Path) -> list[str]:
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith(".") and d not in SKIP_DIRS)
        rel = Path(dirpath).relative_to(root)
        for name in sorted(filenames):
            if name.startswith(".") or not name.endswith(".md"):
                continue
            out.append(str(rel / name) if str(rel) != "." else name)
    return out


def load_page_meta(root: Path, file: str) -> tuple[PageMeta, list[str], str]:
    raw = (root / file).read_text(encoding="utf-8")
    data, body = read_page(raw)
    path = file[:-3]
    slug = path.split("/")[-1]
    title = data.get("title")
    meta = PageMeta(
        path=path,
        folder="/".join(path.split("/")[:-1]),
        slug=slug,
        title=title if isinstance(title, str) and title else slug,
        aliases=_as_list(data.get("aliases")),
        tags=_as_list(data.get("tags")),
        created=str(data.get("created") or ""),
        updated=str(data.get("updated") or ""),
        flashcardIds=_as_list(data.get("flashcard_ids")),
        isIndex=slug.endswith("-index"),
        sections=extract_h2s(body),
    )
    return meta, link_targets(body), body


class Resolver:
    """Resolves a wikilink target to a page path or, for a MOC, its folder ('' is the root)."""

    def __init__(self, index: dict[str, Any]):
        """From build_index's result: its `pages` and `mocs`."""
        self.by_path = {p["path"] for p in index["pages"]}
        self.by_slug: dict[str, list[str]] = {}
        for p in index["pages"]:
            self.by_slug.setdefault(p["path"].split("/")[-1], []).append(p["path"])
        self.moc_by_path = {m["path"]: m["folder"] for m in index["mocs"]}
        self.moc_by_slug: dict[str, list[str]] = {}
        for m in index["mocs"]:
            self.moc_by_slug.setdefault(m["path"].split("/")[-1], []).append(m["folder"])

    def resolve(self, target: str) -> dict[str, str] | None:
        """{"page": path} or {"folder": path}, or None when broken."""
        if target in self.by_path:
            return {"page": target}
        if target in self.moc_by_path:
            return {"folder": self.moc_by_path[target]}
        if "/" in target:
            return None
        candidates = self.by_slug.get(target, [])
        if len(candidates) == 1:
            return {"page": candidates[0]}
        if not candidates:
            folders = self.moc_by_slug.get(target, [])
            if len(folders) == 1:
                return {"folder": folders[0]}
        return None


def _resolve_raw(all_pages: list[tuple[PageMeta, list[str]]]) -> None:
    """Fill outbound/inbound over every page, MOCs included (the graph needs them)."""
    by_path = {m.path: m for m, _ in all_pages}
    by_slug: dict[str, list[str]] = {}
    for m, _ in all_pages:
        by_slug.setdefault(m.slug, []).append(m.path)
    for meta, targets in all_pages:
        resolved = set()
        for t in targets:
            hit = t if t in by_path else None
            if hit is None and "/" not in t and len(by_slug.get(t, [])) == 1:
                hit = by_slug[t][0]
            if hit and hit != meta.path:
                resolved.add(hit)
        meta.outbound = sorted(resolved)
    for meta, _ in all_pages:
        for t in meta.outbound:
            by_path[t].inbound.append(meta.path)
    for meta, _ in all_pages:
        meta.inbound.sort()


def build_tree(pages: list[PageMeta]) -> dict[str, Any]:
    # `count` is every page at or below the folder: what its rows and tiles show.
    root: dict[str, Any] = {"name": "wiki", "path": "", "folders": [], "pages": [], "count": 0}
    folders = {"": root}

    def ensure(path: str) -> dict[str, Any]:
        if path in folders:
            return folders[path]
        parent = ensure("/".join(path.split("/")[:-1]))
        node = {"name": path.split("/")[-1], "path": path, "folders": [], "pages": [], "count": 0}
        parent["folders"].append(node)
        folders[path] = node
        return node

    for p in pages:
        ensure(p.folder)["pages"].append({"path": p.path, "title": p.title})
        parts = p.folder.split("/") if p.folder else []
        for depth in range(len(parts) + 1):
            folders["/".join(parts[:depth])]["count"] += 1
    for node in folders.values():
        node["folders"].sort(key=lambda f: f["name"])
        node["pages"].sort(key=lambda p: p["title"].lower())
    return root


def build_graph(pages: list[PageMeta]) -> dict[str, Any]:
    nodes = [
        {
            "id": p.path,
            "title": p.title,
            "folder": p.folder,
            "isIndex": p.isIndex,
            "linkCount": len(p.inbound) + len(p.outbound),
        }
        for p in pages
    ]
    links, seen = [], set()
    for p in pages:
        for t in p.outbound:
            key = tuple(sorted((p.path, t)))
            if key in seen:
                continue
            seen.add(key)
            links.append({"source": p.path, "target": t})
    return {"nodes": nodes, "links": links}


def stamp(root: Path) -> str:
    """Changes whenever a page is added, removed or rewritten: the app polls this."""
    parts = []
    for file in markdown_files(root):
        try:
            st = (root / file).stat()
        except OSError:
            continue
        parts.append(f"{file}:{st.st_mtime_ns}:{st.st_size}")
    return hashlib.sha1("\n".join(parts).encode()).hexdigest()[:16]


def build_index(root: Path) -> dict[str, Any]:
    raw = [load_page_meta(root, f)[:2] for f in markdown_files(root)]
    raw.sort(key=lambda r: r[0].path)
    _resolve_raw(raw)
    everything = [m for m, _ in raw]
    graph = build_graph(everything)
    mocs = [m for m in everything if m.isIndex]
    moc_paths = {m.path for m in mocs}
    pages = [m for m in everything if not m.isIndex]
    for p in pages:
        p.outbound = [t for t in p.outbound if t not in moc_paths]
        p.inbound = [t for t in p.inbound if t not in moc_paths]
    return {
        "pages": [asdict(p) for p in pages],
        "mocs": [{"path": m.path, "folder": m.folder, "title": m.title} for m in mocs],
        "tree": build_tree(pages),
        "graph": graph,
        "stamp": stamp(root),
    }


def safe_page_file(root: Path, page_path: str) -> Path | None:
    """The page's file, or None when the path escapes the wiki root."""
    resolved_root = root.resolve()
    target = (resolved_root / f"{page_path}.md").resolve()
    if resolved_root not in target.parents:
        return None
    return target
