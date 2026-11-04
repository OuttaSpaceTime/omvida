# Omvida

The study wiki and its flashcards as a desktop app: a [Quickshell](https://quickshell.org/)
(QML) app beside [Omvision](../omvision), for Omarchy. It reads the wiki in
`~/Code/study/wiki` and the deck in [flashcard-mcp](../flashcard-mcp), and adds what a browser
viewer could not: a study loop you answer in, graded by Claude.

```
~/Code/omvida/bin/omvida              open it (or focus the running one)
~/Code/omvida/bin/omvida study        straight into a session
~/Code/omvida/bin/omvida open security/csrf
```

## Study

A card's front, and the answer box already focused. Type an answer, or don't.

| Key | Does |
|---|---|
| **Shift+Enter** | reveal the back; a typed answer goes to the Claude API (Haiku), which suggests a rating with a one-sentence reason (once per card, on the reveal, since each grade bills the API) |
| **Shift+Enter** again | submit the rating Shift+1–4 picked, else **Good** |
| **Alt+Enter** | accept the suggestion. Before the reveal: reveal, and accept it the moment it arrives |
| **Shift+1–4** | pick Again / Hard / Good / Easy, overriding the suggestion; before the reveal it reveals too. The same digit again (or Shift+Enter) submits the pick, another digit changes it |
| **Ctrl+D** | discuss the card in Claude Code (kitty), Socratic mode, with your answer and the suggestion |
| **Ctrl+Q** | check the card's quality in the background: Claude Code (`/study-card-check`, headless) fixes it if it is flawed, and a slot above the status line says what it did until dismissed (**Ctrl+Shift+Q**; **Ctrl+Shift+D** discusses it) |
| **Ctrl+S** | skip; the card stays due |
| **Ctrl+Z** | undo the last rating, and again for the one before: the card comes back revealed, with your answer and Claude's verdict, and no new grade. It also works on a leech and on the summary, which it reopens, until the session's log entry is written. With an answer typed, Ctrl+Z edits it |
| **Ctrl+Shift+Z** | redo a rating undone, one at a time. Rating the card differently starts over: the redos are gone |
| **Esc** | end the session; what was rated counts, and the summary follows |
| **Del** | delete the card, after a confirm dialog; the session goes on. With an answer typed, Del edits it. Also on Cards, for the card on the stage |
| Enter | a newline: answers are often code |

Shift+digit is matched on the physical key, so it works on US and German layouts alike
(`StudyKeys.js` explains why). The grader's rubric is `/study`'s, fixed, and it only rates.
**Ctrl+Q** checks the card's own quality instead: the study repo's `/study-card-check` runs
headless, fixes a flawed card (corrects, rewrites, or splits it, keeping its schedule) and says
what it did above the status line, while you study on. The keys that work
at each moment are on the status line at the bottom of the window, and each is also a button
there; after the reveal the four ratings are keycaps under the card.

Around the loop it keeps what `/study` does: Anki sync before (phone reviews first) and after,
the pressure and calibration verdicts, new cards held back under pressure, the leech block
(rewrite or split in Claude, delete, or keep as is), and at the end the summary, the wiki pages
related to what you studied, and a `## Session N — Study` entry in the study repo's log.

## The rest

- **Home**: what is due and why (pressure, clearance, calibration, the week, maturity), last
  studied pages, recently updated pages, topics.
- **Wiki**: the page in a reading column, syntax-highlighted code, callouts, tables,
  `[[wikilinks]]` (broken ones in red); a context panel (where am I, siblings, the page's
  sections, outgoing and linked-from) or the whole tree; the page's local graph; its flashcards
  as an overview or flip-through.
- **Cards**: the whole deck with true retention and the calibration verdict, a state bar that
  filters, deck, tag and text filters. One card on a stage at the top (Space or Enter flips,
  ←/→ or h/l page), the cards after it in a grid below: paging forward takes cards off the
  grid, paging back puts them back, and clicking a tile jumps there.
- **Graph**: every page and link, or two hops around the open page.
- **Search** (Ctrl+K or `/`): titles as you type, the wiki's text through qmd, the cards, and
  **Ask Claude** (Ctrl+Enter), which answers under the study repo's Query Protocol (memory
  first, then the wiki, the cards and a web check, logged) and streams into the app.
  "Continue in Claude" resumes the same session in kitty.
- **Add** (Ctrl+N): Flashcards (`/study-flashcard`) or Wiki entry (`/study-walkthrough --write`),
  opened in Claude Code in kitty with the topic and where you were.

Ctrl+1–5 switch screens, Alt+←/→ go back and forward.

## The bar

`bar/` is an omarchy-shell plugin, `omvida.bar`: the Omvida mark with the number of reviews
due. Click for a panel with your progress (pressure, calibration, maturity) and Study
now; right-click starts a session; middle-click refreshes. It reads `bin/omvida-overview`
(flashcard-mcp's `master overview`), so it needs neither the app nor its own copy of any rule.

## How it fits together

See [`docs/architecture.md`](docs/architecture.md). In short: QML for the app, two long-lived
backends speaking JSON lines (the deck through flashcard-mcp's app server, the wiki through a
small Python service here), and Claude Code for everything that writes cards or pages.

## Requirements

Quickshell, Qt 6, a Nerd Font monospace (JetBrainsMono on Omarchy), `uv` (the wiki service's
venv builds itself on first launch), node via mise (flashcard-mcp), `claude`, `kitty`, `qmd`.
Tests need `qmltestrunner`/`qmllint` from `qt6-declarative`; `bin/check` also needs a checkout of
[qs-kit](../qs-kit) beside this repo (or `QS_KIT` pointing at one).

## Docs

- [`docs/architecture.md`](docs/architecture.md): the parts, the protocols, and why
- [`docs/testing.md`](docs/testing.md): `bin/test`, `bin/check`, `bin/shot`, fixtures
- [`docs/ui-spec.md`](docs/ui-spec.md): screens, keys, tokens
- [`docs/layout-rules.md`](docs/layout-rules.md): QML layout rules, from Omvision
