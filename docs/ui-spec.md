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

Retention (true retention, verdict, reasons, rating mix), the state bar and chips, text, deck
and tag filters, a count, List (60 at a time) or Flip through.

## Graph

All pages or two hops around the open page; topic legend; hubs and the hovered node's
neighbours labelled; click opens, drag pins, wheel zooms.

## Overlays

Search palette (as tall as its results; Keyword or Deep; Ask streams, then renders like a page),
Add menu, the topic dialog, a page's cards (overview grid or flip-through), toasts.
