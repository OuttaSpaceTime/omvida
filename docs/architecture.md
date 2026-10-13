# Architecture

```
                 omvida.qml (window, navigation, shared data)
   Home · Study · Wiki · Cards · Graph · Search/Ask · Add      bar/ (omarchy-shell plugin)
          │                     │               │                      │
   JsonLineClient        JsonLineClient     claude / kitty         bin/omvida-overview
          │                     │           (Launch.js)                │
   bin/omvida-deck        bin/omvida-wiki                         master overview
          │                     │                                      │
 flashcard-mcp src/app    backend/omvida_backend                       │
   handlers · grading       wiki · render · rank                       │
   overview                 search (qmd) · logs                        │
          │                     │                                      │
   prisma/master.db       ~/Code/study/wiki, logs/  ◄──────────────────┘
```

## The parts

**QML** (repo root, one Quickshell config, as Omvision). `omvida.qml` owns navigation and the
data screens share (the wiki index, the deck overview, all cards). Screens are files of their
own. Pure logic is in `.js` modules, unit-tested without a window: `StudyKeys.js` (what a key
means), `Session.js` (a session's record), `Format.js` (wording, and card HTML as plain text),
`Cards.js` (explorer filters, the viewer's), `Graph.js` (force layout), `Launch.js`
(every argv and prompt handed to Claude), `StatusBits.js` (the status line's shared hints
and alert).

**The deck server** is flashcard-mcp's `src/app/server.ts`, started by `bin/omvida-deck`.
It runs for the app's whole life rather than per call: a tsx start costs about a second, and
the session cache lives in it (queues are also saved in the deck, so a restart resumes them). It derives `maxNewCards` from the pressure verdict and returns a leech block as
data; flashcard-mcp's CLAUDE.md has the method table and the why. `grade` runs `claude -p`
(Sonnet, structured output, no tools, no MCP, no settings) with /study's fixed rubric, in about
three seconds, and only suggests: `review` writes whatever rating the developer chose.

**The wiki service** is `backend/omvida_backend` (Python, uv venv in this repo), started by
`bin/omvida-wiki`. It ports the Next.js viewer's `lib/wiki.ts` (links both ways, the tree, the
graph, its nodes carrying their tags) and renders a page as **blocks** for Qt: QML's rich text cannot scroll to
an anchor, so a page is a column of items, and a heading link scrolls to one. Syntax
highlighting is Pygments, collapsed to a dozen class names that `Theme.richTextStyle` colours,
so a theme switch recolours without re-rendering. It also ranks pages (after a session, and
for Home), runs qmd, and appends the session log entry.

**Both speak JSON lines** over stdio (`JsonLineClient.qml`): `{id, method, params}` in,
`{id, result | error}` out, `{"ready": true}` at start. MCP was the alternative for the deck,
and was rejected: a QML MCP client means the initialize handshake and tool-result envelopes by
hand, for nothing the app needs. The CLI per call was rejected for its second-long start.

**Claude Code** does everything that writes cards or pages, in kitty, in the study repo where
the skills and AGENTS.md live: Discuss (Socratic mode on one card), Add → Flashcards
(`/study-flashcard`), Add → Wiki entry (`/study-walkthrough --write`), a leech rewrite or split,
fixing a flagged card, "Continue in Claude" after an Ask. Their results show up on their own.
The wiki: the app polls the wiki service's stamp. The deck: the study repo's PostToolUse hook
runs `bin/omvida-deck-changed` after every flashcard-mcp tool that writes a card, which calls
the app's `deckChanged` IPC, so the card shows the moment it is saved, even with the window in
the background (one reload per batch: the IPC is debounced). Behind that, the app polls the deck
server's `stamp` while the window is in front and on coming back to it, for writes the hook does
not see: the CLI, a tool the hook does not name, a Claude session outside the study repo. The
hook alone would tie the app to tool names and hook config; the poll alone lags and stops in
the background. The app's own writes take the new stamp as they reload, so the poll does not
reload them twice. The stamp has three parts: the cards' content (a review keeps a card's
`updatedAt`, so it does not move this one), the reviews, and the notes. Reviews reload the deck,
except during a study session, when each rating reloads only the overview (the due count, the
bar) and the cards' scheduling waits for the session's end: it was a whole-deck read per rating
for nothing on screen. A study session catches up with the card on screen (`StudySession.catchUp`): a rewritten card replaces the shown one
and drops the stale suggestion, a deleted one moves the session on, and a fixed leech lifts
the block. The only headless run with tools is Ask: `claude -p` under the Query Protocol, with only
read-only lookups and `Edit/Write(logs/**)` pre-allowed.

**Card notes** are the one thing the app writes about a card without changing it. Ctrl+N in
Study (N on the Cards stage) notes what should change about a card, or what to understand
better, in markdown (`NoteDialog.qml`, `NoteEdit.js`), so the session goes on instead of
breaking off into Claude Code per card. They live in the deck (flashcard-mcp's `CardNote`, one
per card, deleted with it; `notes` and `setNote`), so they outlast the app and a fix session can
read them too. "Fix all" (Home's past sessions, the summary, "fix it" on Cards with the noted
filter) hands them to one Claude Code session, the study repo's `/study-fix-notes` with the
cards' ids: the skill owns how a note is handled, reads the notes itself (`list_card_notes`), and
resolves each with `resolve_card_note` once it is dealt with; that tool is in the study repo's hook, and the deck
`stamp` counts notes, so a resolved note leaves the app's lists as a fixed card does. Home's past
sessions come from the deck server's `sessions` (each recent session with the cards it lapsed and
noted), so a /study chat session shows there too; the summary's count of the cards noted in its
session is the same list's. A file of notes in the study repo was the
alternative, and rejected: nothing would remove a deleted card's note, and Claude would edit it by
hand.

**The bar plugin** (`bar/`) runs inside omarchy-shell, so it uses the shell's `qs.Commons`
and `qs.Ui` (Panel, KeyboardPanel, PanelKeyCatcher) and none of this repo's QML. Its numbers
come from `bin/omvida-overview`, which prints flashcard-mcp's overview, the same object the app
shows. It runs that every ten minutes and when the panel opens; while the app is open, the app
also hands the bar each new overview it loads (`omarchy-shell -q omvida.bar setOverview`), so
the count follows a session rating by rating.

## What was copied, and from where

The research for this app (2026-10-06) looked at Omvision, omarchy-shell's first-party
plugins (`/usr/share/omarchy/shell/plugins`: clock, weather, agents, disk-speedtest), the
omarchy plugin guide (plugins.omarchy.org/develop), and community plugins (dance.todo's
markdown todo, Okomart's storefront). What was taken:

- **From Omvision**: the whole verification setup (`bin/check` with a lint baseline and the
  pixel rule, `bin/test` with an in-app TestCase harness and its `qtest_results` workaround,
  `bin/shot` offscreen screenshots), `Theme.qml`'s contrast-solved text colours and spacing
  scale, the theme-set hook, the icon rail, single-instance launch, "closing the window ends
  the app", and the rule that hiding a screen hands the keyboard back.
- **From omarchy-shell's plugins**: a bar widget that loads its `Panel.qml` and stands in for
  it as the popout identity (`open`/`close`/`opened`/`closeForPopoutSwitch`), `KeyboardPanel`
  with `PanelKeyCatcher` for Esc and Tab, launches as an argv (`Quickshell.execDetached`,
  never a shell string), and `omarchy plugin validate` as the plugin's check.
- **From dance.todo and the plugin guide**: pure logic in a `Model.js` the shell doesn't need
  to test (here, `bar/Model.js` under qmltestrunner), and a plugin that never starts a second
  Quickshell process.
- **From the Next.js viewer**: every feature (tree, context panel, connections, local and
  full graph, per-page cards with flip-through, the deck explorer with retention, the
  dashboard), its link rules and ranking functions, ported rather than reinvented.

## Data and safety

- The real deck is written only through flashcard-mcp's own code (reviews, leech keep, card
  delete on a confirmed leech drop, card notes). Everything else that changes a card is a skill.
- The wiki is never written by the app. The study log is appended (never rewritten), with the
  session number read just before.
- Tests and screenshots run in `bin/sandbox`, which refuses a target outside the temp dir.
