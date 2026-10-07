import QtQuick

// The study loop's keys and what each one writes to the deck. The fixture
// deck has three review cards due and one new card. The fake grader rates 3,
// or 1 for an answer containing "wrong", 4 for "perfect", and flags a card
// issue for "flagme".
OmvidaTest {
  name: "study"

  function reviews() { return sql("SELECT cardId, rating FROM Review WHERE id NOT LIKE 'fixturereview%' ORDER BY reviewedAt")[0] ? sql("SELECT cardId, rating FROM Review WHERE id NOT LIKE 'fixturereview%' ORDER BY reviewedAt") : [] }

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
    verify(findNamed(target, "statusHint:take good") !== null, "the status line offers to take it")
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
    verify(item("lastResult").visible, "the previous card's line shows")
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
  function test_shift_digits_rate_without_typing_or_grading() {
    startSession()
    var before = gradeCalls().length
    var cardId = study.card.id
    key(Qt.Key_section, Qt.ShiftModifier)
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000, "moved on")
    var r = reviews()
    compare(r[r.length - 1], [cardId, 3])
    compare(gradeCalls().length, before, "nothing was graded")
    compare(item("answerField").text, "", "no § typed into the next answer")
  }

  function test_a_rating_overrides_the_suggestion() {
    startSession()
    var cardId = study.card.id
    type("a perfect answer")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.suggestion !== null }, 8000)
    key(Qt.Key_At, Qt.ShiftModifier)    // Shift+2 on a US layout
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000)
    var r = reviews()
    compare(r[r.length - 1], [cardId, 2], "Hard, not the suggested Easy")
    verify(item("lastResult").children[1].text.indexOf("(your call)") !== -1, "marked as overridden")
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

  function test_a_flagged_card_offers_a_fix_in_claude() {
    startSession()
    type("flagme")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.suggestion !== null && study.suggestion.quality !== null }, 8000)
    var before = kittyCalls().length
    click("fixCardButton")
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    var argv = kittyCalls()[before]
    compare(argv.slice(0, 2), ["--directory", studyDir])
    verify(argv[argv.length - 1].indexOf("two questions") !== -1, "the issue goes along")
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
    compare(argv[argv.length - 2], "claude")
    var prompt = argv[argv.length - 1]
    verify(prompt.indexOf("Socratic mode") !== -1)
    verify(prompt.indexOf("My answer:\nmy attempt") !== -1)
    verify(prompt.indexOf("Suggested rating: Good (3)") !== -1)
    compare(study.phase, "revealed", "the card stays up to be rated")
  }

  // The status line's hints are buttons too: reveal, then a keycap.
  function test_a_click_on_reveal_then_on_a_keycap_rates() {
    startSession()
    var cardId = study.card.id
    type("a perfect answer")
    click("statusHint:reveal")
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
    click("statusHint:skip")
    tryVerify(function() { return study.card && study.card.id !== cardId }, 8000)
    compare(reviews().length, before)
  }

  function test_escape_ends_the_session_and_what_was_rated_counts() {
    startSession()
    var cardId = study.card.id
    key(Qt.Key_Exclam, Qt.ShiftModifier)   // Shift+1: Again
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

  // A failed Anki sync is an alert on the status line, its message on hover.
  function test_a_sync_failure_shows_on_the_status_line() {
    startSession()
    study.syncNote = "Anki sync failed: offline"
    var alerts = []
    for (var i = 0; findNamed(target, "statusAlert:" + i) !== null; i++) alerts.push(findNamed(target, "statusAlert:" + i).text)
    verify(alerts.indexOf("sync ✕") !== -1, "alerts: " + JSON.stringify(alerts))
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
    for (var i = 0; i < 12 && study.phase !== "done"; i++) {
      tryVerify(function() { return study.phase === "answering" || study.phase === "done" }, 8000)
      if (study.phase === "done") break
      key(Qt.Key_NumberSign, Qt.ShiftModifier)   // Shift+3: Good
      tryVerify(function() { return study.phase !== "submitting" && study.phase !== "loading" }, 8000)
    }
    tryCompare(study, "phase", "done", 8000)
    verify(item("summaryLine").text.indexOf("card") !== -1)
    tryVerify(function() { return study.related.length > 0 }, 5000, "related pages offered")
    // Opening one writes the log, with the page in it.
    var rel = study.related[0].path
    click("related:" + rel)
    tryCompare(app, "currentScreen", "wiki")
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
}
