import QtQuick

// A card at five or more lapses: the server flags it when served, and the
// next card is blocked until it is dealt with (flashcard-mcp leeches.ts).
OmvidaTest {
  name: "leech"

  // The CSRF card has lapsed 6 times and is the only card due, so it is
  // served first. The deck server reads the database on every call, so a
  // change here is seen by the next session.
  function test_a_leech_blocks_until_kept() {
    sqlWrite("UPDATE Card SET lapses = 6 WHERE id = 'fixturecard0003'")
    sqlWrite("UPDATE Card SET due = '2099-01-01T00:00:00.000+00:00' WHERE id != 'fixturecard0003'")
    startSession()
    compare(study.card.id, "fixturecard0003")
    verify(study.next.leech !== null && study.next.leech !== undefined, "served with the leech flag")
    key(Qt.Key_NumberSign, Qt.ShiftModifier)
    tryCompare(study, "phase", "blocked", 8000)
    verify(item("leechRewrite").visible)

    // Rewrite opens Claude Code with the card; the block stays until resolved.
    var before = kittyCalls().length
    click("leechRewrite")
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    var prompt = kittyCalls()[before].slice(-1)[0]
    verify(prompt.indexOf("leech: 6 lapses") !== -1)
    verify(prompt.indexOf("update_card") !== -1)
    click("leechContinue")
    tryCompare(study, "phase", "blocked", 8000)

    click("leechKeep")
    tryVerify(function() { return study.phase === "done" || study.phase === "answering" }, 8000)
    compare(sql("SELECT leechDeferredLapses FROM Card WHERE id = 'fixturecard0003'")[0][0], 6, "kept at 6 lapses")
  }

  // Enter continues and Esc ends while a leech blocks (no answer box then:
  // the screen's key catcher has the keyboard).
  function test_b_enter_continues_and_esc_ends_a_blocked_session() {
    sqlWrite("UPDATE Card SET lapses = 6, leechDeferredLapses = 0, due = '2020-01-01T00:00:00.000+00:00' WHERE id = 'fixturecard0003'")
    sqlWrite("UPDATE Card SET due = '2099-01-01T00:00:00.000+00:00' WHERE id != 'fixturecard0003'")
    // After the first test the server may block the card at once, before
    // serving it; either way, one rating at most gets to the block.
    app.setScreen("study")
    study.start()
    tryVerify(function() { return study.phase === "answering" || study.phase === "blocked" }, 15000)
    if (study.phase === "answering") {
      tryVerify(function() { return item("answerField").activeFocus }, 3000)
      key(Qt.Key_NumberSign, Qt.ShiftModifier)
    }
    tryCompare(study, "phase", "blocked", 8000)
    compare(item("statusMode").text, "LEECH")
    wait(100)
    // Enter asks the server again (loading), which blocks again.
    var seen = []
    var note = function() { seen.push(study.phase) }
    study.phaseChanged.connect(note)
    key(Qt.Key_Return)
    tryVerify(function() { return seen.indexOf("loading") !== -1 }, 3000, "Enter continued")
    tryCompare(study, "phase", "blocked", 8000)
    study.phaseChanged.disconnect(note)
    wait(100)
    key(Qt.Key_Escape)
    tryCompare(study, "phase", "done", 3000)
  }
}
