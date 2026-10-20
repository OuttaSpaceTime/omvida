import QtQuick

// Card notes: Ctrl+N notes the card in Study and the session goes on; the
// note is kept in the deck (flashcard-mcp's CardNote) and shows on Cards
// (the "noted" filter, "fix it", the stage) and on Home (past sessions,
// "fix all"), which hand the noted cards to one Claude Code session. Also
// the pages a finished session points to, kept in the wiki's side panel,
// and that panel's drag edge. A file of its own: it writes notes and
// sessions to the deck.
OmvidaTest {
  name: "notes"

  function notes() { return sql("SELECT cardId, body FROM CardNote ORDER BY createdAt") }

  function init() {
    if (app.noteOpen) item("noteDialog").close()
    if (study.phase !== "idle" && study.phase !== "done") study.endNow()
    sqlWrite("DELETE FROM CardNote")
    sqlWrite("UPDATE Card SET due = '2020-01-01T00:00:00.000+00:00' WHERE suspended = 0")
    app.store.refreshDeck()
    tryCompare(app.store, "noteCount", 0, 5000)
  }

  // Ctrl+N over a typed answer: the dialog takes the keyboard, Esc in it
  // does not end the session, and saving goes back to the answer as it was.
  function test_ctrl_n_notes_the_card_and_the_session_goes_on() {
    startSession()
    var cardId = study.card.id
    type("half an answer")
    key(Qt.Key_N, Qt.ControlModifier)
    tryVerify(function() { return app.noteOpen }, 3000, "the note dialog opens")
    verify(!app.addMenuOpen, "not the window's Add")
    var editor = item("noteEditor")
    tryVerify(function() { return editor.activeFocus }, 3000)
    // The window's keys stay quiet over a dialog.
    key(Qt.Key_N, Qt.ControlModifier)
    key(Qt.Key_1, Qt.ControlModifier)
    verify(!app.addMenuOpen && app.currentScreen === "study", "no Add, no screen change")
    key(Qt.Key_Escape)
    tryVerify(function() { return !app.noteOpen }, 2000)
    compare(study.phase, "answering", "Esc closed the dialog, not the session")
    compare(notes().length, 0, "nothing saved")

    key(Qt.Key_N, Qt.ControlModifier)
    tryVerify(function() { return app.noteOpen }, 3000)
    tryVerify(function() { return editor.activeFocus }, 3000)
    type("Split it:\n- one\n")
    compare(editor.text, "Split it:\n- one\n- ", "Enter carries the list on")
    type("two")
    key(Qt.Key_Return, Qt.ControlModifier)
    tryVerify(function() { return !app.noteOpen }, 5000, "Ctrl+Enter saves and closes")
    tryVerify(function() { return notes().length === 1 }, 5000)
    compare(notes()[0], [cardId, "Split it:\n- one\n- two"])
    compare(study.card.id, cardId, "the same card is still up")
    tryVerify(function() { return item("answerField").activeFocus }, 3000, "the keyboard is back in the answer")
    compare(item("answerField").text, "half an answer", "with what was typed")
    tryVerify(function() { return studyView.statusSegments.some(function(s) { return s.text === "noted" }) }, 5000, "the status line says noted")

    // Noting it again opens the note; deleting it there deletes it.
    key(Qt.Key_N, Qt.ControlModifier)
    tryVerify(function() { return app.noteOpen }, 3000)
    compare(editor.text, "Split it:\n- one\n- two")
    click("noteDelete")
    tryVerify(function() { return notes().length === 0 }, 5000)
  }

  // A card the grader flagged starts its note with the flag, so "fix in
  // claude" can wait for the fix session.
  function test_a_flagged_card_starts_its_note_with_the_flag() {
    startSession()
    type("flagme")
    key(Qt.Key_Return, Qt.ShiftModifier)
    tryVerify(function() { return study.suggestion !== null && study.suggestion.quality !== null }, 8000)
    key(Qt.Key_N, Qt.ControlModifier)
    tryVerify(function() { return app.noteOpen }, 3000)
    verify(item("noteEditor").text.indexOf("> card issue, ") === 0, item("noteEditor").text)
    verify(item("notePreview").visible, "the markdown is previewed")
  }

  // The summary counts the noted cards and fixes them; its related pages
  // stay in the wiki's side panel once one is open.
  function test_z_the_summary_offers_the_fix_and_keeps_its_pages_in_the_wiki() {
    app.clearStudyPages()
    startSession()
    var noted = study.card.id
    key(Qt.Key_N, Qt.ControlModifier)
    tryVerify(function() { return app.noteOpen }, 3000)
    tryVerify(function() { return item("noteEditor").activeFocus }, 3000)
    type("Why 60?")
    key(Qt.Key_Return, Qt.ControlModifier)
    tryVerify(function() { return !app.noteOpen }, 5000)
    for (let i = 0; i < 12 && study.phase !== "done"; i++) {
      tryVerify(function() { return study.phase === "answering" || study.phase === "done" }, 8000)
      if (study.phase === "done") break
      if (i === 1) {
        // A note deleted again is no longer one of the session's.
        key(Qt.Key_N, Qt.ControlModifier)
        tryVerify(function() { return app.noteOpen && item("noteEditor").activeFocus }, 3000)
        type("never mind")
        key(Qt.Key_Return, Qt.ControlModifier)
        tryVerify(function() { return !app.noteOpen && app.store.noteCount === 2 }, 5000)
        key(Qt.Key_N, Qt.ControlModifier)
        tryVerify(function() { return app.noteOpen && item("noteDelete").visible }, 3000)
        click("noteDelete")
        tryVerify(function() { return !app.noteOpen && app.store.noteCount === 1 }, 5000)
        tryVerify(function() { return item("answerField").activeFocus }, 3000)
      }
      rate(3)
      tryVerify(function() { return study.phase !== "submitting" && study.phase !== "loading" }, 8000)
    }
    tryCompare(study, "phase", "done", 8000)
    tryVerify(function() { return study.noted.length === 1 }, 5000, "the deck server's count: " + JSON.stringify(study.noted))
    compare(item("summaryNoted").text, "Noted 1 card")
    var before = kittyCalls().length
    click("summaryFixNotes")
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    compare(kittyCalls()[before].slice(-1)[0], "/study-fix-notes " + noted)

    tryVerify(function() { return study.related.length > 0 }, 5000)
    var pages = study.related.map(function(p) { return p.path })
    compare(app.studyPages.map(function(p) { return p.path }), pages)
    click("related:" + pages[0])
    tryCompare(app, "currentScreen", "wiki")
    // Every page from the session is listed, the open one marked; a click
    // goes from one to the next.
    pages.forEach(function(p) { item("studyPage:" + p) })
    if (pages.length > 1) {
      click("studyPage:" + pages[1])
      tryCompare(app, "wikiPath", pages[1])
      item("studyPage:" + pages[0])
    }
    click("studyPageDrop:" + pages[0])
    tryVerify(function() { return app.studyPages.length === pages.length - 1 }, 2000)
    if (pages.length > 1) {
      click("studyPagesClear")
      tryCompare(app.studyPages, "length", 0)
    }
    tryVerify(function() { return findNamed(target, "studyPages") === null }, 2000, "the section goes when empty")
  }

  // Cards: the "noted" filter, the stage's note, N to note, and "fix it",
  // which sends only the noted cards the filters leave.
  function test_cards_filter_the_noted_and_fix_them() {
    app.store.saveNote("fixturecard0002", "**Reword** the front", null)
    app.store.saveNote("fixturecard0004", "What is a scheme?", null)
    tryCompare(app.store, "noteCount", 2, 5000)
    app.setScreen("cards")
    var cards = cardsScreen
    click("notedChip")
    tryVerify(function() { return cards.filtered.length === 2 }, 3000)
    item("selected:noted:yes")
    tryVerify(function() { return item("stageNote").text.length > 0 }, 3000)
    compare(item("stageNote").text, "note: " + (cards.filtered[0].id === "fixturecard0002" ? "Reword the front" : "What is a scheme?"))

    var before = kittyCalls().length
    click("fixNoted")
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    var prompt = kittyCalls()[before].slice(-1)[0]
    verify(prompt.indexOf("/study-fix-notes ") === 0, prompt)
    verify(prompt.indexOf("fixturecard0002") !== -1 && prompt.indexOf("fixturecard0004") !== -1, "both noted cards")
    verify(prompt.indexOf("fixturecard0001") === -1, "and no other")

    // N on the stage opens the card's note.
    cards.takeFocus()
    key(Qt.Key_N)
    tryVerify(function() { return app.noteOpen }, 3000)
    item("noteDialog").close()

    // A resolved note (Claude Code's resolve_card_note) leaves the filter.
    sqlWrite("DELETE FROM CardNote WHERE cardId = 'fixturecard0004'")
    app.store.checkDeck()
    tryVerify(function() { return cards.filtered.length === 1 }, 5000)
    click("selected:noted:yes")
    tryVerify(function() { return !cards.filters.noted }, 2000)
  }

  // Home: the past sessions with what they lapsed and noted, and "fix all"
  // with every note.
  function test_home_lists_past_sessions_and_fixes_all() {
    compare(run(["python3", repo + "/tests/fixtures/seed_deck.py", deckDb, "--notes"]).code, 0, "seeded")
    app.store.refreshDeck()
    app.setScreen("home")
    tryVerify(function() { return app.store.sessions.some(function(s) { return s.id === "fixturesession" }) }, 5000)
    item("flaw:lapsed:fixturecard0003")
    item("flaw:noted:fixturecard0001")
    compare(item("homeFixAll").label, "fix all · 2 notes")
    var before = kittyCalls().length
    click("homeFixAll")
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    compare(kittyCalls()[before].slice(-1)[0], "/study-fix-notes", "every open note")
    click("flaw:noted:fixturecard0001")
    tryVerify(function() { return app.noteOpen }, 3000, "a noted card opens its note")
    compare(item("noteEditor").text, "**Reword**: say what the 60 counts from")
  }

  // The wiki's left panel drags wider by its right edge, and no further
  // than leaves the page its column.
  function test_the_side_panel_is_resizable() {
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.loadedPath === "web/http-caching" }, 8000)
    wiki.sideOpen = true
    var handle = item("sidePanelHandle")
    var panel = handle.parent
    var before = panel.width
    mouseDrag(handle, handle.width / 2, handle.height / 2, 80, 0)
    tryVerify(function() { return panel.width > before }, 2000, "wider: " + panel.width + " from " + before)
    mouseDrag(handle, handle.width / 2, handle.height / 2, 4000, 0)
    tryCompare(panel, "width", wiki.sidePanelMax, 2000, "stops where the page would lose its column")
    var page = item("wikiFlick").width
    compare(Math.round(page), Math.round(wiki.width - panel.width - wiki.rightWidth), "the page takes the rest")
  }
}
