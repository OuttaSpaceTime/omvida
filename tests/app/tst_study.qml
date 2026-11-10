import QtQuick

// The study loop's keys and what each one writes to the deck. The fixture
// deck has three review cards due and one new card. The fake grader rates 3,
// or 1 for an answer containing "wrong", 4 for "perfect", fails for
// "failme", and takes two seconds over "slowly".
OmvidaTest {
  name: "study"

  // Every test starts with the whole deck due again and no session open: a
  // review pushes a card days out, and the next test would find nothing to do.
  function init() {
    if (study.phase !== "idle" && study.phase !== "done") study.endNow()
    sqlWrite("UPDATE Card SET due = '2020-01-01T00:00:00.000+00:00' WHERE suspended = 0")
  }

  function test_a_session_opens_on_a_card_with_the_answer_focused() {
    startSession()
    var field = item("answerField")
    tryVerify(function() { return field.activeFocus }, 3000, "the answer box has the keyboard")
    compare(item("statusMode").text, "STUDY")
    verify(/^1\/\d+$/.test(item("statusSegment:0").text), "position comes from the server: " + item("statusSegment:0").text)
    compare(item("statusSegment:1").text, "Web", "then the deck")
    type("abc")
    compare(field.text, "abc")
  }

  // A tag can name the answer, so the card shows none of them.
  function test_the_card_shows_no_tags() {
    startSession()
    verify(study.card.tags.length > 0, "the fixture card has tags to hide")
    var shown = []
    var walk = function(it) {
      if (!it || !it.visible) return
      if (typeof it.text === "string" && study.card.tags.some(function(t) { return it.text.indexOf("#" + t) !== -1 }))
        shown.push(it.text)
      for (let i = 0; i < it.children.length; i++) walk(it.children[i])
    }
    walk(studyView)
    compare(shown, [], "no tag on screen while answering")
  }

  function test_shift_enter_reveals_and_grades_then_shift_enter_submits_good() {
    startSession()
    var before = gradeCalls().length
    var cardId = study.card.id
    type("max-age is how long it stays fresh")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 8000)
    compare(gradeCalls().length, before + 1, "one grade call")
    verify(item("cardBack").visible, "the back is shown")
    tryVerify(function() { return item("suggestionLine").verdict === "claude: good" }, 3000)
    verify(item("suggestionLine").reason.indexOf("Fixture grader") === 0, "the reason is shown")
    compare(item("statusMode").text, "RATE")
    verify(item("rate:3").suggested, "the suggested keycap is marked")
    verify(!item("rate:1").suggested && !item("rate:2").suggested && !item("rate:4").suggested, "and only that one")
    // Each key says where it sends the card, from the deck server's preview.
    var label = function(n) { return findNamed(item("rate:" + n), "interval").text }
    for (let n = 1; n <= 4; n++)
      verify(/^(<1m|\d+m|\d+h|\d+d|[\d.]+mo|[\d.]+y)$/.test(label(n)), "rate:" + n + " shows an interval: " + label(n))
    verify(/m$/.test(label(1)), "again repeats within minutes: " + label(1))
    verify(/d$|mo$|y$/.test(label(4)), "easy waits days: " + label(4))
    verify(studyView.keyList.some(function(h) { return h.label === "take good" }), "the key list offers to take it")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.card && study.card.id !== cardId && study.phase === "answering" }, 8000, "next card")
    var r = reviews()
    compare(r[r.length - 1], [cardId, 3], "Good was written")
    compare(item("answerField").text, "", "the answer box is cleared")
  }

  function test_alt_enter_accepts_the_suggestion_even_before_it_arrives() {
    startSession()
    var cardId = study.card.id
    type("this is wrong")
    key(Qt.Key_Return, Qt.ShiftModifier)
    key(Qt.Key_Return, Qt.AltModifier)   // still grading: accepted on arrival
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000, "moved on")
    var r = reviews()
    compare(r[r.length - 1], [cardId, 1], "the suggested Again was written")
  }

  function test_alt_enter_while_answering_reveals_and_accepts() {
    startSession()
    var cardId = study.card.id
    type("a perfect answer")
    key(Qt.Key_Return, Qt.AltModifier)
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000, "moved on")
    var r = reviews()
    compare(r[r.length - 1], [cardId, 4])
  }

  // Shift+digit arrives as the shifted character; a German layout's Shift+3 is §.
  // The first press reveals and picks, never moves on: the back is seen
  // before the card goes. The same digit again rates.
  function test_shift_digit_reveals_and_picks_then_rates_on_the_second_press() {
    startSession()
    var before = gradeCalls().length
    var cardId = study.card.id
    var reviewed = reviews().length
    key(Qt.Key_section, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 3000)
    compare(study.picked, 3)
    compare(study.card.id, cardId, "still on the card")
    compare(reviews().length, reviewed, "nothing rated yet")
    compare(gradeCalls().length, before, "an empty answer is not graded")
    key(Qt.Key_section, Qt.ShiftModifier)
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000, "moved on")
    var r = reviews()
    compare(r[r.length - 1], [cardId, 3])
    compare(study.picked, 0, "the next card starts unpicked")
    compare(item("answerField").text, "", "no § typed into the next answer")
  }

  // Shift+Enter submits the pick; another digit changes it first.
  function test_shift_enter_submits_the_pick() {
    startSession()
    var cardId = study.card.id
    key(Qt.Key_Exclam, Qt.ShiftModifier)
    tryCompare(study, "picked", 1, 3000)
    key(Qt.Key_Dollar, Qt.ShiftModifier)
    compare(study.picked, 4, "a second digit changes the pick")
    compare(study.card.id, cardId)
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000)
    var r = reviews()
    compare(r[r.length - 1], [cardId, 4])
  }

  // Shift+Enter on a revealed card takes the suggestion, not a blanket Good.
  function test_shift_enter_takes_the_suggestion() {
    startSession()
    var cardId = study.card.id
    type("a perfect answer")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.suggestion !== null }, 8000)
    var suggested = study.suggestion.rating
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000)
    var r = reviews()
    compare(r[r.length - 1], [cardId, suggested], "the suggested rating")
  }

  function test_a_rating_overrides_the_suggestion() {
    startSession()
    var cardId = study.card.id
    type("a perfect answer")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.suggestion !== null }, 8000)
    rate(2)
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000)
    var r = reviews()
    compare(r[r.length - 1], [cardId, 2], "Hard, not the suggested Easy")
  }

  // A grade bills an API call, so typing alone grades nothing, however long
  // it pauses: the reveal grades once, the whole answer.
  function test_typing_grades_nothing_and_the_reveal_grades_once() {
    startSession()
    var before = gradeCalls().length
    type("an answer but wrong")
    // Past the old 1.2s typing pause, the one that used to grade.
    wait(1500)
    compare(gradeCalls().length, before, "nothing graded while typing")
    key(Qt.Key_Return, Qt.ShiftModifier)
    compare(study.phase, "grading")
    tryCompare(study, "phase", "revealed", 8000)
    compare(study.suggestion.rating, 1, "the verdict is for the whole answer")
    var calls = gradeCalls()
    compare(calls.length, before + 1, "one grade")
    verify(calls[before][0].indexOf("an answer but wrong") !== -1, "the whole answer was sent")
  }

  // A slow grade is waited for in the grading phase, then shown.
  function test_a_reveal_waits_for_a_slow_grade() {
    startSession()
    type("slowly")
    key(Qt.Key_Return, Qt.ShiftModifier)
    compare(study.phase, "grading")
    wait(1000)
    compare(study.phase, "grading", "still waiting")
    tryCompare(study, "phase", "revealed", 8000)
    compare(study.suggestion.rating, 3)
  }

  // A failed grade reveals the back with the error, and is not asked again.
  function test_a_failed_grade_reveals_with_the_error() {
    startSession()
    var before = gradeCalls().length
    type("failme")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 8000)
    verify(study.gradeError.indexOf("Fixture grader failed") !== -1, "the error: " + study.gradeError)
    compare(study.suggestion, null)
    wait(500)
    compare(gradeCalls().length, before + 1, "asked once")
  }

  // Only the empty-answer check trims: the grader gets the answer as typed, a code
  // answer's first indent included.
  function test_the_grader_gets_the_answer_as_typed() {
    startSession()
    type("    indented code")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 8000)
    var calls = gradeCalls()
    verify(calls[calls.length - 1][0].indexOf("<developer_answer>\n    indented code\n") !== -1, "indent kept")
  }

  // A card rated without waiting for Claude ends its grade (the deck server
  // aborts the request), and so does a session ended mid-grade.
  function test_rating_or_ending_aborts_the_grade_still_running() {
    startSession()
    var cardId = study.card.id
    type("slowly")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return gradeCalls().some(function(c) { return c[0].indexOf("slowly") !== -1 }) }, 5000, "a slow grade is running")
    study.submit(3)
    tryVerify(function() { return study.card && study.card.id !== cardId && study.phase === "answering" }, 8000)
    tryVerify(function() { return gradeAborts().length === 1 }, 3000, "the rated card's grade was aborted")
    type("slowly again")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return gradeCalls().some(function(c) { return c[0].indexOf("slowly again") !== -1 }) }, 5000, "another slow grade")
    study.endNow()
    tryCompare(study, "phase", "done", 3000)
    tryVerify(function() { return gradeAborts().length === 2 }, 3000, "ending the session aborted it")
  }

  // A rating is shown taken before the card goes: its keycap filled, the
  // others faded, then the card fades out and the next fades in. The review
  // is written at once; only the next card waits for the moment.
  function test_a_rating_is_shown_taken_then_the_next_card_fades_in() {
    startSession()
    var cardId = study.card.id
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 3000)
    key(Qt.Key_2, Qt.ShiftModifier)
    compare(study.chosen, 0, "the first press only picks")
    key(Qt.Key_2, Qt.ShiftModifier)
    compare(study.chosen, 2)
    verify(item("rate:2").chosen && !item("rate:3").chosen, "the chosen keycap is marked")
    compare(item("rate:2").opacity, 1, "and stays")
    tryVerify(function() { return item("rate:1").opacity === 0 && item("rate:3").opacity === 0 }, 1000, "the others fade")
    compare(study.card.id, cardId, "the card is still up while it shows")
    tryVerify(function() { return item("studyCard").opacity < 1 }, 2000, "the card fades out")
    tryVerify(function() { return study.card && study.card.id !== cardId && study.phase === "answering" }, 3000, "next card")
    compare(study.chosen, 0)
    var r = reviews()
    compare(r[r.length - 1], [cardId, 2], "Hard was written")
    tryCompare(item("studyCard"), "opacity", 1, 2000, "and it fades in")
  }

  // A pick from the answer reveals the back with its keycap marked, the
  // others still up beside it (the pick can change); nothing is taken yet.
  function test_a_pick_marks_its_keycap_and_keeps_the_others() {
    startSession()
    var cardId = study.card.id
    key(Qt.Key_4, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 3000)
    compare(study.picked, 4)
    compare(study.chosen, 0, "not taken")
    verify(item("rate:4").marked && !item("rate:4").chosen, "the picked keycap is marked")
    verify(!item("rate:2").marked)
    compare(item("rate:2").opacity, 1, "the others stay")
    key(Qt.Key_2, Qt.ShiftModifier)
    verify(item("rate:2").marked && !item("rate:4").marked, "the mark follows the pick")
    compare(study.card.id, cardId, "still on the card")
  }

  function test_an_empty_answer_reveals_without_grading() {
    startSession()
    var before = gradeCalls().length
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 3000)
    wait(500)
    compare(gradeCalls().length, before)
    verify(item("cardBack").visible)
  }

  function test_plain_enter_types_a_newline() {
    startSession()
    type("line one")
    key(Qt.Key_Return)
    type("line two")
    compare(study.phase, "answering")
    compare(item("answerField").text, "line one\nline two")
  }

  // Ctrl+Q hands the card to the study repo's /study-card-check, headless, and
  // the session goes on. Its report is drawn over the screen's bottom, so the
  // layout does not jump, and stays until dismissed. A second Ctrl+Q while it runs starts no second check.
  function test_ctrl_q_reports_in_the_slot_until_dismissed() {
    startSession()
    var id = study.card.id
    var screenHeight = studyView.height
    var before = cardCheckCalls().length
    compare(app.cardCheck.reports.length, 0, "nothing to show yet")
    key(Qt.Key_Q, Qt.ControlModifier)
    verify(item("checkSlot").visible, "shown while it runs")
    compare(item("checkHeadline:0").text, "Checking this card…")
    compare(study.phase, "answering", "the session goes on")
    key(Qt.Key_Q, Qt.ControlModifier)
    compare(item("toast").text, "This card is already being checked")
    tryVerify(function() { return item("checkHeadline:0").text === "Sound, no change" }, 8000)
    compare(item("checkText:0").text, "Fixture card " + id + " is sound.")
    var calls = cardCheckCalls().slice(before)
    compare(calls.length, 1, "one check")
    compare(calls[0][calls[0].indexOf("-p") + 1], "/study-card-check " + id)
    compare(app.cardCheck.count, 0, "none left running")
    wait(4200)
    verify(item("checkSlot").visible, "unlike a toast, it does not go away on its own")
    compare(studyView.height, screenHeight, "the screen keeps its room: the slot is drawn over it")
    verify(studyView.keyList.some(function(h) { return h.label === "dismiss the check" }), "its keys are in the key list")
    compare(app.checkCover, item("checkSlot").height, "the screens get scroll room past it")
    // Drawn after the screens, it would cover the key list's last rows.
    key(Qt.Key_Question, Qt.AltModifier | Qt.ShiftModifier)
    item("keyHelp:dismiss the check")
    verify(findNamed(target, "checkSlot") === null, "it steps aside for the key list")
    compare(app.checkCover, 0, "and gives back the scroll room")
    key(Qt.Key_Escape)
    tryVerify(function() { return findNamed(target, "checkSlot") !== null }, 2000, "and is back once it closes")
    click("checkDismiss:0")
    tryVerify(function() { return app.cardCheck.reports.length === 0 })
    compare(studyView.height, screenHeight, "nor does it jump on dismiss")
    verify(!studyView.keyList.some(function(h) { return h.label === "dismiss the check" }), "gone with it")
    compare(study.phase, "answering")
  }

  // A split reports what the card asked, what it carried beyond that and the
  // cards it became. Ctrl+Shift+D and Ctrl+Shift+Q act from the answer box, and
  // typing what was answered is not lost.
  function test_check_report_is_discussed_and_dismissed_by_key() {
    run(["touch", outDir + "/split-card-check"])
    startSession()
    type("half an answer")
    key(Qt.Key_Q, Qt.ControlModifier)
    tryVerify(function() { return item("checkHeadline:0").text === "Split into 2 cards" }, 8000)
    run(["rm", "-f", outDir + "/split-card-check"])
    compare(item("checkAsked:0").text, "Asked 2 things: what an ETag is; which header revalidates it")
    compare(item("checkExtra:0").text, "Beyond what it asked: a date nobody asked for")
    compare(item("checkCard:0:1").text, "→ Which header revalidates an ETag?")
    var kittyBefore = kittyCalls().length
    key(Qt.Key_D, Qt.ControlModifier | Qt.ShiftModifier)
    tryVerify(function() { return kittyCalls().length === kittyBefore + 1 }, 5000)
    var prompt = kittyCalls()[kittyBefore]
    prompt = prompt[prompt.length - 1]
    verify(prompt.indexOf("card quality check") !== -1)
    verify(prompt.indexOf("which header revalidates it") !== -1)
    verify(item("checkSlot").visible, "discussing does not dismiss it")
    key(Qt.Key_Q, Qt.ControlModifier | Qt.ShiftModifier)
    tryVerify(function() { return app.cardCheck.reports.length === 0 })
    compare(item("answerField").text, "half an answer")
  }

  function test_a_failed_check_says_why() {
    run(["touch", outDir + "/bad-card-check"])
    startSession()
    key(Qt.Key_Q, Qt.ControlModifier)
    tryVerify(function() { return item("checkHeadline:0").text === "The check failed" }, 8000)
    run(["rm", "-f", outDir + "/bad-card-check"])
    compare(item("checkText:0").text, "ran out of turns")
    click("checkDismiss:0")
    tryVerify(function() { return app.cardCheck.reports.length === 0 })
  }

  // At most Config.cardCheckLimit (2) checks run at once: a third Ctrl+Q,
  // on a third card, is refused until one is done.
  function test_card_checks_are_capped() {
    run(["touch", outDir + "/slow-card-check"])
    startSession()
    var seen = []
    for (let i = 0; i < 3; i++) {
      tryVerify(function() { return study.phase === "answering" && seen.indexOf(study.card.id) === -1 }, 8000, "a new card")
      seen.push(study.card.id)
      key(Qt.Key_Q, Qt.ControlModifier)
      if (i < 2) key(Qt.Key_S, Qt.ControlModifier)
    }
    compare(item("toast").text, "Card checks are busy: try again when one is done")
    compare(app.cardCheck.count, 2)
    run(["rm", "-f", outDir + "/slow-card-check"])
    tryVerify(function() { return app.cardCheck.count === 0 }, 10000, "both finish")
    while (app.cardCheck.reports.length > 0) app.dismissCheck(app.cardCheck.reports[0])
  }

  function test_discuss_opens_claude_in_kitty_with_the_card_and_answer() {
    startSession()
    type("my attempt")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.suggestion !== null }, 8000)
    var before = kittyCalls().length
    key(Qt.Key_D, Qt.ControlModifier)
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    var argv = kittyCalls()[before]
    var at = argv.indexOf("claude")
    var prompt = argv[at + 1]
    compare(argv[at + 2], "--mcp-config", "the flashcard tools load up front")
    verify(prompt.indexOf("Socratic mode") !== -1)
    verify(prompt.indexOf("My answer:\nmy attempt") !== -1)
    verify(prompt.indexOf("Suggested rating: Good (3)") !== -1)
    compare(study.phase, "revealed", "the card stays up to be rated")
  }

  // The key list's rows are buttons too: reveal, then a keycap.
  function test_a_click_on_reveal_then_on_a_keycap_rates() {
    startSession()
    var cardId = study.card.id
    type("a perfect answer")
    click("statusHint:keys")
    click("keyHelp:reveal")
    tryVerify(function() { return study.suggestion !== null }, 8000)
    verify(item("cardBack").visible)
    verify(item("rate:4").suggested)
    compare(item("answerField").activeFocus, true, "the answer box keeps the keyboard after a click")
    click("rate:2")
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000)
    var r = reviews()
    compare(r[r.length - 1], [cardId, 2])
  }

  function test_the_skip_hint_skips() {
    startSession()
    var before = reviews().length
    var cardId = study.card.id
    click("statusHint:keys")
    click("keyHelp:skip")
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000)
    compare(reviews().length, before)
  }

  function test_escape_ends_the_session_and_what_was_rated_counts() {
    startSession()
    var cardId = study.card.id
    rate(1)   // Again
    tryVerify(function() { return study.phase === "answering" && study.card.id !== cardId }, 8000)
    key(Qt.Key_Escape)
    tryCompare(study, "phase", "done", 3000)
    compare(item("statusMode").text, "DONE")
    var r = reviews()
    compare(r[r.length - 1], [cardId, 1], "the rating before Esc was written")
    var open = sql("SELECT COUNT(*) FROM StudySession WHERE endTime IS NULL AND cardsReviewed > 0")[0][0]
    compare(open, 0, "the session was closed")
  }

  // A reflex Esc with an answer typed keeps the answer and the session.
  function test_escape_with_a_typed_answer_keeps_it() {
    startSession()
    type("half an answer")
    key(Qt.Key_Escape)
    wait(300)
    compare(study.phase, "answering")
    compare(item("answerField").text, "half an answer")
  }

  // The Add menu never takes the keyboard, so Esc on Study closes it first.
  function test_escape_closes_the_add_menu_before_ending() {
    startSession()
    app.toggleAdd()
    verify(app.addMenuOpen)
    key(Qt.Key_Escape)
    tryVerify(function() { return !app.addMenuOpen }, 2000)
    compare(study.phase, "answering")
  }

  function scheduleOf(id) { return sql("SELECT due, reps, state, stability FROM Card WHERE id = '" + id + "'")[0] }
  function nextCardAfter(id) {
    tryVerify(function() { return study.card && study.card.id !== id && study.phase === "answering" }, 8000, "next card")
    var field = item("answerField")
    tryVerify(function() { return field.activeFocus }, 3000, "the answer box has the keyboard")
  }

  // Ctrl+Z from the next card: the rating is gone from the deck and the card is
  // back as it was rated, with no second grade to pay for.
  function test_ctrl_z_brings_the_card_back_as_it_was_rated() {
    startSession()
    var cardId = study.card.id
    var schedule = scheduleOf(cardId)
    var position = item("statusSegment:0").text
    var count = reviews().length
    type("a perfect answer")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.suggestion !== null }, 8000)
    var grades = gradeCalls().length
    rate(2)
    nextCardAfter(cardId)
    compare(reviews().length, count + 1)
    verify(JSON.stringify(scheduleOf(cardId)) !== JSON.stringify(schedule), "the rating moved the card")

    key(Qt.Key_Z, Qt.ControlModifier)
    tryCompare(study, "phase", "revealed", 8000)
    compare(study.card.id, cardId)
    compare(reviews().length, count, "the review is gone")
    compare(scheduleOf(cardId), schedule, "the card is scheduled as before")
    compare(item("statusSegment:0").text, position, "back at its place in the queue")
    compare(item("answerField").text, "a perfect answer")
    compare(study.suggestion.rating, 4, "Claude's verdict is back")
    verify(item("rate:4").suggested)
    compare(study.picked, 2, "the rating given is picked")
    verify(item("rate:2").marked)
    verify(item("cardBack").visible)
    tryCompare(item("studyCard"), "opacity", 1, 2000)
    tryVerify(function() { return item("answerField").activeFocus }, 3000)
    wait(300)
    compare(gradeCalls().length, grades, "not graded again")

    key(Qt.Key_4, Qt.ShiftModifier)
    compare(study.picked, 4, "another digit changes it")
    key(Qt.Key_4, Qt.ShiftModifier)
    nextCardAfter(cardId)
    var r = reviews()
    compare(r[r.length - 1], [cardId, 4], "and rates it")
    compare(reviews().length, count + 1)
  }

  // Several back, several forward, each key press one rating.
  function test_several_ratings_undo_and_redo() {
    startSession()
    var count = reviews().length
    var a = study.card.id
    rate(4)
    nextCardAfter(a)
    var b = study.card.id
    rate(3)
    nextCardAfter(b)
    var c = study.card.id
    compare(reviews().length, count + 2)

    key(Qt.Key_Z, Qt.ControlModifier)
    tryVerify(function() { return study.phase === "revealed" && study.card.id === b }, 8000)
    compare(study.picked, 3)
    key(Qt.Key_Z, Qt.ControlModifier)
    tryVerify(function() { return study.phase === "revealed" && study.card.id === a }, 8000)
    compare(study.picked, 4)
    compare(reviews().length, count)
    key(Qt.Key_Z, Qt.ControlModifier)
    compare(item("toast").text, "Nothing to undo")
    compare(study.card.id, a)

    key(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
    tryVerify(function() { return study.phase === "revealed" && study.card.id === b }, 8000, "redo goes to the next one undone")
    compare(study.picked, 3)
    key(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
    nextCardAfter(b)
    compare(study.card.id, c)
    var r = reviews()
    compare(r.slice(count), [[a, 4], [b, 3]], "the same ratings are written again")
    key(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
    compare(item("toast").text, "Nothing to redo")
  }

  // Quicker than the cards come: no press is lost.
  function test_quick_presses_wait_for_the_card() {
    startSession()
    var count = reviews().length
    var a = study.card.id
    rate(4)
    nextCardAfter(a)
    var b = study.card.id
    rate(4)
    compare(study.phase, "submitting")
    key(Qt.Key_Z, Qt.ControlModifier)
    key(Qt.Key_Z, Qt.ControlModifier)
    tryVerify(function() { return study.phase === "revealed" && study.card.id === a }, 8000)
    compare(reviews().length, count, "both undone")
    tryCompare(item("studyCard"), "opacity", 1, 2000, "the card is not left faded out")
    key(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
    key(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
    tryVerify(function() { return study.phase === "answering" && study.card.id !== a && study.card.id !== b }, 8000)
    compare(reviews().slice(count), [[a, 4], [b, 4]], "both given back")
  }

  // Another rating after an undo is a new history.
  function test_a_different_rating_drops_the_redos() {
    startSession()
    var a = study.card.id
    rate(4)
    nextCardAfter(a)
    key(Qt.Key_Z, Qt.ControlModifier)
    tryVerify(function() { return study.phase === "revealed" && study.card.id === a }, 8000)
    verify(study.canRedo)
    study.submit(2)
    nextCardAfter(a)
    verify(!study.canRedo)
    compare(study.undone, [])
  }

  // With an answer typed, Ctrl+Z is the box's.
  function test_ctrl_z_with_a_typed_answer_leaves_the_ratings_alone() {
    startSession()
    var a = study.card.id
    rate(4)
    nextCardAfter(a)
    var count = reviews().length
    var b = study.card.id
    verify(studyView.keyList.some(function(h) { return h.label === "undo rating" }), "listed while the box is empty")
    type("half")
    verify(!studyView.keyList.some(function(h) { return h.label === "undo rating" }), "not listed while typed")
    key(Qt.Key_Z, Qt.ControlModifier)
    wait(300)
    compare(study.card.id, b)
    compare(study.phase, "answering")
    compare(reviews().length, count)
  }

  // The slip most likely noticed is on the last card, on the summary: Ctrl+Z
  // reopens the session, and no log entry is written for what it takes back.
  function test_ctrl_z_on_the_summary_reopens_the_session() {
    startSession()
    var a = study.card.id
    rate(4)
    nextCardAfter(a)
    var count = reviews().length
    key(Qt.Key_Escape)
    tryCompare(study, "phase", "done", 3000)
    verify(study.logPending)
    verify(studyView.keyList.some(function(h) { return h.label === "undo rating" }), "listed on the summary")
    tryVerify(function() { return studyView.takeFocus() }, 1000)

    key(Qt.Key_Z, Qt.ControlModifier)
    tryVerify(function() { return study.phase === "revealed" && study.card.id === a }, 8000)
    compare(study.logPending, false, "nothing logged for it")
    compare(reviews().length, count - 1)
    tryCompare(item("studyCard"), "opacity", 1, 2000, "the card shows")
    tryVerify(function() { return item("answerField").activeFocus }, 3000, "and has the keyboard")
    compare(sql("SELECT endTime FROM StudySession WHERE id = '" + study.sessionId + "'")[0][0], null, "open again")

    key(Qt.Key_4, Qt.ShiftModifier)
    compare(study.picked, 4)
    key(Qt.Key_Return, Qt.ShiftModifier)
    nextCardAfter(a)
    key(Qt.Key_Escape)
    tryCompare(study, "phase", "done", 3000)
    verify(study.logPending, "ended again, it logs")
    var r = reviews()
    compare(r[r.length - 1], [a, 4])
  }

  // Once the summary's entry is in the log, the ratings stand.
  function test_no_undo_once_the_log_is_written() {
    startSession()
    var a = study.card.id
    rate(4)
    nextCardAfter(a)
    var count = reviews().length
    key(Qt.Key_Escape)
    tryCompare(study, "phase", "done", 3000)
    study.writeLog()
    verify(!study.canUndo)
    study.undo()
    compare(item("toast").text, "Nothing to undo")
    compare(study.phase, "done")
    compare(reviews().length, count)
  }

  function test_the_key_list_offers_undo_and_redo() {
    startSession()
    var row = function(label) { return studyView.keyList.filter(function(h) { return h.label === label })[0] }
    var clickable = function(label) { return typeof row(label).run === "function" }
    // Listed from the first card on, so they can be found before they are needed.
    verify(row("undo rating") && row("redo rating"), "on the first card")
    verify(!clickable("undo rating") && !clickable("redo rating"), "as a legend: nothing to take back yet")
    var a = study.card.id
    rate(4)
    nextCardAfter(a)
    verify(clickable("undo rating"))
    verify(!clickable("redo rating"))
    click("statusHint:keys")
    click("keyHelp:undo rating")
    tryVerify(function() { return study.phase === "revealed" && study.card.id === a }, 8000)
    verify(clickable("redo rating"))
    verify(!clickable("undo rating"), "that was the only one")
    click("statusHint:keys")
    click("keyHelp:redo rating")
    nextCardAfter(a)
    var r = reviews()
    compare(r[r.length - 1], [a, 4])
  }

  // A failed Anki sync is an alert on the status line, its message on hover.
  function test_a_sync_failure_shows_on_the_status_line() {
    startSession()
    study.syncNote = "Anki sync failed: offline"
    var alerts = []
    for (let i = 0; findNamed(target, "statusAlert:" + i) !== null; i++) alerts.push(findNamed(target, "statusAlert:" + i).text)
    verify(alerts.indexOf("sync ✕") !== -1, "alerts: " + JSON.stringify(alerts))
  }

  // The fixture study has no scripts/ at all (the sync counts as skipped);
  // these put a fake anki-sync there for one session start and take it away.
  function withFakeSync(script, fn) {
    var path = studyDir + "/scripts/anki-sync"
    compare(run(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && chmod +x \"$1\"", "sh", path, script]).code, 0, "fake written")
    try { fn() } finally { run(["rm", "-f", "--", path]) }
  }

  // bin/sandbox resolves its directory, so studyDir is what pwd -P prints.
  function test_anki_sync_runs_in_the_study_repo() {
    withFakeSync("#!/bin/sh\necho \"sync: done (ran in $(pwd -P))\"\n", function() {
      startSession()
      compare(study.syncNote, "Anki sync: ran in " + studyDir)
    })
  }

  // A crash's reason is the traceback's last line, on stderr, not the plan
  // stdout printed before it.
  function test_a_crashed_anki_sync_says_why() {
    withFakeSync("#!/bin/sh\necho 'plan: create 1'\nprintf 'Traceback (most recent call last):\\n  File \"x\"\\nModuleNotFoundError: No module named fastanki\\n' >&2\nexit 1\n", function() {
      startSession()
      compare(study.syncNote, "Anki sync failed: ModuleNotFoundError: No module named fastanki")
    })
  }

  function test_skip_leaves_the_card_unreviewed() {
    startSession()
    var before = reviews().length
    var cardId = study.card.id
    key(Qt.Key_S, Qt.ControlModifier)
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000)
    compare(reviews().length, before)
  }

  function test_z_a_finished_session_logs_offers_pages_and_closes() {
    startSession()
    // Rate every card Good until the queue is empty (a new card repeats once).
    for (let i = 0; i < 12 && study.phase !== "done"; i++) {
      tryVerify(function() { return study.phase === "answering" || study.phase === "done" }, 8000)
      if (study.phase === "done") break
      rate(3)   // Good
      tryVerify(function() { return study.phase !== "submitting" && study.phase !== "loading" }, 8000)
    }
    tryCompare(study, "phase", "done", 8000)
    verify(item("summaryLine").text.indexOf("card") !== -1)
    tryVerify(function() { return study.related.length > 0 }, 5000, "related pages offered")
    // Opening one writes the log, with the page in it.
    var rel = study.related[0].path
    click("related:" + rel)
    tryCompare(app.nav, "currentScreen", "wiki")
    var d = new Date()
    var m = d.getMonth() + 1
    var day = d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate()
    var path = studyDir + "/logs/" + (m < 10 ? "0" : "") + m + "/" + day + ".md"
    tryVerify(function() { var t = readFile(path); return t !== null && t.indexOf("— Study (") !== -1 }, 5000, "log written to " + path)
    var log = readFile(path)
    verify(log.indexOf("# " + day) === 0, "a new day's file starts with its header")
    verify(log.indexOf("- **Lapses:** none") !== -1, "all Good, no lapses")
    verify(log.indexOf("[[" + rel + "]]") !== -1, "the opened page is in Wiki explored")
    verify(log.indexOf("- **Surface:** Omvida app") !== -1)
    var open = sql("SELECT COUNT(*) FROM StudySession WHERE endTime IS NULL AND cardsReviewed > 0")[0][0]
    compare(open, 0, "every session that reviewed something was closed")
  }

  // The status line names one key; Alt+? lists the rest, and Esc closes the
  // list without ending the session or touching the answer.
  function test_alt_question_lists_the_keys_and_esc_closes_it() {
    startSession()
    var hints = item("statusLine").hints.map(function(h) { return h.keys })
    compare(hints, ["alt+?"])
    type("half")
    key(Qt.Key_Question, Qt.AltModifier | Qt.ShiftModifier)
    item("keyHelp:reveal")
    item("keyHelp:discuss")
    key(Qt.Key_Escape)
    tryVerify(function() { return findNamed(target, "keyHelp:reveal") === null }, 2000, "closed")
    compare(study.phase, "answering")
    var field = item("answerField")
    tryVerify(function() { return field.activeFocus }, 2000, "the answer box has the keyboard back")
    compare(field.text, "half")
  }
}
