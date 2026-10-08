import QtQuick

// Del deletes a card, after the window's ConfirmDialog asks: the one on the
// deck explorer's stage, or the one being studied. A file of its own: the
// deck loses cards here, and tst_cards and tst_study count on all five.
OmvidaTest {
  name: "delete"

  function stage() { return item("cardsStage") }
  function cardCount(id) { return sql("SELECT COUNT(*) FROM Card WHERE id = '" + id + "'")[0][0] }

  function init() {
    app.setScreen("home")
    app.setScreen("cards")
    tryVerify(function() { return cardsScreen.filtered.length > 0 }, 5000)
    cardsScreen.showCard(0)
    tryVerify(function() { return stage().activeFocus }, timeout, "the stage has the keyboard")
    // The change of screen hands the keyboard to the stage a turn later
    // (omvida.qml's focusScreen); let it, or it takes the keyboard back
    // from the dialog the first Del opens.
    wait(50)
  }

  // ---- Study (first: a session needs the fixture's due cards) -----------------
  // Del on the card being studied deletes it, and the session goes on; with
  // an answer typed it edits the answer instead, and Esc in the dialog
  // keeps the card.
  function test_0_study_del_deletes_the_card_and_goes_on() {
    startSession()
    var field = item("answerField")
    var c = study.card.id
    type("ab")
    field.cursorPosition = 0
    key(Qt.Key_Delete)
    compare(field.text, "b", "with an answer typed, Del edits it")
    verify(!app.confirmOpen)
    field.text = ""
    key(Qt.Key_Delete)
    verify(app.confirmOpen, "Del asks first")
    compare(item("confirmQuote").text, cardsScreen.tileTexts[c])
    key(Qt.Key_Escape)
    verify(!app.confirmOpen)
    tryVerify(function() { return field.activeFocus }, timeout, "the answer box has the keyboard back")
    compare(study.card.id, c)
    compare(cardCount(c), 1)

    click("statusHint:keys")
    click("keyHelp:delete")
    verify(app.confirmOpen, "the key list's row asks too")
    key(Qt.Key_Return)
    tryVerify(function() { return study.phase === "answering" || study.phase === "done" }, 8000)
    compare(cardCount(c), 0)
    verify(study.card === null || study.card.id !== c, "the session went on")
    study.endNow()
  }

  // ---- Cards ------------------------------------------------------------------------
  // Del opens the dialog, quoting the card; Esc (or n) keeps the card, and
  // the keys go back to the stage.
  function test_a_esc_keeps_the_card() {
    var n = cardsScreen.all.length
    var here = stage().card.id
    key(Qt.Key_Delete)
    verify(app.confirmOpen, "Del asks first")
    compare(item("confirmQuote").text, cardsScreen.tileTexts[here])
    // Enter is the answer now, not a flip; a stray → does not move on.
    key(Qt.Key_Right)
    compare(stage().card.id, here)
    key(Qt.Key_Escape)
    verify(!app.confirmOpen)
    tryVerify(function() { return stage().activeFocus }, timeout, "the stage has the keyboard back")
    key(Qt.Key_Delete)
    key(Qt.Key_N)
    verify(!app.confirmOpen)
    compare(cardCount(here), 1)
    compare(cardsScreen.all.length, n)
  }

  // Cancel, and a click on the scrim, keep the card too.
  function test_b_cancel_and_the_scrim_keep_the_card() {
    var here = stage().card.id
    key(Qt.Key_Delete)
    click("confirmCancel")
    verify(!app.confirmOpen)
    key(Qt.Key_Delete)
    mouseClick(item("confirmDialog"), 5, 5)   // check: allow-px a point on the scrim, off the card
    verify(!app.confirmOpen, "a click outside the card closes it")
    tryVerify(function() { return stage().activeFocus }, timeout)
    key(Qt.Key_Return)
    verify(stage().flipped, "Enter flips again")
    compare(cardCount(here), 1)
  }

  // Enter deletes it in the deck, and the walk goes on at the next card.
  function test_c_enter_deletes_and_the_walk_goes_on() {
    var n = cardsScreen.all.length
    key(Qt.Key_Right)
    var gone = stage().card.id, next = cardsScreen.filtered[2].id
    key(Qt.Key_Delete)
    key(Qt.Key_Return)
    verify(!app.confirmOpen)
    tryVerify(function() { return cardsScreen.all.length === n - 1 }, 5000, "the deck was read again")
    compare(cardCount(gone), 0)
    compare(stage().card.id, next)
    compare(cardsScreen.current, 1)
    tryVerify(function() { return stage().activeFocus }, timeout)
  }

  // The last card deleted: the one before it takes the stage. The status
  // line's hint asks, as Del does, and the red button deletes.
  function test_d_the_last_card_hands_back_to_the_one_before() {
    var n = cardsScreen.all.length
    cardsScreen.showCard(n - 1)
    var gone = stage().card.id, before = cardsScreen.filtered[n - 2].id
    click("statusHint:delete")
    verify(app.confirmOpen)
    click("confirmAccept")
    tryVerify(function() { return cardsScreen.all.length === n - 1 }, 5000)
    compare(cardCount(gone), 0)
    compare(stage().card.id, before)
  }

  // In the filter field Del deletes text, not the card.
  function test_e_del_in_the_filter_field_edits_text() {
    var field = item("cardFilter")
    field.forceActiveFocus()
    field.text = "ab"
    field.cursorPosition = 0
    key(Qt.Key_Delete)
    compare(field.text, "b")
    verify(!app.confirmOpen)
    field.text = ""
  }
}
