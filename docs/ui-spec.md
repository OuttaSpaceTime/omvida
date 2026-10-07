# UI spec

Tokens are `Theme.qml`'s, which are Omvision's (the contrast-solved `secondaryInk`/`dim`/`faint`,
the 4px spacing scale, square 1px controls) plus the theme's named hues for syntax, topics,
card states, ratings and verdicts. Body 15px; the card front 20px, the largest text in the app.

## Window

A 64px icon rail (Home, Study, Wiki, Cards, Graph; Study carries the due badge), a 56px top bar
(back, the search box that opens the palette, a status note for backend failures, Add), and the
screen. Content sits in a reading column of 82 body characters, centred.

Keys everywhere: Ctrl+1–5 screens, Ctrl+K or `/` search (not on Study, where `/` is typed),
Ctrl+N Add, Alt+←/→ history. Esc closes an overlay.

## Home

The study panel (pressure verdict in its colour, the reviews due, clearance, calibration, the
week as bars with Again in red, maturity as one stacked bar, Study now), pending reviews, last
studied pages (latest review first, then coverage), recently updated, topic tiles.

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
it, subfolders, Outgoing, Linked from) or Tree. Centre: breadcrumb, title, tags, updated and
aliases, the cards button and Claude actions, the page's blocks, then Linked from / Links to.
Right (280px, wide windows only): the page's neighbourhood graph. The side panels drop out
before the reading column narrows below ~60% of its measure.

## Cards

Set in a wider column than the reading one (`Theme.cardsWidth`, up to 1600px), since it is a
grid. At the top, the stage: the current card large, front first, its position (`Card 12 of
357`, a progress hairline) and quiet ‹ back / next › links; beside it (above it when the stage
would drop under 480px), retention (true retention, verdict, reasons, rating mix) and the
filters (text, state bar and states, decks, tags, a count, clear), all text links, no boxes.
Below, `NEXT UP · n · m passed` and the grid: 2–5 tiles a row, each a hairline rule, the card's
tags and lapses, its position, and five lines of its front as plain text, so every tile is the
same height.

The stage and the grid are one walk through the filtered cards: the grid holds only the cards
after the stage's. Space or Enter flips; → or l moves on, taking that card off the grid; ← or
h moves back, putting it back. The walk stops at both ends (`from the start` goes back).
Clicking a tile makes it current, front up, and the cards before it count as passed. A change
of filter starts over; a refresh of the deck keeps the current card. The keys are listed in
the window's status line (`statusMode`, `statusSegments`, `statusHints`, `statusAlerts`).

## Graph

All pages or two hops around the open page; topic legend; hubs and the hovered node's
neighbours labelled; click opens, drag pins, wheel zooms.

## Overlays

Search palette (as tall as its results; Keyword or Deep; Ask streams, then renders like a page),
Add menu, the topic dialog, a page's cards (overview grid or flip-through), toasts.
