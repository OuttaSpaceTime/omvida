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
means), `Session.js` (a session's record), `Format.js`, `Cards.js` (explorer filters, the
viewer's), `Graph.js` (force layout), `Launch.js` (every argv and prompt handed to Claude).

**The deck server** is flashcard-mcp's `src/app/server.ts`, started by `bin/omvida-deck`.
It runs for the app's whole life rather than per call: a tsx start costs about a second, and
the session cache lives in it (queues are also saved in the deck, so a restart resumes them). It derives `maxNewCards` from the pressure verdict and returns a leech block as
data; flashcard-mcp's CLAUDE.md has the method table and the why. `grade` runs `claude -p`
(Sonnet, structured output, no tools, no MCP, no settings) with /study's fixed rubric, in about
three seconds, and only suggests: `review` writes whatever rating the developer chose.

**The wiki service** is `backend/omvida_backend` (Python, uv venv in this repo), started by
`bin/omvida-wiki`. It ports the Next.js viewer's `lib/wiki.ts` (links both ways, the tree, the
graph, MOCs as hubs) and renders a page as **blocks** for Qt: QML's rich text cannot scroll to
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
fixing a flagged card, "Continue in Claude" after an Ask. The app re-reads the deck when its
window comes back to the front and polls the wiki's stamp, so their results show up on their
own. The only headless run with tools is Ask: `claude -p` under the Query Protocol, with only
read-only lookups and `Edit/Write(logs/**)` pre-allowed.

**The bar plugin** (`bar/`) runs inside omarchy-shell, so it uses the shell's `qs.Commons`
and `qs.Ui` (Panel, KeyboardPanel, PanelKeyCatcher) and none of this repo's QML. Its numbers
come from `bin/omvida-overview`, which prints flashcard-mcp's overview, the same object the app
shows.

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
  delete on a confirmed leech drop). Everything else that changes a card is a skill.
- The wiki is never written by the app. The study log is appended (never rewritten), with the
  session number read just before.
- Tests and screenshots run in `bin/sandbox`, which refuses a target outside the temp dir.
