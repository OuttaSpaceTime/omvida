import QtQuick
import QtTest
import "../../StudyKeys.js" as K

// Every study binding, phase by phase (StudyKeys.js has the why).
TestCase {
  name: "StudyKeys"

  function st(phase, extra) {
    var s = { phase: phase, hasSuggestion: false, answerEmpty: false }
    for (var k in extra) s[k] = extra[k]
    return s
  }

  function test_shift_enter_reveals_then_submits_good() {
    compare(K.action(st("answering"), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "reveal" })
    compare(K.action(st("revealed"), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "submit", rating: 3 })
    compare(K.action(st("grading"), Qt.Key_Enter, Qt.ShiftModifier, 0), { action: "submit", rating: 3 })
  }

  function test_alt_enter_accepts_the_suggestion() {
    compare(K.action(st("revealed", { hasSuggestion: true }), Qt.Key_Return, Qt.AltModifier, 0), { action: "accept" })
    compare(K.action(st("revealed", { hasSuggestion: false }), Qt.Key_Return, Qt.AltModifier, 0), null)
    compare(K.action(st("grading"), Qt.Key_Return, Qt.AltModifier, 0), { action: "acceptLater" })
    compare(K.action(st("answering"), Qt.Key_Return, Qt.AltModifier, 0), { action: "revealAccept" })
    compare(K.action(st("answering", { answerEmpty: true }), Qt.Key_Return, Qt.AltModifier, 0), { action: "reveal" })
  }

  function test_plain_enter_is_a_newline() {
    compare(K.action(st("answering"), Qt.Key_Return, Qt.NoModifier, 0), null)
    compare(K.action(st("revealed"), Qt.Key_Return, Qt.NoModifier, 0), null)
  }

  // Shift+digit arrives as the shifted character; the scan code wins when present.
  function test_shift_digits_rate_on_any_layout() {
    compare(K.action(st("answering"), Qt.Key_Exclam, Qt.ShiftModifier, 0), { action: "submit", rating: 1 })
    compare(K.action(st("answering"), Qt.Key_At, Qt.ShiftModifier, 0), { action: "submit", rating: 2 })
    compare(K.action(st("answering"), Qt.Key_QuoteDbl, Qt.ShiftModifier, 0), { action: "submit", rating: 2 })
    compare(K.action(st("revealed"), Qt.Key_NumberSign, Qt.ShiftModifier, 0), { action: "submit", rating: 3 })
    compare(K.action(st("revealed"), Qt.Key_section, Qt.ShiftModifier, 0), { action: "submit", rating: 3 })
    compare(K.action(st("grading"), Qt.Key_Dollar, Qt.ShiftModifier, 0), { action: "submit", rating: 4 })
    compare(K.action(st("answering"), Qt.Key_4, Qt.ShiftModifier, 0), { action: "submit", rating: 4 })
    // A layout where Shift+2 gives some other character still rates by scan code.
    compare(K.action(st("answering"), Qt.Key_Ampersand, Qt.ShiftModifier, 11), { action: "submit", rating: 2 })
  }

  function test_unshifted_digits_and_other_modifiers_type() {
    compare(K.action(st("answering"), Qt.Key_1, Qt.NoModifier, 10), null)
    compare(K.action(st("answering"), Qt.Key_Exclam, Qt.ShiftModifier | Qt.ControlModifier, 10), null)
    compare(K.shiftDigit(Qt.Key_5, Qt.ShiftModifier, 14), 0)
  }

  function test_discuss_and_skip() {
    compare(K.action(st("revealed"), Qt.Key_D, Qt.ControlModifier, 0), { action: "discuss" })
    compare(K.action(st("answering"), Qt.Key_S, Qt.ControlModifier, 0), { action: "skip" })
  }

  function test_escape_ends_the_session() {
    compare(K.action(st("answering"), Qt.Key_Escape, Qt.NoModifier, 0), { action: "end" })
    compare(K.action(st("grading"), Qt.Key_Escape, Qt.NoModifier, 0), { action: "end" })
    compare(K.action(st("revealed"), Qt.Key_Escape, Qt.NoModifier, 0), { action: "end" })
    compare(K.action(st("answering"), Qt.Key_Escape, Qt.ShiftModifier, 0), null)
  }

  function test_nothing_fires_outside_a_card() {
    compare(K.action(st("submitting"), Qt.Key_Return, Qt.ShiftModifier, 0), null)
    compare(K.action(st("blocked"), Qt.Key_Exclam, Qt.ShiftModifier, 10), null)
    compare(K.action(st("done"), Qt.Key_Return, Qt.AltModifier, 0), null)
  }
}
