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
}
