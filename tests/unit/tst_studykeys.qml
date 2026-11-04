import QtQuick
import QtTest
import "../../StudyKeys.js" as K

// Every study binding, phase by phase (StudyKeys.js has the why).
TestCase {
  name: "StudyKeys"

  function st(phase, extra) {
    var s = { phase: phase, suggested: 0, answerEmpty: false }
    for (let k in extra) s[k] = extra[k]
    return s
  }

  function test_shift_enter_reveals_then_submits_good() {
    compare(K.action(st("answering"), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "reveal" })
    compare(K.action(st("revealed"), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "submit", rating: 3 })
    compare(K.action(st("grading"), Qt.Key_Enter, Qt.ShiftModifier, 0), { action: "submit", rating: 3 })
  }

  // Shift+Enter takes what is in play: the pick, else the suggestion, else Good.
  function test_shift_enter_takes_the_suggestion_over_good() {
    compare(K.action(st("revealed", { suggested: 4 }), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "submit", rating: 4 })
    compare(K.action(st("revealed", { suggested: 4, picked: 2 }), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "submit", rating: 2 })
    compare(K.action(st("revealed", { suggested: 0 }), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "submit", rating: 3 })
  }

  function test_alt_enter_accepts_the_suggestion() {
    compare(K.action(st("revealed", { suggested: 3 }), Qt.Key_Return, Qt.AltModifier, 0), { action: "accept" })
    compare(K.action(st("revealed", { suggested: 0 }), Qt.Key_Return, Qt.AltModifier, 0), null)
    compare(K.action(st("grading"), Qt.Key_Return, Qt.AltModifier, 0), { action: "acceptLater" })
    compare(K.action(st("answering"), Qt.Key_Return, Qt.AltModifier, 0), { action: "revealAccept" })
    compare(K.action(st("answering", { answerEmpty: true }), Qt.Key_Return, Qt.AltModifier, 0), { action: "reveal" })
  }

  function test_plain_enter_is_a_newline() {
    compare(K.action(st("answering"), Qt.Key_Return, Qt.NoModifier, 0), null)
    compare(K.action(st("revealed"), Qt.Key_Return, Qt.NoModifier, 0), null)
  }

  // Shift+digit arrives as the shifted character; the scan code wins when present.
  function test_shift_digits_pick_on_any_layout() {
    compare(K.action(st("answering"), Qt.Key_Exclam, Qt.ShiftModifier, 0), { action: "pick", rating: 1 })
    compare(K.action(st("answering"), Qt.Key_At, Qt.ShiftModifier, 0), { action: "pick", rating: 2 })
    compare(K.action(st("answering"), Qt.Key_QuoteDbl, Qt.ShiftModifier, 0), { action: "pick", rating: 2 })
    compare(K.action(st("revealed"), Qt.Key_NumberSign, Qt.ShiftModifier, 0), { action: "pick", rating: 3 })
    compare(K.action(st("revealed"), Qt.Key_section, Qt.ShiftModifier, 0), { action: "pick", rating: 3 })
    compare(K.action(st("grading"), Qt.Key_Dollar, Qt.ShiftModifier, 0), { action: "pick", rating: 4 })
    compare(K.action(st("answering"), Qt.Key_4, Qt.ShiftModifier, 0), { action: "pick", rating: 4 })
    // A layout where Shift+2 gives some other character still picks by scan code.
    compare(K.action(st("answering"), Qt.Key_Ampersand, Qt.ShiftModifier, 11), { action: "pick", rating: 2 })
    // A shifted character off the digit row types, even when another layout
    // puts it on a digit: '"' is Shift+' on US (scan code 48).
    compare(K.action(st("answering"), Qt.Key_QuoteDbl, Qt.ShiftModifier, 48), null)
    compare(K.action(st("revealed"), Qt.Key_NumberSign, Qt.ShiftModifier, 51), null)
  }

  // The first press never rates: before the reveal, not even the same digit
  // twice (the reveal comes first). Once the back shows, the picked digit
  // again or Shift+Enter submits the pick.
  function test_a_pick_rates_on_the_second_press() {
    compare(K.action(st("answering", { picked: 2 }), Qt.Key_2, Qt.ShiftModifier, 11), { action: "pick", rating: 2 })
    compare(K.action(st("revealed", { picked: 2 }), Qt.Key_2, Qt.ShiftModifier, 11), { action: "submit", rating: 2 })
    compare(K.action(st("grading", { picked: 2 }), Qt.Key_2, Qt.ShiftModifier, 11), { action: "submit", rating: 2 })
    compare(K.action(st("revealed", { picked: 2 }), Qt.Key_4, Qt.ShiftModifier, 13), { action: "pick", rating: 4 })
    compare(K.action(st("revealed", { picked: 1 }), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "submit", rating: 1 })
    compare(K.action(st("revealed", { picked: 0 }), Qt.Key_Return, Qt.ShiftModifier, 0), { action: "submit", rating: 3 })
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
    compare(K.action(st("answering", { answerEmpty: true }), Qt.Key_Escape, Qt.NoModifier, 0), { action: "end" })
    // A typed answer is not thrown away by a reflex Esc: the key is taken
    // (it doesn't reach the box) and does nothing.
    compare(K.action(st("answering"), Qt.Key_Escape, Qt.NoModifier, 0), { action: "none" })
    compare(K.action(st("grading"), Qt.Key_Escape, Qt.NoModifier, 0), { action: "end" })
    compare(K.action(st("revealed"), Qt.Key_Escape, Qt.NoModifier, 0), { action: "end" })
    compare(K.action(st("answering"), Qt.Key_Escape, Qt.ShiftModifier, 0), null)
  }

  // Del deletes the card (after the dialog), except while a typed answer
  // waits: there it edits the answer.
  function test_delete_deletes_the_card() {
    compare(K.action(st("answering", { answerEmpty: true }), Qt.Key_Delete, Qt.NoModifier, 0), { action: "delete" })
    compare(K.action(st("answering"), Qt.Key_Delete, Qt.NoModifier, 0), null)
    compare(K.action(st("grading"), Qt.Key_Delete, Qt.NoModifier, 0), { action: "delete" })
    compare(K.action(st("revealed"), Qt.Key_Delete, Qt.NoModifier, 0), { action: "delete" })
    compare(K.action(st("revealed"), Qt.Key_Delete, Qt.ControlModifier, 0), null)
    compare(K.action(st("submitting", { answerEmpty: true }), Qt.Key_Delete, Qt.NoModifier, 0), null)
    compare(K.action(st("done"), Qt.Key_Delete, Qt.NoModifier, 0), null)
  }

  // Ctrl+Z and Ctrl+Shift+Z are the ratings', everywhere a rating can be taken
  // back, unless an answer is typed: there they are the box's own.
  function test_ctrl_z_undoes_and_ctrl_shift_z_redoes() {
    var undo = Qt.ControlModifier, redo = Qt.ControlModifier | Qt.ShiftModifier
    var phases = ["grading", "revealed", "submitting", "loading", "blocked", "done"]
    for (let i = 0; i < phases.length; i++) {
      compare(K.action(st(phases[i]), Qt.Key_Z, undo, 0), { action: "undo" }, phases[i])
      compare(K.action(st(phases[i]), Qt.Key_Z, redo, 0), { action: "redo" }, phases[i])
    }
    compare(K.action(st("answering", { answerEmpty: true }), Qt.Key_Z, undo, 0), { action: "undo" })
    compare(K.action(st("answering", { answerEmpty: true }), Qt.Key_Z, redo, 0), { action: "redo" })
    compare(K.action(st("answering"), Qt.Key_Z, undo, 0), null, "a typed answer keeps the box's undo")
    compare(K.action(st("answering"), Qt.Key_Z, redo, 0), null)
    compare(K.action(st("revealed"), Qt.Key_Z, Qt.NoModifier, 0), null)
    compare(K.action(st("revealed"), Qt.Key_Z, Qt.ShiftModifier, 0), null)
    compare(K.action(st("revealed"), Qt.Key_Z, undo | Qt.AltModifier, 0), null)
    compare(K.action(st("idle"), Qt.Key_Z, undo, 0), null)
    compare(K.action(st("syncing"), Qt.Key_Z, undo, 0), null)
    compare(K.action(st("error"), Qt.Key_Z, undo, 0), null)
  }

  function test_nothing_fires_outside_a_card() {
    compare(K.action(st("submitting"), Qt.Key_Return, Qt.ShiftModifier, 0), null)
    compare(K.action(st("blocked"), Qt.Key_Exclam, Qt.ShiftModifier, 10), null)
    compare(K.action(st("done"), Qt.Key_Space, Qt.NoModifier, 0), null)
  }

  // With no card up, Enter goes on: a new session from idle, the summary or
  // an error, past a leech; Esc on a leech ends the session.
  function test_enter_goes_on_without_a_card() {
    compare(K.action(st("idle"), Qt.Key_Return, Qt.NoModifier, 0), { action: "start" })
    compare(K.action(st("done"), Qt.Key_Enter, Qt.KeypadModifier, 0), { action: "start" })
    compare(K.action(st("error"), Qt.Key_Return, Qt.NoModifier, 0), { action: "start" })
    compare(K.action(st("blocked"), Qt.Key_Return, Qt.NoModifier, 0), { action: "continue" })
    compare(K.action(st("blocked"), Qt.Key_Escape, Qt.NoModifier, 0), { action: "end" })
    compare(K.action(st("done"), Qt.Key_Escape, Qt.NoModifier, 0), null)
  }

  // Ctrl+N notes the card mid-study, in every phase a card is up; with no
  // card it is not Study's (the window's Add has it).
  function test_ctrl_n_notes_the_card() {
    compare(K.action(st("answering"), Qt.Key_N, Qt.ControlModifier, 0), { action: "note" })
    compare(K.action(st("answering", { answerEmpty: true }), Qt.Key_N, Qt.ControlModifier, 0), { action: "note" })
    compare(K.action(st("grading"), Qt.Key_N, Qt.ControlModifier, 0), { action: "note" })
    compare(K.action(st("revealed"), Qt.Key_N, Qt.ControlModifier, 0), { action: "note" })
    compare(K.action(st("done"), Qt.Key_N, Qt.ControlModifier, 0), null)
    compare(K.action(st("answering"), Qt.Key_N, Qt.NoModifier, 0), null, "a plain n is typed")
  }

  // Ctrl+Q checks the card's quality, in every phase a card is up, an
  // answer typed or not; Shift+Q is a capital Q in the answer.
  function test_ctrl_q_checks_the_card() {
    compare(K.action(st("answering"), Qt.Key_Q, Qt.ControlModifier, 0), { action: "check" })
    compare(K.action(st("answering", { answerEmpty: true }), Qt.Key_Q, Qt.ControlModifier, 0), { action: "check" })
    compare(K.action(st("grading"), Qt.Key_Q, Qt.ControlModifier, 0), { action: "check" })
    compare(K.action(st("revealed"), Qt.Key_Q, Qt.ControlModifier, 0), { action: "check" })
    compare(K.action(st("done"), Qt.Key_Q, Qt.ControlModifier, 0), null)
    compare(K.action(st("answering"), Qt.Key_Q, Qt.ShiftModifier, 0), null, "Shift+Q types a Q")
  }

  // ---- code cards ------------------------------------------------------------
  function codeState(extra) {
    var code = Object.assign({ enterChecks: true, canGiveUp: false, rating: 0 }, extra || {})
    return { phase: "answering", suggested: 0, answerEmpty: false, picked: 0, code: code }
  }

  function test_code_shift_enter_checks() {
    compare(K.action(codeState(), K.KEY.Return, K.MOD.Shift, 0), { action: "codeCheck" })
    compare(K.action(codeState({ enterChecks: false }), K.KEY.Return, K.MOD.Shift, 0), { action: "codeCheck" })
  }

  function test_code_enter_checks_in_an_inline_blank_and_types_in_a_block() {
    compare(K.action(codeState(), K.KEY.Return, 0, 0), { action: "codeCheck" })
    compare(K.action(codeState({ enterChecks: false }), K.KEY.Return, 0, 0), null)
  }

  function test_code_shift_digits_type_what_code_needs() {
    compare(K.action(codeState(), K.KEY.K1, K.MOD.Shift, 10), null, "! is typed")
    compare(K.action(codeState(), K.KEY.QuoteDbl, K.MOD.Shift, 11), null, "a quote is typed")
    compare(K.action(codeState(), K.KEY.Dollar, K.MOD.Shift, 13), null, "$ is typed")
  }

  function test_code_alt_enter_is_nothing_with_no_rating_to_take() {
    compare(K.action(codeState(), K.KEY.Return, K.MOD.Alt, 0), null)
  }

  function test_code_ctrl_g_gives_up_only_once_offered() {
    compare(K.action(codeState({ canGiveUp: true }), K.KEY.G, K.MOD.Control, 0), { action: "giveUp" })
    compare(K.action(codeState(), K.KEY.G, K.MOD.Control, 0), { action: "none" })
  }

  // Passed or given up on: the rating it came with, on Shift+Enter and nothing else.
  function test_code_decided_only_shift_enter_moves_on() {
    [3, 1].forEach(function(rating) {
      var s = codeState({ rating: rating })
      s.phase = "revealed"
      compare(K.action(s, K.KEY.Return, K.MOD.Shift, 0), { action: "submit", rating: rating })
      compare(K.action(s, K.KEY.Return, 0, 0), null, "a plain Enter doesn't")
      compare(K.action(s, K.KEY.Return, K.MOD.Alt, 0), null, "nor Alt+Enter")
      compare(K.action(s, K.KEY.K4, K.MOD.Shift, 13), null, "no rating to pick")
    })
  }

  function test_code_an_undone_rating_is_an_ordinary_revealed_card() {
    var s = codeState()
    s.phase = "revealed"
    s.picked = 3
    compare(K.action(s, K.KEY.Return, K.MOD.Shift, 0), { action: "submit", rating: 3 })
    compare(K.action(s, K.KEY.K1, K.MOD.Shift, 10), { action: "pick", rating: 1 })
  }

  function test_code_keeps_the_other_keys_of_a_card() {
    compare(K.action(codeState(), K.KEY.S, K.MOD.Control, 0), { action: "skip" })
    compare(K.action(codeState(), K.KEY.N, K.MOD.Control, 0), { action: "note" })
    compare(K.action(codeState({ }), K.KEY.Escape, 0, 0), { action: "none" }, "a typed answer is safe from Esc")
    var empty = codeState()
    empty.answerEmpty = true
    compare(K.action(empty, K.KEY.Escape, 0, 0), { action: "end" })
  }
}
