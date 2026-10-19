import QtQuick

// A card changed behind the session's back, as Claude Code does when it fixes
// one from Discuss, Fix card or a leech: the deck poll (Store.checkDeck)
// notices, and the session catches up (StudySession.catchUp). The changes
// are written straight to the fixture deck, as another process would, with
// updatedAt set to now, as Prisma's @updatedAt does, so the deck's stamp
// moves even when the card count does not.
OmvidaTest {
  name: "catchup"

  // The whole deck due again.
  function init() {
    if (study.phase !== "idle" && study.phase !== "done") study.endNow()
    sqlWrite("UPDATE Card SET due = '2020-01-01T00:00:00.000+00:00' WHERE suspended = 0")
  }

  // Now, as flashcard-mcp writes it (ISO text, +00:00).
  readonly property string sqlNow: "strftime('%Y-%m-%dT%H:%M:%f+00:00', 'now')"

  function test_a_a_rewritten_card_replaces_the_shown_one_and_drops_the_suggestion() {
    startSession()
    var id = study.card.id
    type("an answer")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryCompare(study, "phase", "revealed", 8000)
    tryVerify(function() { return study.suggestion !== null }, 3000, "graded")

    sqlWrite("UPDATE Card SET back = 'Rewritten in Claude Code', updatedAt = " + sqlNow + " WHERE id = '" + id + "'")
    tryVerify(function() { return study.card.back === "Rewritten in Claude Code" }, 10000, "the new back is shown")
    compare(study.card.id, id, "the same card")
    compare(study.phase, "revealed", "the back stays shown")
    compare(study.suggestion, null, "the old suggestion is gone")
    compare(study.answer, "an answer", "the answer is kept")

    study.submit(3)
    tryVerify(function() { return study.phase === "answering" || study.phase === "done" }, 8000)
    compare(sql("SELECT rating FROM Review WHERE cardId = '" + id + "' AND id NOT LIKE 'fixturereview%'").length, 1, "rated once")
  }

  function test_b_a_rewritten_front_shows_while_answering() {
    startSession()
    var id = study.card.id
    sqlWrite("UPDATE Card SET front = 'A sharper front', updatedAt = " + sqlNow + " WHERE id = '" + id + "'")
    tryVerify(function() { return study.card.front === "A sharper front" }, 10000, "the new front is shown")
    compare(study.phase, "answering")
    compare(gradeCalls().filter(function(a) { return a.join(" ").indexOf("A sharper front") !== -1 }).length, 0, "nothing graded")
  }

  // An answer typed before the card changed is graded against the new card,
  // with no more typing.
  function test_b_an_answer_typed_before_an_edit_is_graded_again() {
    startSession()
    var id = study.card.id
    type("an answer")
    tryVerify(function() { return study.early && study.early.done }, 5000, "graded on the pause")
    var before = gradeCalls().length
    sqlWrite("UPDATE Card SET back = 'A new back', updatedAt = " + sqlNow + " WHERE id = '" + id + "'")
    tryVerify(function() { return study.card.back === "A new back" }, 10000, "the new back is in")
    tryVerify(function() { return gradeCalls().length === before + 1 }, 5000, "graded again")
    verify(gradeCalls()[before][0].indexOf("A new back") !== -1, "against the new back")
  }

  // A split deletes the original (its parts inherit its schedule, so they
  // are not this session's): the session goes on to the next card.
  function test_c_a_card_deleted_mid_card_moves_the_session_on() {
    startSession()
    var id = study.card.id
    sqlWrite("DELETE FROM Review WHERE cardId = '" + id + "'")
    sqlWrite("DELETE FROM Card WHERE id = '" + id + "'")
    tryVerify(function() { return study.phase === "done" || (study.card && study.card.id !== id) }, 10000, "moved past the deleted card")
  }

  // A leech rewritten through update_card has its lapses reset and its flag
  // cleared (flashcard-mcp leechResolutionFor): the block lifts without
  // pressing Continue.
  function test_d_a_rewritten_leech_lifts_the_block() {
    blockOnLeech("fixturecard0003")

    sqlWrite("UPDATE Card SET front = 'A grounded scenario', lapses = 0, leechFlaggedAt = NULL, "
             + "updatedAt = " + sqlNow + " WHERE id = 'fixturecard0003'")
    tryVerify(function() { return study.phase === "answering" || study.phase === "done" }, 10000, "the block lifted: " + study.phase)
  }

  function test_e_the_bar_gets_the_overview_after_a_rating() {
    startSession()
    var shown = JSON.stringify(app.store.overview)
    study.submit(3)
    tryVerify(function() {
      var sent = barOverviews(), last = JSON.stringify(sent[sent.length - 1])
      return last !== shown && last === JSON.stringify(app.store.overview)
    }, 8000, "the bar got the new overview")
  }

  // A rating moves the deck server's reviews stamp, not its cards': mid-
  // session it reloads the overview (the due count, the bar) and not the
  // whole deck, whose scheduling is reloaded when the session ends.
  function test_f_a_rating_reloads_the_overview_not_the_cards() {
    startSession()
    var id = study.card.id
    var cards = app.store.allCards, overview = app.store.overview
    study.submit(1)
    tryVerify(function() { return app.store.overview !== overview }, 8000, "the overview was reloaded")
    wait(2500)   // past Theme.deckPollInterval
    verify(app.store.allCards === cards, "the cards were not")
    verify(app.store.scheduleStale, "and are known to be behind")
    study.endNow()
    tryVerify(function() { return app.store.allCards !== cards }, 8000, "reloaded once the session ended")
    verify(!app.store.scheduleStale)
    compare(app.store.cardsById[id].lapses, cards.find(function(c) { return c.id === id }).lapses + 1, "with the lapse")
  }

  // The study repo's hook (bin/omvida-deck-changed) calls the deckChanged IPC
  // the moment a card is saved. With the poll stopped, as with the window in
  // the background, only that call can bring the edit in. Last in the file:
  // it unbinds the store's `active`.
  function test_z_the_deckChanged_ipc_brings_an_edit_in_without_the_poll() {
    startSession()
    var id = study.card.id
    app.store.active = false
    sqlWrite("UPDATE Card SET back = 'Pushed by the hook', updatedAt = " + sqlNow + " WHERE id = '" + id + "'")
    wait(2500)   // past Theme.deckPollInterval
    verify(study.card.back !== "Pushed by the hook", "no poll in the background")
    app.ipc.deckChanged()
    tryVerify(function() { return study.card.back === "Pushed by the hook" }, 3000, "the IPC call reloaded the deck")
  }
}
