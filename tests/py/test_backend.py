"""The wiki service against tests/fixtures/study: index, links, rendering, ranking, logs."""

import json
from datetime import datetime
from pathlib import Path

import pytest
from omvida_backend import logs, rank, render, search, wiki
from omvida_backend.server import Service, respond

FIXTURE = Path(__file__).resolve().parents[1] / "fixtures" / "study"


@pytest.fixture
def svc():
    return Service(FIXTURE)


@pytest.fixture
def idx(svc):
    return svc.index({})


def page(idx, path):
    return next(p for p in idx["pages"] if p["path"] == path)


# ---- index ------------------------------------------------------------------------
def test_mocs_are_hubs_not_pages(idx):
    assert [p["path"] for p in idx["pages"]] == ["security/csrf", "security/same-origin-policy", "web/http-caching"]
    assert idx["mocs"] == [{"path": "web/web-index", "folder": "web", "title": "Web Index"}]
    assert "web/web-index" in {n["id"] for n in idx["graph"]["nodes"]}


def test_links_resolve_both_ways_without_code_or_embeds(idx):
    caching = page(idx, "web/http-caching")
    # [[missing/page]] is broken, [[not-a-link]] sits in inline code, the MOC link is dropped.
    assert caching["outbound"] == ["security/csrf"]
    csrf = page(idx, "security/csrf")
    # [[csrf]] from same-origin-policy resolves by unique slug.
    assert csrf["inbound"] == ["security/same-origin-policy", "web/http-caching"]


def test_sections_skip_fenced_code(idx):
    assert page(idx, "web/http-caching")["sections"] == ["Freshness", "Validation"]


def test_page_meta_reads_frontmatter(idx):
    p = page(idx, "web/http-caching")
    assert p["title"] == "HTTP Caching"
    assert p["flashcardIds"] == ["fixturecard0001", "fixturecard0002"]
    assert p["created"] == "2026-05-02"
    assert p["aliases"] == ["cache-control"]


def test_tree_puts_folders_and_pages_in_order(idx):
    tree = idx["tree"]
    assert [f["name"] for f in tree["folders"]] == ["security", "web"]
    assert [p["title"] for p in tree["folders"][0]["pages"]] == ["CSRF", "Same-Origin Policy"]
    assert (tree["count"], tree["folders"][0]["count"], tree["folders"][1]["count"]) == (3, 2, 1)


def test_stamp_changes_when_a_page_changes(tmp_path):
    (tmp_path / "a.md").write_text("---\ntitle: A\n---\nhi\n")
    before = wiki.stamp(tmp_path)
    (tmp_path / "a.md").write_text("---\ntitle: A\n---\nhello\n")
    assert wiki.stamp(tmp_path) != before


def test_page_path_cannot_escape_the_wiki(svc):
    assert svc.page({"path": "../AGENTS"}) is None
    assert wiki.safe_page_file(FIXTURE / "wiki", "../../etc/passwd") is None


# ---- rendering ------------------------------------------------------------------
def blocks(svc, path):
    return svc.page({"path": path})["blocks"]


def test_leading_h1_is_dropped_and_headings_get_anchors(svc):
    b = blocks(svc, "web/http-caching")
    assert b[0]["kind"] == "rich"
    heads = [x for x in b if x["kind"] == "heading"]
    assert [(h["text"], h["anchor"], h["level"]) for h in heads] == [
        ("Freshness", "freshness", 2),
        ("Validation", "validation", 2),
    ]


def test_wikilinks_render_as_links_broken_spans_and_literal_embeds(svc):
    first = blocks(svc, "web/http-caching")[0]["html"]
    assert '<a href="wiki:security/csrf">CSRF</a>' in first
    assert '<span class="broken">missing/page</span>' in first
    assert "<code>[[not-a-link]]</code>" in first
    last = blocks(svc, "web/http-caching")[-1]["html"]
    assert '<a href="anchor:freshness">#Freshness</a>' in last
    assert '<a href="folder:web">web-index</a>' in last
    assert "![[diagram.png]]" in last


def test_link_with_heading_carries_the_anchor(svc):
    first = blocks(svc, "security/csrf")[0]["html"]
    assert '<a href="wiki:web/http-caching#freshness">web/http-caching#Freshness</a>' in first


def test_code_blocks_are_highlighted_with_theme_classes(svc):
    code = next(b for b in blocks(svc, "security/csrf") if b["kind"] == "code")
    assert code["lang"] == "python"
    assert code["text"].startswith("def check(token, session):")
    assert '<span class="kw">def</span>' in code["html"]
    assert '<span class="fn">check</span>' in code["html"]


def test_unknown_language_is_escaped_plain_text():
    assert render.highlight("a < b", "nosuchlang") == "a &lt; b"


def test_callouts_tables_and_task_lists(svc):
    b = blocks(svc, "web/http-caching")
    callout = next(x for x in b if x["kind"] == "callout")
    assert callout["label"] == "Heuristic"
    assert callout["html"].startswith("<p>Validate with ETag")
    table = next(x for x in b if x["html"].startswith("<table"))
    assert table["html"].startswith('<table border="1"')
    tasks = next(x for x in b if "task-list" in x["html"])
    assert "☑ read RFC 9111" in tasks["html"] and "☐ write a card" in tasks["html"]


def test_slugify_matches_the_viewer():
    assert render.slugify_heading("Why SameSite=Lax Doesn't Work") == "why-samesitelax-doesnt-work"


# ---- ranking --------------------------------------------------------------------
def test_related_prefers_lapsed_cards_then_coverage(idx):
    studied = [
        {"id": "fixturecard0001", "tags": ["http"], "lapsed": False},
        {"id": "fixturecard0002", "tags": ["http"], "lapsed": False},
        {"id": "fixturecard0003", "tags": ["security"], "lapsed": True},
    ]
    out = rank.related_pages(idx["pages"], studied)
    assert [(r["path"], r["cards"], r["lapsed"]) for r in out] == [
        ("security/csrf", 1, 1),
        ("web/http-caching", 2, 0),
    ]


def test_related_falls_back_to_tags_only_when_no_card_matches(idx):
    out = rank.related_pages(idx["pages"], [{"id": "other", "tags": ["Security"], "lapsed": False}])
    assert {r["path"] for r in out} == {"security/csrf", "security/same-origin-policy"}
    assert all(r["via"] == "tags" for r in out)


def test_recent_ranks_by_last_review_then_coverage(idx):
    studied = [
        {"id": "fixturecard0001", "at": "2026-10-01"},
        {"id": "fixturecard0002", "at": "2026-10-01"},
        {"id": "fixturecard0003", "at": "2026-10-02"},
    ]
    out = rank.recently_studied_pages(idx["pages"], studied)
    assert [(r["path"], r["cards"]) for r in out] == [("security/csrf", 1), ("web/http-caching", 2)]


# ---- search ---------------------------------------------------------------------
def test_parse_qmd_skips_progress_lines_and_maps_paths():
    out = 'Expanding query...\n[{"file": "qmd://wiki/security/csrf.md", "title": "CSRF", "score": 0.9, "line": 4, "snippet": "@@ -3,4 @@ (2 before)\\n\\nThe naive   version"}]'
    assert search.parse_qmd(out) == [
        {"path": "security/csrf", "title": "CSRF", "score": 0.9, "line": 4, "snippet": "The naive version"}
    ]
    assert search.parse_qmd("no results") == []


def test_search_modes_pick_the_qmd_command():
    assert search.qmd_argv("x", "fast", 5)[:2] == ["qmd", "search"]
    deep = search.qmd_argv("x", "deep", 5)
    assert deep[:3] == ["qmd", "query", "--no-rerank"]


# ---- logs -----------------------------------------------------------------------
def test_session_log_starts_a_day_and_numbers_after_other_sessions(tmp_path):
    now = datetime(2026, 10, 6, 21, 5)
    first = logs.append_session(tmp_path, {"cardsReviewed": 3, "accuracy": 2 / 3, "lapses": ["csrf"]}, now)
    path = tmp_path / "logs" / "10" / "2026-10-06.md"
    assert first == {"path": str(path), "session": 1}
    with path.open("a") as fh:
        fh.write("\n## Session 2 — Walkthrough (21:30)\n- stuff\n")
    second = logs.append_session(tmp_path, {"cardsReviewed": 12, "repeats": 2, "duration": "11 min"}, now)
    assert second["session"] == 3
    text = path.read_text()
    assert text.startswith("# 2026-10-06\n\n## Session 1 — Study (21:05)\n- **Cards reviewed:** 3\n- **Accuracy:** 67%\n- **Lapses:** csrf\n")
    assert "## Session 3 — Study (21:05)\n- **Cards reviewed:** 12 (+2 intra-day repeats)" in text
    assert "- **Duration:** 11 min" in text
    assert "\n\n## Session 3" in text


# ---- protocol -------------------------------------------------------------------
def test_respond_returns_results_and_errors_with_the_id(svc):
    h = svc.handlers()
    assert json.loads(respond(h, {"id": 3, "method": "stamp"}))["id"] == 3
    assert "unknown method" in json.loads(respond(h, {"id": 4, "method": "nope"}))["error"]["message"]
    assert "unknown method" in json.loads(respond(h, ["not", "a", "request"]))["error"]["message"]


def test_markdown_renders_an_answer_with_resolved_wikilinks(svc):
    out = svc.markdown({"text": "# Answer\n\nOrigins: see [[csrf]] and [[nope]]."})
    assert out["blocks"][0]["kind"] == "rich"  # a leading H1 is dropped, as on pages
    assert '<a href="wiki:security/csrf">csrf</a>' in out["blocks"][0]["html"]
    assert '<span class="broken">nope</span>' in out["blocks"][0]["html"]
