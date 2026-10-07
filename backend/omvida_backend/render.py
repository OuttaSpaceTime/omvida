"""A wiki page's markdown, turned into blocks a QML page can lay out one by one.

Why blocks and not one HTML document: QML's Text can show Qt rich text, but it
cannot scroll to an anchor, so the sidebar's section links and `[[page#Heading]]`
links would have nowhere to go. A page that is a list of blocks (a heading, a
paragraph, a code block, a callout, a table) scrolls to a heading by scrolling
to its item, and lets code blocks and callouts be drawn as real items with their
own background and copy button instead of whatever Qt's HTML subset allows.

Each block's `html` uses only what Qt's rich text supports (`p`, `b`, `i`,
`code`, `a`, `ul`/`ol`/`li`, `table`, `pre`, `span class`). There is no colour
in it: syntax tokens and broken links carry short class names, and the app
prepends a `<style>` built from the live theme. A theme switch then recolours a
page without asking for it again.

Same rules as the Next.js viewer (lib/markdown.ts):
- the page's own leading `# Title` is dropped, since the header shows the title;
- `> [Label] text` is a callout titled Label;
- `[[path]]`, `[[path|text]]`, `[[path#Heading]]` and `[[#Heading]]` become
  links (`wiki:path#anchor`, `folder:path` for a MOC), and an unresolved target
  becomes `<span class="broken">`; `![[embeds]]` stay literal text, and nothing
  inside code is touched;
- heading anchors use slugify_heading on both sides, so links and headings agree.
"""

from __future__ import annotations

import html as htmlmod
import re
from typing import Any

from markdown_it import MarkdownIt
from markdown_it.rules_inline import StateInline
from markdown_it.token import Token
from mdit_py_plugins.tasklists import tasklists_plugin
from pygments import lex
from pygments.lexers import get_lexer_by_name
from pygments.token import Token as T
from pygments.util import ClassNotFound

from .wiki import Resolver

CALLOUT = re.compile(r"^\[([A-Za-z][\w-]*)\]\s*")
LEADING_H1 = re.compile(r"^\s*#[ \t][^\n]*\n?")


def slugify_heading(text: str) -> str:
    s = re.sub(r"[^a-z0-9\s-]", "", text.lower()).strip()
    return re.sub(r"[\s-]+", "-", s)


def strip_leading_h1(markdown: str) -> str:
    return LEADING_H1.sub("", markdown, count=1).lstrip("\n")


# ---- syntax highlighting --------------------------------------------------------
# Pygments' token tree collapsed to a dozen classes the theme colours. Most
# specific first: Name.Function must win over Name.
TOKEN_CLASSES = [
    (T.Comment, "cm"),
    (T.Keyword.Type, "ty"),
    (T.Keyword, "kw"),
    (T.Name.Builtin, "bi"),
    (T.Name.Function, "fn"),
    (T.Name.Class, "ty"),
    (T.Name.Decorator, "fn"),
    (T.Name.Tag, "tag"),
    (T.Name.Attribute, "at"),
    (T.Name.Variable, "var"),
    (T.Name.Constant, "num"),
    (T.Literal.String, "str"),
    (T.Literal.Number, "num"),
    (T.Literal, "num"),
    (T.Operator, "op"),
    (T.Generic.Deleted, "del"),
    (T.Generic.Inserted, "ins"),
    (T.Generic.Heading, "hd"),
    (T.Generic.Subheading, "hd"),
]



def token_class(ttype: Any) -> str:
    for parent, cls in TOKEN_CLASSES:
        if ttype in parent:
            return cls
    return ""


def highlight(code: str, lang: str) -> str:
    """Code as escaped text with `<span class=..>` per token, newlines kept."""
    try:
        lexer = get_lexer_by_name(lang.lower()) if lang else None
    except ClassNotFound:
        lexer = None
    if lexer is None:
        return htmlmod.escape(code)
    out = []
    for ttype, value in lex(code, lexer):
        text = htmlmod.escape(value)
        cls = token_class(ttype)
        out.append(f'<span class="{cls}">{text}</span>' if cls and text.strip() else text)
    return "".join(out)


# ---- wikilinks ---------------------------------------------------------------------
def wikilink_rule(resolver: Resolver):
    def rule(state: StateInline, silent: bool) -> bool:
        src, pos = state.src, state.pos
        if not src.startswith("[[", pos):
            return False
        if pos > 0 and src[pos - 1] == "!":
            return False  # an embed: left as literal text
        end = src.find("]]", pos + 2)
        if end == -1:
            return False
        inner = src[pos + 2 : end]
        if not inner or "[" in inner or "]" in inner:
            return False
        if not silent:
            target_part, _, display = inner.partition("|")
            path_part, _, heading = target_part.partition("#")
            target, heading, display = path_part.strip(), heading.strip(), display.strip()
            label = display or (f"{target}#{heading}" if heading else target) or inner
            href = None
            if not target and heading:
                href = f"anchor:{slugify_heading(heading)}"
            elif target:
                hit = resolver.resolve(target)
                if hit and "page" in hit:
                    href = f"wiki:{hit['page']}" + (f"#{slugify_heading(heading)}" if heading else "")
                elif hit and "folder" in hit:
                    href = f"folder:{hit['folder']}"
            tok = state.push("html_inline", "", 0)
            if href is None:
                tok.content = f'<span class="broken">{htmlmod.escape(label)}</span>'
            else:
                tok.content = f'<a href="{htmlmod.escape(href, quote=True)}">{htmlmod.escape(label)}</a>'
        state.pos = end + 2
        return True

    return rule


def make_md(resolver: Resolver) -> MarkdownIt:
    # html: False, so raw HTML in a page is shown as text: the wiki is markdown,
    # and Qt's rich text would otherwise try to honour whatever a page contains.
    md = MarkdownIt("commonmark", {"html": False}).enable(["table", "strikethrough"])
    md.use(tasklists_plugin)
    md.inline.ruler.before("link", "wikilink", wikilink_rule(resolver))
    return md


def _render(md: MarkdownIt, tokens: list[Token], env: dict) -> str:
    out = md.renderer.render(tokens, md.options, env).strip()
    # Qt draws a table without borders unless asked; the theme styles the rest.
    out = out.replace("<table>", '<table border="1" cellspacing="0" cellpadding="6" width="100%">')
    # The tasklists plugin emits <input> checkboxes Qt can't draw.
    out = re.sub(r'<input class="task-list-item-checkbox"[^>]*checked="checked"[^>]*>\s*', "☑ ", out)
    out = re.sub(r'<input class="task-list-item-checkbox"[^>]*>\s*', "☐ ", out)
    return out


def _plain(tokens: list[Token]) -> str:
    parts = []
    for t in tokens:
        for c in t.children or []:
            if c.type in ("text", "code_inline"):
                parts.append(c.content)
            elif c.type == "html_inline":
                parts.append(re.sub(r"<[^>]+>", "", htmlmod.unescape(c.content)))
    return "".join(parts)


def _groups(tokens: list[Token]) -> list[list[Token]]:
    """Top-level blocks: each open token with everything up to its close."""
    groups, i = [], 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.nesting == 1 and tok.level == 0:
            depth, j = 0, i
            while j < len(tokens):
                depth += tokens[j].nesting
                if depth == 0:
                    break
                j += 1
            groups.append(tokens[i : j + 1])
            i = j + 1
        else:
            groups.append([tok])
            i += 1
    return groups


def render_blocks(markdown: str, resolver: Resolver) -> list[dict[str, Any]]:
    md = make_md(resolver)
    env: dict = {}
    tokens = md.parse(strip_leading_h1(markdown), env)
    blocks: list[dict[str, Any]] = []
    for group in _groups(tokens):
        head = group[0]
        if head.type == "heading_open":
            level = int(head.tag[1])
            inline = group[1:-1]
            text = _plain(inline)
            blocks.append({
                "kind": "heading",
                "level": level,
                "text": text,
                "anchor": slugify_heading(text),
                "html": md.renderer.render(inline, md.options, env).strip(),
            })
        elif head.type in ("fence", "code_block"):
            lang = (head.info or "").strip().split(" ")[0] if head.type == "fence" else ""
            code = head.content.rstrip("\n")
            blocks.append({"kind": "code", "lang": lang, "text": code, "html": highlight(code, lang)})
        elif head.type == "hr":
            blocks.append({"kind": "hr"})
        elif head.type == "blockquote_open":
            inner = group[1:-1]
            label = None
            first_inline = next((t for t in inner if t.type == "inline"), None)
            if first_inline is not None and first_inline.children:
                first = first_inline.children[0]
                m = CALLOUT.match(first.content) if first.type == "text" else None
                if m:
                    label = m.group(1)
                    first.content = first.content[m.end():]
            html = _render(md, inner, env)
            if label:
                blocks.append({"kind": "callout", "label": label, "html": html})
            else:
                blocks.append({"kind": "quote", "html": html})
        else:  # paragraphs, lists and tables: rich text the page draws alike
            html = _render(md, group, env)
            if html:
                blocks.append({"kind": "rich", "html": html})
    return blocks
