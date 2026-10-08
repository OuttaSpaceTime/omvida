.pragma library

// What a key press means on the Study screen. Pure, so tests/unit can pin
// every binding without a window; StudyScreen.qml only carries out the action
// returned.
//
// The bindings:
//   Shift+Enter   reveal: show the back and send a typed answer to the grader.
//                 Pressed again once revealed: submit Good.
//   Alt+Enter     accept the suggested rating. Before the reveal it reveals
//                 and accepts the suggestion the moment it arrives, so one
//                 key goes from answer to next card.
//   Shift+1..4    rate Again/Hard/Good/Easy at any point, overriding the
//                 suggestion. Before the reveal this rates without grading:
//                 "I knew it" or "no idea" needs no typing.
//   Ctrl+D        discuss the card in Claude Code.
//   Ctrl+S        skip the card. It stays due.
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
// Shift+digit is matched on the physical key, not the character. Shift+1
// arrives as "!" on a US layout and as "!" on German too, but Shift+3 is "#"
// on US and "§" on German, and Shift+2 is "@" or '"'. Qt reports the
// shifted character's key code, so matching Qt.Key_1 alone would never fire.
// The scan code is layout-free: under xkb it is the evdev code plus 8, which
// puts the digit row's 1..4 at 10..13. Tests synthesize key events with no
// scan code, so the shifted characters of the common layouts are a fallback.

var KEY = {
  Return: 0x01000004, Enter: 0x01000005, Escape: 0x01000000,
  K1: 0x31, K2: 0x32, K3: 0x33, K4: 0x34,
  Exclam: 0x21, At: 0x40, QuoteDbl: 0x22, NumberSign: 0x23, Section: 0xa7, Dollar: 0x24,
  D: 0x44, S: 0x53
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
  if (scanCode && SCAN_DIGITS[scanCode] !== undefined) return SCAN_DIGITS[scanCode]
  return SHIFTED[key] || 0
}

function isEnter(key) { return key === KEY.Return || key === KEY.Enter }

// state: { phase, hasSuggestion, answerEmpty }
//   phase: "idle" | "loading" | "answering" | "grading" | "revealed" | "submitting" |
//          "blocked" | "done" | "error"
// Returns { action, rating? } or null when the key is not ours (it then types
// into the answer field as usual).
//   reveal         show the back, grade the answer if there is one
//   revealAccept   reveal, then submit the suggestion when it arrives
//   accept         submit the suggestion now
//   acceptLater    the grader is still running: submit its rating on arrival
//   submit         submit `rating`
//   discuss, skip, end
//   start          a new session (Enter with no card up: idle, done, error)
//   continue       go on past a leech (Enter on one)
function action(state, key, modifiers, scanCode) {
  var phase = state.phase
  if (phase === "idle" || phase === "done" || phase === "error") return isEnter(key) ? { action: "start" } : null
  if (phase === "blocked") {
    if (isEnter(key)) return { action: "continue" }
    return key === KEY.Escape && !modifiers ? { action: "end" } : null
  }
  var active = phase === "answering" || phase === "grading" || phase === "revealed"
  if (!active) return null

  var digit = shiftDigit(key, modifiers, scanCode)
  if (digit) return { action: "submit", rating: digit }

  var ctrl = !!(modifiers & MOD.Control), alt = !!(modifiers & MOD.Alt), shift = !!(modifiers & MOD.Shift)
  if (ctrl && !alt && !shift && key === KEY.D) return { action: "discuss" }
  if (ctrl && !alt && !shift && key === KEY.S) return { action: "skip" }
  if (key === KEY.Escape && !ctrl && !alt && !shift && !(modifiers & MOD.Meta)) {
    if (phase === "answering" && !state.answerEmpty) return { action: "none" }
    return { action: "end" }
  }

  if (!isEnter(key)) return null
  if (shift && !ctrl && !alt) {
    return phase === "answering" ? { action: "reveal" } : { action: "submit", rating: 3 }
  }
  if (alt && !ctrl && !shift) {
    if (phase === "answering") return state.answerEmpty ? { action: "reveal" } : { action: "revealAccept" }
    if (phase === "grading") return { action: "acceptLater" }
    return state.hasSuggestion ? { action: "accept" } : null
  }
  return null
}
