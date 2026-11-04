import QtQuick

// Code cards in a session: running what is typed, checking it, passing, giving
// up, and the undo and the keys around them. The session is only code cards
// (seed_deck.py --code): a prediction, a fill, a block to write. The runner and
// the rules are the deck server's real ones, in its real sandbox.
OmvidaTest {
  name: "code"

  function init() {
    if (study.phase !== "idle" && study.phase !== "done") study.endNow()
    compare(run(["python3", repo + "/tests/fixtures/seed_deck.py", deckDb, "--code"]).code, 0, "seeded")
    sqlWrite("DELETE FROM Review WHERE id NOT LIKE 'fixturereview%'")
  }

  // A session, on the card of this kind: the others are skipped past.
  function onCard(kind) {
    startSession()
    tryVerify(function() { return study.isCode }, 5000, "a code card is up")
    while (study.card.exercise.kind !== kind) {
      let at = study.card.id
      study.skip()
      tryVerify(function() { return study.phase === "answering" && study.card.id !== at }, 5000)
    }
    tryVerify(function() { return item("codeBlank:0").activeFocus }, 3000, "the first blank has the keyboard")
  }

  function verdict() { return item("codeVerdict").text }

  function test_a_code_card_shows_the_brief_and_blanks_and_not_the_answer() {
    onCard("fill")
    compare(item("codeBrief").html, "Keep the even numbers, squared.")
    compare(item("statusMode").text, "CODE")
    compare(item("codeBlank:0").text, "")
    compare(findNamed(target, "answerField"), null, "no ordinary answer box")
    verify(JSON.stringify(study.card.exercise).indexOf('"map"') === -1, "the solution isn't in what the app was sent")
    compare(item("codeExpected:0").text, "[4]", "the goal is on show from the start")
    compare(item("codeActual:0").text, "–")
  }

  // ---- the output follows the typing, quietly ----------------------------------
  function test_typing_runs_the_code_with_no_animation_and_no_rating() {
    onCard("fill")
    type("select")
    tryVerify(function() { return study.code.result !== null }, 5000, "it ran at the pause")
    tryCompare(item("codeActual:0"), "text", "[2]", 3000)
    compare(item("codeExpected:0").text, "[4]")
    compare(verdict(), "1 of 2 match")
    verify(!item("codeCard").shaking, "no shake from typing")
    compare(study.phase, "answering")
    compare(reviews().length, 0)
    compare(item("codeOutput").text, "loaded", "what it printed shows too")
  }

  function test_a_mistake_shows_the_real_error_quietly_as_it_is_typed() {
    onCard("fill")
    type("nope")
    tryVerify(function() { return item("codeActual:0").text.indexOf("NoMethodError") !== -1 }, 5000, "the error is the output")
    verify(item("codeActual:0").text.indexOf("main.rb:2") !== -1, "with the line: " + item("codeActual:0").text)
    compare(verdict(), "error")
    verify(!item("codeCard").shaking)
  }

  // Half-typed code doesn't compile at nearly every pause: no red until a check.
  function test_a_syntax_error_waits_for_a_check() {
    onCard("fill")
    type("map {")
    wait(800)   // past the pause that runs it
    compare(study.code.result, null, "nothing said while typing")
    compare(findNamed(target, "codeError"), null)
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return item("codeError").text !== "" }, 5000, "the check says it")
    verify(item("codeError").text.indexOf("main.rb") !== -1, item("codeError").text)
    verify(item("codeCard").shaking)
    // It goes once the code has changed and still doesn't compile, and the last
    // result that did compile stays through a line being typed.
    type("{")
    tryVerify(function() { return findNamed(target, "codeError") === null }, 5000, "the old error goes")
    compare(study.code.result, null)
  }

  function test_a_result_stays_through_code_that_stops_compiling() {
    onCard("fill")
    type("select")
    tryCompare(item("codeActual:0"), "text", "[2]", 5000)
    type(" {")
    wait(800)
    compare(item("codeActual:0").text, "[2]", "the last run stands")
    compare(findNamed(target, "codeError"), null)
  }

  // ---- a check -------------------------------------------------------------------
  // Passed: the result and the why stay up, unrated, until Shift+Enter again.
  function pass() {
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 5000)
    compare(study.code.rating, 3)
  }
  function moveOn() {
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return reviews().length === 1 }, 5000)
  }

  function test_a_pass_waits_for_a_second_shift_enter_then_rates_good_and_moves_on() {
    onCard("fill")
    var cardId = study.card.id
    type("map")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return item("codeCard").flashing }, 5000, "the pass flashes")
    compare(verdict(), "✓ matches")
    tryCompare(item("codeExplain"), "visible", true, 2000)
    wait(1800)   // past anything that used to move on by itself
    compare(study.phase, "revealed", "it stays up")
    compare(study.card.id, cardId)
    compare(reviews().length, 0, "not rated yet")
    compare(findNamed(target, "rate:3"), null, "no rating to choose")
    verify(item("codeBlank:0").readOnly)
    key(Qt.Key_Return)
    compare(study.phase, "revealed", "a plain Enter doesn't move on")
    moveOn()
    compare(reviews()[0], [cardId, 3], "rated Good with no step of choosing")
    tryVerify(function() { return study.phase === "answering" && study.card.id !== cardId || study.phase === "done" }, 8000, "and on to the next")
  }

  function test_esc_on_a_pass_still_writes_it() {
    onCard("fill")
    var cardId = study.card.id
    type("map")
    pass()
    key(Qt.Key_Escape)
    tryCompare(study, "phase", "done", 5000)
    compare(reviews().length, 1)
    compare(reviews()[0], [cardId, 3])
  }

  function test_enter_in_an_inline_blank_checks_as_well() {
    onCard("fill")
    type("map")
    key(Qt.Key_Return)
    tryCompare(study, "phase", "revealed", 5000)
    compare(study.code.rating, 3)
  }

  function test_a_wrong_check_shakes_and_costs_nothing() {
    onCard("fill")
    var cardId = study.card.id
    type("select")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return item("codeCard").shaking }, 5000, "the check shakes")
    compare(verdict(), "1 of 2 match")
    compare(study.phase, "answering", "the card stays")
    compare(reviews().length, 0)
    // As many as it takes, then Good all the same.
    item("codeBlank:0").selectAll()
    type("map")
    pass()
    moveOn()
    compare(reviews()[0], [cardId, 3], "tries don't lower the rating")
  }

  function test_an_error_checked_shakes_and_stays_on_screen() {
    onCard("fill")
    type("nope")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return item("codeCard").shaking }, 5000)
    verify(item("codeActual:0").text.indexOf("NoMethodError") !== -1)
    wait(600)
    verify(item("codeActual:0").text.indexOf("NoMethodError") !== -1, "an error stays")
    compare(reviews().length, 0)
  }

  function test_an_empty_check_counts_as_a_try_and_says_so_without_a_shake() {
    onCard("fill")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.code.canGiveUp }, 5000, "the way out opens")
    compare(verdict(), "fill in the blanks")
    verify(!item("codeCard").shaking)
  }

  function test_code_can_be_typed_with_shift_digits() {
    onCard("fill")
    type("!\"$")
    compare(item("codeBlank:0").text, "!\"$")
    compare(study.picked, 0)
    compare(study.phase, "answering")
  }

  // ---- a prediction --------------------------------------------------------------
  function test_a_prediction_shows_no_output_until_it_is_right() {
    onCard("predict")
    type("[2, 4]")
    wait(700)
    compare(study.code.result, null, "typing runs nothing: the code would answer it")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return item("codeCard").shaking }, 5000)
    compare(verdict(), "doesn't match")
    compare(item("codeActual:0").text, "–", "the real value stays hidden")
    compare(item("codeExpected:0").text, "[2, 4]", "beside what you said")
    compare(findNamed(target, "codeOutput"), null, "and what it printed")
  }

  function test_a_prediction_passes_on_any_expression_of_the_value() {
    onCard("predict")
    var cardId = study.card.id
    type("[3 - 2, 2]")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return item("codeCard").flashing }, 5000)
    compare(item("codeActual:0").text, "[1, 2]")
    compare(item("codeOutput").text, "ran")
    moveOn()
    compare(reviews()[0], [cardId, 3])
  }

  function test_a_prediction_that_does_not_parse_says_so_and_isnt_wrong() {
    onCard("predict")
    type("[1,")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return verdict() === "error" }, 5000)
    verify(item("codeActual:0").text.indexOf("goal 1") !== -1, item("codeActual:0").text)
  }

  // ---- a block to write ----------------------------------------------------------
  function test_a_block_takes_newlines_and_checks_on_shift_enter() {
    onCard("compose")
    verify(study.code.blockFocused, "the block has the keyboard")
    compare(item("codeBlank:0").text, "  ", "a method's body starts indented")
    type("x = n")
    key(Qt.Key_Return)
    compare(item("codeBlank:0").text, "  x = n\n  ", "Enter is a newline, keeping the indentation")
    type("x * 2")
    key(Qt.Key_Return)
    pass()
    moveOn()
    compare(reviews()[0][1], 3)
  }

  // The bug: `new_list` with no Enter after it ran into `end` as `new_listend`.
  function test_a_block_with_no_newline_after_its_last_line_still_runs() {
    onCard("compose")
    type("n * 2")
    compare(item("codeBlank:0").text, "  n * 2")
    pass()
    compare(verdict(), "✓ matches")
  }

  function test_a_block_indents_as_an_editor_does() {
    onCard("compose")
    var blank = item("codeBlank:0")
    type("[1].each do |x|")
    key(Qt.Key_Return)
    compare(blank.text, "  [1].each do |x|\n    ", "one further after a do")
    type("x")
    key(Qt.Key_Return)
    compare(blank.text, "  [1].each do |x|\n    x\n    ")
    type("end")
    key(Qt.Key_Return)
    compare(blank.text, "  [1].each do |x|\n    x\n  end\n  ", "end comes back out")
    key(Qt.Key_Backspace)
    compare(blank.text, "  [1].each do |x|\n    x\n  end\n", "an indent goes whole")
    key(Qt.Key_Tab)
    compare(blank.text, "  [1].each do |x|\n    x\n  end\n  ", "Tab puts it back")
    verify(blank.activeFocus, "and stays in the block")
    key(Qt.Key_Backtab, Qt.ShiftModifier)
    compare(blank.text, "  [1].each do |x|\n    x\n  end\n", "Shift+Tab takes it off")
    type("nx")
    compare(blank.text.slice(-2), "nx", "the cursor stayed at the end of it all")
  }

  function test_the_key_list_of_a_block_says_what_its_keys_do() {
    onCard("compose")
    key(Qt.Key_Question, Qt.AltModifier)
    compare(item("keyHelp:check").keys, "shift+enter")
    compare(item("keyHelp:new line, indented").keys, "enter")
    compare(item("keyHelp:indent").keys, "tab")
    compare(item("keyHelp:outdent").keys, "shift+tab")
    item("keyHelp:give up")
    item("keyHelp:discuss")
    item("keyHelp:note")
    item("keyHelp:check quality")
    item("keyHelp:skip")
    item("keyHelp:end")
    item("keyHelp:delete")
    compare(findNamed(target, "keyHelp:reveal"), null, "not an ordinary card's")
    key(Qt.Key_Escape)
    tryVerify(function() { return findNamed(target, "keyHelp:check") === null }, 3000)
  }

  function test_the_key_list_says_how_to_move_on_from_a_pass() {
    onCard("fill")
    type("map")
    pass()
    key(Qt.Key_Question, Qt.AltModifier)
    compare(item("keyHelp:next").keys, "shift+enter")
    compare(findNamed(target, "keyHelp:check"), null, "nothing left to check")
    key(Qt.Key_Escape)
    tryVerify(function() { return findNamed(target, "keyHelp:next") === null }, 3000)
    compare(study.phase, "revealed", "Esc closed the list, not the session")
  }

  // ---- giving up -----------------------------------------------------------------
  function test_giving_up_needs_a_try_shows_the_solution_and_rates_again() {
    onCard("fill")
    var cardId = study.card.id
    key(Qt.Key_G, Qt.ControlModifier)
    compare(study.phase, "answering", "not before a check has failed")
    type("select")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.code.canGiveUp }, 5000)
    key(Qt.Key_G, Qt.ControlModifier)
    tryCompare(study, "phase", "revealed", 5000)
    compare(item("codeBlank:0").text, "map", "the solution in the blank")
    verify(item("codeBlank:0").readOnly)
    compare(verdict(), "the solution", "no tick for having given up")
    compare(item("codeActual:0").text, "[4]", "run, and seen to work")
    verify(item("codeExplain").visible, "with the reason")
    compare(reviews().length, 0, "the card stays up to be read")
    compare(findNamed(target, "rate:1"), null, "no rating to choose")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return reviews().length === 1 }, 5000)
    compare(reviews()[0], [cardId, 1], "rated Again")
  }

  // ---- around it -----------------------------------------------------------------
  function test_undo_brings_a_passed_card_back_with_its_answer_and_the_keycaps() {
    onCard("fill")
    var cardId = study.card.id
    type("map")
    pass()
    moveOn()
    key(Qt.Key_Z, Qt.ControlModifier)
    tryVerify(function() { return study.phase === "revealed" && study.card && study.card.id === cardId }, 8000)
    tryVerify(function() { return reviews().length === 0 }, 5000)
    compare(item("codeBlank:0").text, "map")
    verify(item("rate:3").visible, "the keycaps, to correct it by hand")
    verify(item("rate:3").marked)
    compare(item("codeVerdict").text, "✓ matches")
    var four = item("rate:4")
    key(Qt.Key_4, Qt.ShiftModifier)
    verify(four.marked, "another rating can be picked")
  }

  function test_the_key_list_is_a_code_cards() {
    onCard("fill")
    key(Qt.Key_Question, Qt.AltModifier)
    compare(item("keyHelp:check").keys, "enter, shift+enter", "either checks in an inline blank")
    item("keyHelp:give up")
    compare(findNamed(target, "keyHelp:indent"), null, "indenting is a block's")
    key(Qt.Key_Escape)
    tryVerify(function() { return findNamed(target, "keyHelp:check") === null && item("codeBlank:0").activeFocus }, 3000)
    type("sel")
    key(Qt.Key_Question, Qt.AltModifier)
    item("keyHelp:undo typing")
    key(Qt.Key_Escape)
  }

  function test_skip_leaves_no_rating_and_clears_the_card() {
    onCard("fill")
    var cardId = study.card.id
    type("select")
    key(Qt.Key_S, Qt.ControlModifier)
    tryVerify(function() { return study.phase === "answering" && study.card.id !== cardId }, 5000)
    compare(reviews().length, 0)
    compare(study.code.result, null)
  }

  // ---- what else can happen to a card up ---------------------------------------
  // The give-up comes back as one: the solution, not a pass of the developer's.
  function test_undo_brings_a_give_up_back_as_a_give_up() {
    onCard("fill")
    type("select")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.code.canGiveUp }, 5000)
    key(Qt.Key_G, Qt.ControlModifier)
    tryCompare(study, "phase", "revealed", 5000)
    var cardId = study.card.id
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return reviews().length === 1 }, 5000)
    key(Qt.Key_Z, Qt.ControlModifier)
    tryVerify(function() { return study.phase === "revealed" && study.card && study.card.id === cardId }, 8000)
    verify(study.code.gaveUp)
    compare(verdict(), "the solution")
    verify(item("rate:1").marked, "Again, as given, to correct by hand")
  }

  function test_a_pass_shown_goes_once_the_answer_is_gone() {
    onCard("fill")
    type("map")
    tryCompare(item("codeVerdict"), "text", "✓ matches", 5000)
    item("codeBlank:0").selectAll()
    key(Qt.Key_Delete)
    tryCompare(study.code, "result", null, 5000)
  }

  function exerciseWithTwoBlanks() {
    return JSON.stringify({
      kind: "fill", lang: "ruby", brief: "Two blanks.",
      source: "a = {{c1::1}}\nb = {{c1::2}}",
      cases: [{ expr: "a + b", goal: "3" }],
      explain: "Addition."
    })
  }
  function rewrite(id, exercise) {
    sqlWrite("UPDATE Card SET exercise = '" + exercise + "', updatedAt = strftime('%Y-%m-%dT%H:%M:%f+00:00', 'now') WHERE id = '" + id + "'")
  }

  // Ctrl+Q fixing the card while it is being typed in, say.
  function test_a_card_changed_mid_answer_starts_over_with_the_keyboard() {
    onCard("fill")
    type("select")
    rewrite(study.card.id, exerciseWithTwoBlanks())
    tryCompare(item("codeBrief"), "html", "Two blanks.", 15000)
    compare(item("codeBlank:0").text, "")
    compare(study.code.answers, ["", ""])
    tryVerify(function() { return item("codeBlank:0").activeFocus }, 3000, "the keyboard came back")
    type("1")
    tryCompare(item("codeBlank:0"), "text", "1", 3000)
    compare(study.code.answers, ["1", ""])
  }

  function test_the_key_list_closing_hands_the_keyboard_back_to_the_same_blank() {
    onCard("fill")
    rewrite(study.card.id, exerciseWithTwoBlanks())
    tryCompare(item("codeBrief"), "html", "Two blanks.", 15000)
    tryVerify(function() { return item("codeBlank:0").activeFocus }, 3000)
    key(Qt.Key_Tab)
    tryVerify(function() { return item("codeBlank:1").activeFocus }, 3000)
    key(Qt.Key_Question, Qt.AltModifier)
    item("keyHelp:check")
    key(Qt.Key_Escape)
    tryVerify(function() { return item("codeBlank:1").activeFocus }, 3000, "not back at the first")
  }

  // A long answer wraps inside the listing, and takes the code after it along.
  function test_a_long_answer_stays_inside_the_listing() {
    onCard("fill")
    var long = ""
    for (let i = 0; i < 200; i++) long += "x"
    study.code.answers = [long]
    study.code.answersSet()
    var blank = item("codeBlank:0")
    var listing = item("codeListing")
    tryVerify(function() { return blank.lineCount > 1 }, 3000, "it wraps")
    tryVerify(function() { return blank.mapToItem(listing, blank.width, 0).x <= listing.width }, 3000,
              "right edge " + blank.mapToItem(listing, blank.width, 0).x + " of " + listing.width)
  }

  // ---- several blanks, one of them a block --------------------------------------
  function mixedExercise() {
    return JSON.stringify({
      kind: "fill", lang: "ruby", brief: "An inline blank and a block.",
      source: "a = {{c1::1}}\ndef f\n{{c1::  2\n}}end",
      cases: [{ expr: "a + f", goal: "3" }],
      explain: "Both."
    })
  }

  function test_tab_and_ctrl_tab_move_between_blanks_and_the_key_list_says_which() {
    onCard("fill")
    rewrite(study.card.id, mixedExercise())
    tryCompare(item("codeBrief"), "html", "An inline blank and a block.", 15000)
    tryVerify(function() { return item("codeBlank:0").activeFocus }, 3000)
    key(Qt.Key_Question, Qt.AltModifier)
    compare(item("keyHelp:next blank").keys, "tab", "Tab moves on from an inline blank")
    key(Qt.Key_Escape)
    tryVerify(function() { return item("codeBlank:0").activeFocus }, 3000)
    key(Qt.Key_Tab)
    tryVerify(function() { return item("codeBlank:1").activeFocus }, 3000, "to the block")
    verify(study.code.blockFocused)
    var before = item("codeBlank:1").text
    key(Qt.Key_Tab)
    verify(item("codeBlank:1").text.length > before.length, "Tab indents in a block")
    verify(item("codeBlank:1").activeFocus, "and stays in it")
    key(Qt.Key_Question, Qt.AltModifier)
    compare(item("keyHelp:next blank").keys, "ctrl+tab", "a block takes Tab for itself")
    key(Qt.Key_Escape)
    tryVerify(function() { return item("codeBlank:1").activeFocus }, 3000)
    key(Qt.Key_Tab, Qt.ControlModifier)
    tryVerify(function() { return item("codeBlank:0").activeFocus }, 3000, "Ctrl+Tab wraps round to the first")
    verify(!study.code.blockFocused)
  }
}
