# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Omvida is a standalone Quickshell (QML) app for the study wiki (`~/Code/study/wiki`) and its
flashcards (flashcard-mcp), with a study loop graded by `claude -p`. It is Omvision's sibling
and copies its practices; `~/Code/omvision/CLAUDE.md` has their history.

## Running and verifying

- **Never open the app on the user's desktop to test a change**, and never point a test at
  real data. Everything runs offscreen in a sandbox (`bin/sandbox`): a fixture study repo, a
  fixture deck built from flashcard-mcp's own schema, and fake `claude`, `kitty` and `qmd`
  first on PATH.
- `bin/check` runs everything a change should pass: lint (against `.qmllint-baseline`), the
  no-pixel-numbers rule, an offscreen load, `omarchy plugin validate` on `bar/`, and `bin/test`.
  Run it before you stop.
- `bin/test` has three layers: `py` (the wiki service, pytest), `unit` (the pure JS modules,
  qmltestrunner) and `app` (the real app driven from inside `qs`). `bin/test app study` runs
  one file. See `docs/testing.md`.
- Screenshots: `bin/shot` (fixtures, offscreen). Read every PNG. `bin/shot -R` shows your
  real wiki and deck read-only, and refuses anything that could write.
- A change to what a key or click does comes with an app test; a change to a JS module or the
  wiki service, with a unit or pytest case. Keep the objectNames in `docs/testing.md`.
- The deck server is flashcard-mcp's (`src/app/`); its tests are `npm test` there. Changing
  the protocol means changing both repos.

## Rules

- Read `docs/layout-rules.md` before UI work. Colours, type and spacing come from `Theme.qml`;
  never type a pixel number (`bin/check px`; `// check: allow-px <reason>` for the exceptions).
- No business rule lives here. Pressure, calibration, scheduling, leeches and the grading
  rubric are flashcard-mcp's; the wiki's link resolution mirrors the study repo's viewer
  (`backend/omvida_backend/wiki.py` says which rules). Show verdicts verbatim; never recompute.
- The app never edits cards or wiki pages. Those go through Claude Code skills in kitty
  (`Launch.js`), which own the content rules. The only writes the app makes are reviews,
  leech decisions (keep, delete) and deleting a card (Del on Cards or in Study) through the deck
  server, and the study log entry through the wiki service.
- Don't name a QML file after a QtQuick.Controls type (`Button`, `Dialog`...): in a file that
  imports Controls, the Controls type wins. That is why ours are `ActionButton` and `Modal`.
- Don't import a JS module as `Keys` (or any attached-property name): it shadows
  `Keys.onPressed`.
- Quickshell's `FileView` caveats in Omvision's CLAUDE.md apply if you add one.
- Comments explain *why*, in prose, including rejected alternatives. Keep them current.

## Deploying

`bar/` is installed as a symlink, `~/.config/omarchy/plugins/omvida.bar`, managed by chezmoi
(`~/Code/system`), as are the desktop entry, the icon and the theme hook. Edit the chezmoi
source, check `chezmoi diff`, and leave `chezmoi apply` to the user.
