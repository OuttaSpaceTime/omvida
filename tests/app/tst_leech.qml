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
    rate(3)
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

  // The rating that led to the block can be taken back from it: the leech,
  // flagged when it was served, must not block its own card. It is flagged
  // again as it comes back.
  function test_a_rating_can_be_undone_from_the_block() {
    // Flagged by the test before, the session would open blocked, unrated.
    sqlWrite("UPDATE Card SET leechFlaggedAt = NULL WHERE id = 'fixturecard0003'")
    blockOnLeech("fixturecard0003")
    verify(study.canUndo, "blocked by the rating just given")
    var count = sql("SELECT COUNT(*) FROM Review WHERE cardId = 'fixturecard0003'")[0][0]
    wait(100)
    key(Qt.Key_Z, Qt.ControlModifier)
    tryCompare(study, "phase", "revealed", 8000)
    compare(study.card.id, "fixturecard0003")
    compare(study.blocked, null)
    verify(study.next.leech !== null && study.next.leech !== undefined, "still told it is a leech")
    compare(sql("SELECT COUNT(*) FROM Review WHERE cardId = 'fixturecard0003'")[0][0], count - 1, "the review is gone")
    tryVerify(function() { return item("answerField").activeFocus }, 3000, "the keyboard is back on the card")
    key(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
    tryCompare(study, "phase", "blocked", 8000)
    study.endNow()
    tryCompare(study, "phase", "done", 3000)
    sqlWrite("UPDATE Card SET leechFlaggedAt = NULL, lapses = 0 WHERE id = 'fixturecard0003'")
  }

  // Enter continues and Esc ends while a leech blocks (no answer box then:
  // the screen's key catcher has the keyboard).
  function test_b_enter_continues_and_esc_ends_a_blocked_session() {
    blockOnLeech("fixturecard0003")
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
