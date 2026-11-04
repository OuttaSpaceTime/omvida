.pragma library

// What a key press means on the Study screen. Pure, so tests/unit can pin
// every binding without a window; StudySession.handleKey only carries out the
// action returned.
//
// The bindings:
//   Shift+Enter   reveal: show the back and send a typed answer to the grader.
//                 Pressed again once revealed: submit the rating in play, the
//                 one Shift+digit picked, else the suggestion, else Good. So
//                 it always takes what the keycaps show as chosen, and Good
//                 only when nothing is.
//   Alt+Enter     accept the suggested rating. Before the reveal it reveals
//                 and accepts the suggestion the moment it arrives, so one
//                 key goes from answer to next card.
//   Shift+1..4    pick Again/Hard/Good/Easy, overriding the suggestion. A
//                 pick never moves on: before the reveal it reveals too (and
//                 grades a typed answer), so the back is always seen before
//                 the card goes. The same digit again, or Shift+Enter, submits
//                 the pick; another digit changes it. Rating on the first
//                 press lost cards to a stray key: one shifted character
//                 matched by mistake (see below) rated eleven cards Hard in
//                 nine seconds.
//   Ctrl+D        discuss the card in Claude Code.
//   Ctrl+S        skip the card. It stays due.
//   Ctrl+N        note the card (NoteDialog.qml): an edit to make or a thing
//                 to understand, kept with the card for a fix session later,
//                 so the session goes on. Elsewhere Ctrl+N is the window's
//                 Add; on a card, noting it is what the hand wants, and Add
//                 is still the top bar's button.
//   Ctrl+Q        check the card's quality: Claude Code judges it in the
//                 background and fixes it if it is flawed (CardCheck.qml),
//                 while the session goes on, its result docked above the
//                 status line (CheckSlot.qml; Ctrl+Shift+Q dismisses it and
//                 Ctrl+Shift+D discusses it, the window's keys). Not Shift+Q:
//                 that types a Q into the answer.
//   Del           delete the card, after the window's confirm dialog asks.
//                 Not while an answer is typed and not yet revealed, for
//                 Esc's reason below: there Del edits the answer, as in any
//                 text box.
//   Ctrl+Z        undo the last rating, again for the one before, and so on:
//                 the card comes back revealed, as it was rated (StudySession's
//                 undo). Also on a leech and on the summary, and between cards,
//                 where the press waits for the card. Not while an answer is
//                 typed and not yet revealed, for Del's reason: there it is
//                 the box's own undo.
//   Ctrl+Shift+Z  redo a rating undone, the same way round.
//   Alt+?         the list of keys that work now (KeyHelp.qml), in any
//                 phase: the status line names only this one.
//   Esc           end the session: what was rated still counts, and the
//                 summary follows. The status line shows it as the way out
//                 (StatusLine.qml), so it is a key too. Not while an answer
//                 is typed and not yet revealed: Esc is a reflex for a vim
//                 or helix hand, and one press would throw the answer away
//                 (the status line's hint still ends it, on purpose). Overlays
//                 take Esc first: an open palette, dialog or Add menu has the
//                 keyboard. On a leech, Esc ends the session too.
// Plain Enter types a newline: answers are often code.
//
// On a code card, being answered (Execute Program's keys):
//   Shift+Enter   check: run it. Wrong is no penalty, so it can be pressed freely.
//   Enter         the same, in an inline blank, which has no use for a newline.
//   Tab           the next blank; in a block it indents, Shift+Tab outdents and
//                 Ctrl+Tab is the next blank (CodeBlank.qml, which handles these).
//   Ctrl+G        give up, once a check has failed: the solution, and rated
//                 Again when moved on from. Elsewhere it does nothing.
//   Shift+digit is no rating here. There is no rating to give, and it is how
//   `!`, `"` and `$` get typed, which code wants.
// Once it has passed or been given up on, the result stays up, and Shift+Enter,
// only that, moves on and writes the rating it came with: a plain Enter is what
// checks in an inline blank, so a repeat of it could pass over the reason unread.
// It went on by itself at first, after a pause, which was never the right length
// for reading. The card is otherwise as any card: Ctrl+D, Ctrl+S, Ctrl+N, Ctrl+Q
// and Esc, which still writes the rating, as the pass was earned.
//
// Shift+digit is matched on the physical key, not the character. Shift+1
// arrives as "!" on a US layout and as "!" on German too, but Shift+3 is "#"
// on US and "§" on German, and Shift+2 is "@" or '"'. Qt reports the
// shifted character's key code, so matching Qt.Key_1 alone would never fire.
// The scan code is layout-free: under xkb it is the evdev code plus 8, which
// puts the digit row's 1..4 at 10..13. Tests synthesize key events with no
// scan code, so the shifted characters of the common layouts are a fallback,
// and only then: a real key event always has a scan code, and the characters
// collide across layouts. '"' is Shift+2 on German but Shift+' on US, so with
// the fallback open to real keys, every quote typed into a US answer rated
// the card Hard and moved on.

var KEY = {
  Return: 0x01000004, Enter: 0x01000005, Escape: 0x01000000, Delete: 0x01000007,
  K1: 0x31, K2: 0x32, K3: 0x33, K4: 0x34,
  Exclam: 0x21, At: 0x40, QuoteDbl: 0x22, NumberSign: 0x23, Section: 0xa7, Dollar: 0x24,
  D: 0x44, S: 0x53, N: 0x4e, Q: 0x51, Z: 0x5a, G: 0x47, Question: 0x3f, Slash: 0x2f
}
var MOD = { Shift: 0x02000000, Control: 0x04000000, Alt: 0x08000000, Meta: 0x10000000 }

var SCAN_DIGITS = { 10: 1, 11: 2, 12: 3, 13: 4 }
var SHIFTED = {}
SHIFTED[KEY.K1] = 1; SHIFTED[KEY.K2] = 2; SHIFTED[KEY.K3] = 3; SHIFTED[KEY.K4] = 4
SHIFTED[KEY.Exclam] = 1
SHIFTED[KEY.At] = 2; SHIFTED[KEY.QuoteDbl] = 2
SHIFTED[KEY.NumberSign] = 3; SHIFTED[KEY.Section] = 3
SHIFTED[KEY.Dollar] = 4

// 1..4 for Shift + a digit-row key 1..4, else 0. Control or Alt held means
// it is some other shortcut.
function shiftDigit(key, modifiers, scanCode) {
  if (!(modifiers & MOD.Shift)) return 0
  if (modifiers & (MOD.Control | MOD.Alt | MOD.Meta)) return 0
  if (scanCode) return SCAN_DIGITS[scanCode] || 0
  return SHIFTED[key] || 0
}

function isEnter(key) { return key === KEY.Return || key === KEY.Enter }

// Where Ctrl+Z and Ctrl+Shift+Z mean a rating. Not the sync or the session's
// start, which have rated nothing yet, nor an error, where the session's state
// is in doubt. Whether there is one to take back is the session's to say.
var HISTORY_PHASES = ["answering", "grading", "revealed", "submitting", "loading", "blocked", "done"]

// state: { phase, suggested, answerEmpty, picked, code }
//   code: on a code card, what its keys need: { enterChecks, canGiveUp, rating },
//         enterChecks being whether the blank in hand is an inline one, and
//         rating the one a pass or a give-up came with, waiting to be moved on from
//   picked: the rating Shift+digit picked on this card, 1..4, else 0
//   suggested: the grader's rating, 1..4, else 0 (none arrived yet)
//   phase: "idle" | "loading" | "answering" | "grading" | "revealed" | "submitting" |
//          "blocked" | "done" | "error"
// Returns { action, rating? } or null when the key is not ours (it then types
// into the answer field as usual).
//   reveal         show the back, grade the answer if there is one
//   revealAccept   reveal, then submit the suggestion when it arrives
//   accept         submit the suggestion now
//   acceptLater    the grader is still running: submit its rating on arrival
//   pick           reveal if need be, and pick `rating` without submitting
//   submit         submit `rating`
//   discuss, skip, note, check, end, delete
//   undo, redo     take back the last rating, or give back one taken back
//   help           show the keys (Alt+?, in every phase)
//   codeCheck, giveUp  a code card's try, and its way out
//   start          a new session (Enter with no card up: idle, done, error)
//   continue       go on past a leech (Enter on one)
function action(state, key, modifiers, scanCode) {
  var phase = state.phase
  // "?" is Shift+/ on most layouts; some report the slash with Shift held.
  if ((modifiers & MOD.Alt) && (key === KEY.Question || (key === KEY.Slash && (modifiers & MOD.Shift))))
    return { action: "help" }
  if ((modifiers & MOD.Control) && !(modifiers & (MOD.Alt | MOD.Meta)) && key === KEY.Z
      && HISTORY_PHASES.indexOf(phase) !== -1 && (phase !== "answering" || state.answerEmpty))
    return { action: (modifiers & MOD.Shift) ? "redo" : "undo" }
  if (phase === "idle" || phase === "done" || phase === "error") return isEnter(key) ? { action: "start" } : null
  if (phase === "blocked") {
    if (isEnter(key)) return { action: "continue" }
    return key === KEY.Escape && !modifiers ? { action: "end" } : null
  }
  var active = phase === "answering" || phase === "grading" || phase === "revealed"
  if (!active) return null

  var codeAnswering = !!state.code && phase === "answering"
  var codeDecided = !!state.code && state.code.rating > 0
  var digit = codeAnswering || codeDecided ? 0 : shiftDigit(key, modifiers, scanCode)
  if (digit) {
    if (phase !== "answering" && state.picked === digit) return { action: "submit", rating: digit }
    return { action: "pick", rating: digit }
  }

  var ctrl = !!(modifiers & MOD.Control), alt = !!(modifiers & MOD.Alt), shift = !!(modifiers & MOD.Shift)
  if (ctrl && !alt && !shift && key === KEY.D) return { action: "discuss" }
  if (ctrl && !alt && !shift && key === KEY.S) return { action: "skip" }
  if (ctrl && !alt && !shift && key === KEY.N) return { action: "note" }
  if (ctrl && !alt && !shift && key === KEY.Q) return { action: "check" }
  if (codeAnswering && ctrl && !alt && !shift && key === KEY.G) return state.code.canGiveUp ? { action: "giveUp" } : { action: "none" }
  if (key === KEY.Escape && !ctrl && !alt && !shift && !(modifiers & MOD.Meta)) {
    if (phase === "answering" && !state.answerEmpty) return { action: "none" }
    return { action: "end" }
  }
  if (key === KEY.Delete && !ctrl && !alt && !shift && !(modifiers & MOD.Meta)) {
    if (phase === "answering" && !state.answerEmpty) return null
    return { action: "delete" }
  }

  if (!isEnter(key)) return null
  if (codeAnswering) {
    if (ctrl || alt) return null
    return shift || state.code.enterChecks ? { action: "codeCheck" } : null
  }
  if (codeDecided) return shift && !ctrl && !alt ? { action: "submit", rating: state.code.rating } : null
  if (shift && !ctrl && !alt) {
    return phase === "answering" ? { action: "reveal" } : { action: "submit", rating: state.picked || state.suggested || 3 }
  }
  if (alt && !ctrl && !shift) {
    if (phase === "answering") return state.answerEmpty ? { action: "reveal" } : { action: "revealAccept" }
    if (phase === "grading") return { action: "acceptLater" }
    return state.suggested > 0 ? { action: "accept" } : null
  }
  return null
}
