# UI spec

Tokens are `Theme.qml`'s, which are Omvision's (the contrast-solved `secondaryInk`/`dim`/`faint`,
the 4px spacing scale, square 1px controls) plus the theme's named hues for syntax, topics,
card states, ratings and verdicts. Body 15px; the card front 20px, the largest text in the app.

## Style

The user chose two looks from a set of mockups, and the app follows them everywhere:

- **Glance** (the bar overlay): one big figure with its word ("37 due", `heroSize`), a small
  verdict chip outlined in its colour, one dim sentence, a thin segmented bar with 2px gaps and
  a legend whose numbers are set in their colours, then sections parted by a hairline and a
  small letter-spaced caption (`SectionLabel { divided: true }`), plain rows, and a footer of
  one filled action beside square icon buttons (`ActionButton { prominent: true }`).
- **Keyboard, no buttons in the way**: key hints live in the window's status line, not on
  buttons, in fields or in placeholders. A screen declares `statusMode`, `statusSegments`,
  `statusHints` (each `{ keys, label, run }`, run being what the key does) and
  `statusAlerts`, and the line adds the shared ones (`StatusBits.js`). Secondary actions are
  quiet text buttons (`PlainButton`, which can carry an icon); an unselected chip is its words alone,
  the selected one outlined in the accent.

New tokens for both are in `Theme.qml`'s "app-wide style" block.

## Window

A 64px icon rail (Home, Study, Wiki, Cards, Graph; the current one in the accent, Study with
the due count as a small accent figure), a 56px top bar (a quiet back arrow, the search box
that opens the palette, a fill with no border and no key printed in it, a status note for
backend failures, a quiet Add), the screen, and a 36px status line along the bottom, right of
the rail. Content sits in a reading column of 82 body characters, centred.

Keys everywhere: Ctrl+1–5 screens, Ctrl+K or `/` search (not on Study, where `/` is typed),
Ctrl+N Add, Alt+←/→ history. Esc closes an overlay. The reading screens name ⌃K, ⌃N (once the
window offers `toggleAdd()`) and alt+← (when there is history) in the status line.

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
readonly property bool statusShared      // default true; Study sets false
```

After a screen's own hints and alerts the line adds what every screen shares: ⌃K search, ⌃N
add, alt+← back (with history), and the pressure verdict while it is not ok, its clearance as
the tip and a click into Study. Study's keys and pressure are its session's, so it opts out.

A screen that declares no mode gets its name (HOME, WIKI, CARDS, GRAPH). Segments default
to `Theme.dim`; a hint without `run` is a legend, not a button; an alert shows `tip` on hover
and runs `run` on click. On a narrow window the mode and the alerts stay, the segments clip and
the hints drop whole from the end, so list them most important first.

## Home

The Glance, as the bar overlay's: the reviews due as the hero figure with "due", the week as a
small sparkline (Again in red, hidden when the week is empty) and the pressure verdict in an
outlined chip on the right; a dim sentence (clearance, cards added today, today's reviews and
streak, the new pool); maturity as a thin segmented bar and its legend; "Retention 75% over
115 reviews, 30 days · <calibration verdict>". Then NEXT UP (the first four pending reviews,
each with its deck's dot, and "+ N more" off the due count), and the footer: Study now, filled,
with the deck and the wiki as square icons. Below, each under a hairline and a caption: last
studied pages (latest review first, then coverage), recently updated, topic tiles (equal
height, a hairline in the topic's colour over the name and three pages). Status line: HOME,
the wiki's counts, ⌃2 study, the shared hints, the pressure verdict while it is not ok.

## Study

Drawn for the keyboard: no button rows, no session line, no hint footer; the status line has
the mode, the place and the keys. The card sits in the reading column, centred vertically
while it fits.

- Answering: the front large (20px), its tags
  faint, then a borderless prompt: an accent `›` and the answer box ("answer, or leave
  empty").
- Revealed: the front cut to a dim three-line recap; a box split by a hairline, "› you" with
  the typed answer (or "(nothing typed)") beside "back" on a faint fill; Claude's verdict as
  one line ("claude: good — reason", the verdict in its rating's colour; "claude: grading…"
  while it runs; the grader's error if it failed); a card issue as a quiet orange line with
  "fix in claude"; then four keycaps, `1 again 1m` `2 hard 2d` `3 good ◂ 4d` `4 easy 12d`,
  the interval dim and taken from the deck server's preview, the suggested one outlined at
  2px in its colour.
- Status line: STUDY (accent) while answering, RATE after the reveal in the suggested rating's
  colour, SYNC, LEECH (orange), DONE, ERROR (red). Segments: the position from the server
  (`3/12`), the deck, `repeat`. One hint, `alt+? keys`: Alt+? (or a click) opens the key list
  (KeyHelp.qml), a modal of the keys that work now, each row clickable; Esc or Alt+? closes it.
  Answering it lists `⇧↵ reveal`, `⌥↵ reveal+accept`, `⇧1-4 rate`, `⌃D discuss`, `⌃S skip`,
  `esc end`, `del delete`; revealed `⌥↵ take <rating>` (or `⇧↵ good` with no suggestion),
  `⇧1-4 rate` as a legend, discuss, skip, end, delete. Del asks in the
  confirm dialog, then deletes the card and the session goes on; with an answer typed and not
  yet revealed, Del edits the answer instead. Alerts: the pressure verdict when
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
it, subfolders, Outgoing, Linked from, each section under a hairline) or Tree. Centre:
breadcrumb, title, tags, updated and aliases (wrapped to the column), the cards button and
Claude actions as quiet text buttons, the page's blocks (code on a fill with no border), then
Linked from / Links to under hairlines. Status line: WIKI and the page's or folder's path.
Right (280px, wide windows only): the page's neighbourhood graph. Its left edge drags it wider
(kept while the app runs, never past the page's reading column), and a full-screen icon in its
corner opens the Graph screen around the page. The side panels drop out
before the reading column narrows below ~60% of its measure.

## Cards

Set in a wider column than the reading one (`Theme.pageWidth` with `Theme.cardsMeasure`, up to 1600px), since it is a
grid. At the top, the stage: the current card at a fixed height (`Theme.cardStageFaceHeight`),
its front set large (`Theme.cardStageFrontSize`) and centred, under a progress hairline; the
position ("12/357") and the ←/→ keys are in the status line. Paging shows the next card front up. Beside it (above it when the stage would drop
under 480px), a column that never scrolls; the stage takes its height, or its own least height
when the column is shorter: retention (`Retention · 30 days`, the figure with verdict and review
count, the rating mix), then the filters. The `▾ FILTER` header folds the section to what is
selected; the selected filters always sit on top, each with ✕ to drop it; then the text field
(kept when folded), the state bar and the remaining states, decks, and the six most common tags
with `N more tags ›` for the rest. All text links, no boxes.

Tags combine: a card must carry every picked tag. The tags offered, and the state bar, count only
the cards the other filters leave, so each choice shows how many cards it would leave and none
empties the grid. `N more tags ›` opens the tag panel, a sheet from the right over a scrim: the
picks on top with ✕, a `find a tag` field (tags starting with the text first), and every tag
still worth picking with its count. ↑/↓ choose, Enter picks and clears the field, Backspace in
the empty field drops the last pick, Esc or a click on the scrim closes; the status line names
those keys while it is up.
Below, `NEXT UP · n · m passed` and the grid: 2–5 tiles a row, each a hairline rule, the card's
tags and lapses, its position, and five lines of its front as plain text, so every tile is the
same height.

The stage and the grid are one walk through the filtered cards: the grid holds only the cards
after the stage's. Space or Enter flips; → or l moves on, taking that card off the grid; ← or
h moves back, putting it back. The walk stops at both ends (`from the start` goes back).
Clicking a tile makes it current, front up, and the cards before it count as passed. A change
of filter starts over; a refresh of the deck keeps the current card. Del (or the status line's
`del delete`) asks in the confirm dialog before deleting the stage's card; deleted, the walk goes
on at the next card, or the one before at the end. The keys are listed in
the window's status line (`statusMode`, `statusSegments`, `statusHints`, `statusAlerts`).

## Graph

All pages or two hops around the open page; topic legend; hubs and the hovered node's
neighbours labelled; click opens, drag pins, wheel zooms. Status line: GRAPH, the pages and
links drawn, and that mouse help (it used to be a line beside the chips).

## Overlays

Search palette (as tall as its results; Keyword or Deep; Ask streams, then renders like a page,
with Continue in Claude filled and Copy/Stop quiet; a foot line of clickable key hints: ↑↓
choose, ↵ open, ⌃↵ ask Claude, esc close, and ⌫ back to search once an answer is in), Add menu,
the topic dialog (the topic typed on a line; Open in Claude Code filled, Cancel quiet), the
confirm dialog (what goes quoted, what else goes in dim text, the action filled in red, Cancel
quiet; ↵ or y takes it, esc, n or the scrim cancels), a
page's cards (overview grid or flip-through), toasts. Dialogs and the palette have a 1px frame.
