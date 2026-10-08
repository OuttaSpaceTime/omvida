# Testing

Everything runs offscreen, in a sandbox: no window opens, and the real deck, wiki and logs are
never read or written.

```bash
bin/check                       # lint, px, load, bar, test: run before you stop
bin/test                        # py + unit + app
bin/test py                     # the wiki service (pytest, ~0.2s)
bin/test unit                   # the pure JS modules (qmltestrunner, <1s)
bin/test app                    # the whole app, one qs run per tests/app/tst_*.qml (~1.5 min)
bin/test app study test_shift_digits_rate_without_typing_or_grading
bin/test -k / -v                # keep every sandbox / full runner output
bin/shot -s study -a answer     # a screenshot; read it
bin/shot -R -s graph            # your real wiki, read-only
```

`bin/check`'s steps live in `~/Code/qs-kit/bin/qs-check`, shared with Omvision; this repo's
`.qs-kit` gives the app name, the steps, how the load step starts the app (in a sandbox) and the
extra `bar` step. Without a qs-kit checkout beside this repo (or `QS_KIT`), `bin/check` says so
and stops.

## The sandbox (`bin/sandbox <dir> -- <cmd>`)

- `home/`: a HOME with no omarchy theme (the Flexoki fallback is drawn) and the
  `.omvida-test-home` marker the test harness checks before it runs anything.
- `study/`: a copy of `tests/fixtures/study`: four wiki pages (one a MOC), with a broken link,
  links in code, an embed, a callout, a table, a task list and highlighted code.
- `master.db`: the fixture deck, built by `tests/fixtures/make-deck.sh` with flashcard-mcp's
  own `prisma db push` (so its schema can never drift) and seeded by `seed_deck.py`: three
  review cards due, one new, one suspended, a few days of history. The card ids are the
  fixture wiki's `flashcard_ids`.
- `out/`: where the fakes record their calls.
- `tests/fixtures/bin` first on PATH: `claude` (grades 3, or 1 for "wrong", 4 for "perfect",
  flags a card issue for "flagme"; streams a short answer for Ask), `kitty` and `qmd`.

## Layers

- `tests/py`: the wiki service against the fixture study repo: links both ways, MOCs,
  sections, rendering (anchors, wikilinks, code classes, callouts, tables), ranking, the qmd
  output parser, the session log format and numbering, the protocol.
- `tests/unit`: `StudyKeys.js` (every binding in every phase, US and German Shift+digit),
  `Format.js`, `Cards.js`, `Graph.js`, `Launch.js` (the prompts and the Ask tool allowlist),
  `Session.js`, `StatusBits.js` (the status line's shared hints and pressure alert), and the
  bar's `Model.js`.
- `tests/app`: `OmvidaTest.qml` is Omvision's harness adapted: the app loads the test file
  through `OMVIDA_TEST`, and tests click and type into the real screens against the real
  backends. Helpers: `click`, `item`, `type`, `key`, `sql` (read the deck), `sqlWrite`,
  `kittyCalls`, `claudeCalls`, `gradeCalls`, `readFile`, `startSession`. Tests in a file share
  one app; a file whose tests change the deck resets what it needs in `init()` (tst_study makes
  every card due again), or gets a file of its own (tst_delete deletes cards, from Study and from Cards).

`started()` runs inside the test hook before the event loop turns, so it cannot run a process
(`sql`, `run`); do setup in the test itself.

## objectNames tests rely on

| objectName | control |
|---|---|
| `nav:<screen>` | the rail's icons |
| `searchBox`, `addButton`, `backButton` | the top bar |
| `add:flashcard`, `add:wiki`, `topicField`, `topicSubmit` | the Add menu and its dialog |
| `confirmDialog`, `confirmQuote`, `confirmAccept`, `confirmCancel` (`app.confirmOpen` says whether it is up) | the confirm dialog (Del on Cards and in Study) |
| `statusLine`, `statusMode`, `statusSegment:<i>`, `statusHint:<label>`, `statusAlert:<i>` | the status line (each has a plain `text`; hints are buttons: `statusHint:keys` on Study, `statusHint:delete` on Cards...) |
| `keyHelp:<label>` | Study's key list (Alt+?), its rows: `keyHelp:reveal`, `keyHelp:skip`... |
| `answerField`, `cardFront`, `cardRecap`, `cardBack`, `suggestionBox`, `suggestionLine` (`verdict`, `reason`), `fixCardButton` | the study card |
| `rate:<1-4>` (`suggested`; its `interval` label), `startSessionButton`, `studyAgainButton` | the study controls |
| `leechRewrite`, `leechSplit`, `leechDrop`, `leechDropConfirm`, `leechKeep`, `leechContinue` | a leech |
| `summary`, `summaryLine`, `related:<path>` | the session summary |
| `pageTitle`, `wikiFlick`, `pageCardsButton`, `pageAddCards`, `pageDeeper`, `heading:<anchor>` | a wiki page |
| `panelMode:context`, `panelMode:tree`, `tree:<path>`, `sibling:<path>`, `section:<anchor>` | the wiki side panel |
| `folderTitle`, `folder:<path>`, `folderPage:<path>` | a folder |
| `pageCardsFlip`, `flipCard` | a page's cards |
| `searchField`, `result:<kind>:<i>`, `deepSearch`, `askView`, `askAnswer`, `askAnswerBlocks`, `askContinue`, `paletteHint:<label>` | search and Ask |
| `stateChip:<state>`, `stateBar:<state>`, `tagChip:<tag>`, `cardFilter`, `filteredCount`, `clearFilters`, `retentionPanel`, `filtersToggle`, `selectedFilters`, `selected:<state|deck|tag>:<value>`, `moreTags` | the deck explorer's filters |
| `cardsStage` (its card is `flipCard`, the front `flipFront`), `upNext`, `cardsRestart`, `cardTile:<card id>` | the deck explorer's stage and grid |
| `graphScreen`, `graphAll`, `graphLocal`, `graphView` | the graph |
| `graphRailHandle`, `graphFullScreen` | the wiki page's graph rail: its drag edge, its full-screen icon |
| `homeScreen`, `homeStudyButton`, `homeCardsButton`, `homeWikiButton`, `recent:<path>`, `topic:<path>`, `dueFigure`, `pressureVerdict`, `calibrationVerdict` | home |

## What the tests don't cover

How things look (use `bin/shot`), the live omarchy theme, the bar plugin inside the running
shell (`omarchy plugin validate` checks its manifest and files; `bar/Model.js` is unit-tested),
the real `claude` (one real grade was checked by hand: 3.3s, sensible reason), and kitty itself.
