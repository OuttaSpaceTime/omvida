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
  `statusAlerts`; Home, Wiki and Graph build theirs with `StatusBits.js`. Secondary actions are
  quiet text buttons (`ActionButton { quiet: true }`); an unselected chip is its words alone,
  the selected one outlined in the accent.

New tokens for both are in `Theme.qml`'s "app-wide style" block.

## Window

A 64px icon rail (Home, Study, Wiki, Cards, Graph; the current one in the accent, Study with
the due count as a small accent figure), a 56px top bar (a quiet back arrow, the search box
that opens the palette, a fill with no border and no key printed in it, a status note for
backend failures, a quiet Add), the screen, and the window's status line. Content sits in a
reading column of 82 body characters, centred.

Keys everywhere: Ctrl+1–5 screens, Ctrl+K or `/` search (not on Study, where `/` is typed),
Ctrl+N Add, Alt+←/→ history. Esc closes an overlay. The reading screens name ⌃K, ⌃N (once the
window offers `toggleAdd()`) and alt+← (when there is history) in the status line.

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

The session line (`Card 3/12 · Deck (repeat)` from the server, and the session's make-up with
new cards held back), the previous card's result line, the front, its tags, the answer box,
then once revealed: the back, the suggestion box (rating in its colour, the reason, a card
issue with Fix in Claude), the four rating buttons (the suggested one filled) with their keys,
Reveal, Discuss, Skip, and a line of key hints for the phase. Keys: README's table.

States: syncing (Skip the sync), starting, answering, grading, revealed, submitting, blocked
(a leech: its card, Rewrite/Split in Claude, Delete with a confirm, Keep as is, Continue),
done (the summary with an honest duration, accuracy, lapses, leeches; related pages; a
walkthrough offer per lapse; Start another), error (Try again).

## Wiki

Left (280px): Context (You are here, the folder's pages with the open page's sections under
it, subfolders, Outgoing, Linked from, each section under a hairline) or Tree. Centre:
breadcrumb, title, tags, updated and aliases (wrapped to the column), the cards button and
Claude actions as quiet text buttons, the page's blocks (code on a fill with no border), then
Linked from / Links to under hairlines. Status line: WIKI and the page's or folder's path.
Right (280px, wide windows only): the page's neighbourhood graph. The side panels drop out
before the reading column narrows below ~60% of its measure.

## Cards

Retention (true retention, verdict, reasons, rating mix), the state bar and chips, text, deck
and tag filters, a count, List (60 at a time) or Flip through.

## Graph

All pages or two hops around the open page; topic legend; hubs and the hovered node's
neighbours labelled; click opens, drag pins, wheel zooms. Status line: GRAPH, the pages and
links drawn, and that mouse help (it used to be a line beside the chips).

## Overlays

Search palette (as tall as its results; Keyword or Deep; Ask streams, then renders like a page,
with Continue in Claude filled and Copy/Stop quiet; a foot line of clickable key hints: ↑↓
choose, ↵ open, ⌃↵ ask Claude, esc close, and ⌫ back to search once an answer is in), Add menu,
the topic dialog (the topic typed on a line; Open in Claude Code filled, Cancel quiet), a
page's cards (overview grid or flip-through), toasts. Dialogs and the palette have a 1px frame.
