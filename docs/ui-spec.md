# UI spec

Tokens are `Theme.qml`'s, which are Omvision's (the contrast-solved `secondaryInk`/`dim`/`faint`,
the 4px spacing scale, square 1px controls) plus the theme's named hues for syntax, topics,
card states, ratings and verdicts. Body 15px; the card front 20px, the largest text in the app.

## Window

A 64px icon rail (Home, Study, Wiki, Cards, Graph; Study carries the due badge), a 56px top bar
(back, the search box that opens the palette, a status note for backend failures, Add), the
screen, and a 36px status line along the bottom, right of the rail. Content sits in a reading
column of 82 body characters, centred.

Keys everywhere: Ctrl+1–5 screens, Ctrl+K or `/` search (not on Study, where `/` is typed),
Ctrl+N Add, Alt+←/→ history. Esc closes an overlay.

### The status line

An editor's status line (`StatusLine.qml`), hairline on top: a mode block on the left (filled,
paper text, bold, letter-spaced capitals), then segments saying where you are, a gap, the keys
that work now as clickable hints (`**keys** label`), and alerts at the right edge, each behind a
hairline. It draws whatever the screen on show declares; every property is optional:

```qml
readonly property string statusMode      // e.g. "STUDY"; "" = the screen's name uppercased
readonly property color statusModeColor  // optional; default Theme.accentColor
readonly property var statusSegments     // [{ text, color? }] left, after the mode
readonly property var statusHints        // [{ keys, label, run: function() {} }] clickable
readonly property var statusAlerts       // [{ text, color?, tip?, run? }] right edge
```

A screen that declares none gets its name only (HOME, WIKI, CARDS, GRAPH). Segments default
to `Theme.dim`; a hint without `run` is a legend, not a button; an alert shows `tip` on hover
and runs `run` on click. On a narrow window the mode and the alerts stay, the segments clip and
the hints drop whole from the end, so list them most important first.

## Home

The study panel (pressure verdict in its colour, the reviews due, clearance, calibration, the
week as bars with Again in red, maturity as one stacked bar, Study now), pending reviews, last
studied pages (latest review first, then coverage), recently updated, topic tiles.

## Study

Drawn for the keyboard: no button rows, no session line, no hint footer; the status line has
the mode, the place and the keys. The card sits in the reading column, centred vertically
while it fits.

- Answering: the previous card's result as one faint line, the front large (20px), its tags
  faint, then a borderless prompt: an accent `›` and the answer box ("answer, or leave
  empty").
- Revealed: the front cut to a dim three-line recap; a box split by a hairline, "› you" with
  the typed answer (or "(nothing typed)") beside "back" on a faint fill; Claude's verdict as
  one line ("claude: good — reason", the verdict in its rating's colour; "claude: grading…"
  while it runs; the grader's error if it failed); a card issue as a quiet orange line with
  "fix in claude"; then four keycaps, `1 again` `2 hard` `3 good ◂` `4 easy`, the suggested
  one outlined at 2px in its colour.
- Status line: STUDY (accent) while answering, RATE after the reveal in the suggested rating's
  colour, SYNC, LEECH (orange), DONE, ERROR (red). Segments: the position from the server
  (`3/12`), the deck, `repeat`. Hints: answering `⇧↵ reveal`, `⌥↵ reveal+accept`, `⇧1-4 rate`,
  `⌃D discuss`, `⌃S skip`, `esc end`; revealed `⌥↵ take <rating>` (or `⇧↵ good` with no
  suggestion), `⇧1-4 rate` as a legend, discuss, skip, end. Alerts: the pressure verdict when
  not ok (`● warn` in its colour), new cards held back, and the Anki sync (`sync ✕` in red on
  failure, `synced` otherwise; the message on hover and as a toast on click).

States: syncing (skip the sync), starting, answering, grading, revealed, submitting, blocked
(a leech: why, its card between hairlines, rewrite/split in claude, keep as is, delete with a
confirm, `↵ continue`), done (the summary with an honest duration, accuracy, lapses, leeches;
related pages; a walkthrough offer per lapse; `↵ start another session`, browse the wiki,
home), error (`↵ try again`). The leech and the summary set their actions as plain words
(`PlainButton.qml`), never a row of boxes. Keys: README's table; Enter and Esc also work on a
leech, Enter on the summary.

## Wiki

Left (280px): Context (You are here, the folder's pages with the open page's sections under
it, subfolders, Outgoing, Linked from) or Tree. Centre: breadcrumb, title, tags, updated and
aliases, the cards button and Claude actions, the page's blocks, then Linked from / Links to.
Right (280px, wide windows only): the page's neighbourhood graph. The side panels drop out
before the reading column narrows below ~60% of its measure.

## Cards

Retention (true retention, verdict, reasons, rating mix), the state bar and chips, text, deck
and tag filters, a count, List (60 at a time) or Flip through.

## Graph

All pages or two hops around the open page; topic legend; hubs and the hovered node's
neighbours labelled; click opens, drag pins, wheel zooms.

## Overlays

Search palette (as tall as its results; Keyword or Deep; Ask streams, then renders like a page),
Add menu, the topic dialog, a page's cards (overview grid or flip-through), toasts.
