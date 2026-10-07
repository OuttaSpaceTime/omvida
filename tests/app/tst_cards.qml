import QtQuick

// The deck explorer: its filters, and the walk through them, the stage at
// the top showing the current card and the grid below only what comes after.
OmvidaTest {
  name: "cards"

  function stage() { return item("cardsStage") }
  function tile(i) { return findNamed(target, "cardTile:" + cardsScreen.filtered[i].id) }

  // Every test starts on a fresh visit to Cards, no filter, at the first
  // card, with the stage holding the keyboard as it does after a click on
  // the rail.
  function init() {
    cardsScreen.clearFilters()
    app.setScreen("home")
    app.setScreen("cards")
    tryVerify(function() { return cardsScreen.filtered.length === 5 }, 5000)
    cardsScreen.showCard(0)
    tryVerify(function() { return stage().activeFocus }, timeout, "the stage has the keyboard")
  }

  function test_state_and_text_filters() {
    click("stateChip:suspended")
    tryVerify(function() { return cardsScreen.filtered.length === 1 })
    click("stateChip:suspended")
    tryVerify(function() { return cardsScreen.filtered.length === 5 })
    item("cardFilter").text = "etag"
    tryVerify(function() { return cardsScreen.filtered.length === 1 })
    item("cardFilter").text = ""
    click("tagChip:http")
    tryVerify(function() { return cardsScreen.filtered.length === 2 })
    compare(item("filteredCount").text, "2 cards")
  }

  function test_retention_comes_from_the_deck() {
    tryVerify(function() { return cardsScreen.calibration !== null }, 5000)
    compare(cardsScreen.calibration.verdict, "low-signal")
    item("retentionPanel")
  }

  // One screen: no List / Flip through switch, the stage and the grid both up.
  function test_one_screen_no_mode_switch() {
    verify(findNamed(target, "cardsFlipMode") === null, "no mode switch")
    verify(stage().visible)
    verify(tile(1) !== null && tile(1).visible, "the grid is up")
  }

  // Paging forward takes the passed cards off the grid; paging back puts
  // them back. The grid always starts after the stage's card.
  function test_paging_takes_cards_off_the_grid() {
    var first = cardsScreen.filtered[0].id
    compare(stage().card.id, first)
    verify(tile(0) === null, "the stage's card is not in the grid")
    compare(cardsScreen.upNextCount, 4)

    key(Qt.Key_Right)
    compare(cardsScreen.current, 1)
    compare(stage().card.id, cardsScreen.filtered[1].id)
    verify(tile(1) === null, "the card now on the stage left the grid")
    verify(tile(2) !== null, "the rest is still there")
    compare(cardsScreen.upNextCount, 3)

    key(Qt.Key_Space)
    verify(stage().flipped, "Space flips")
    key(Qt.Key_L)
    compare(cardsScreen.current, 2)
    verify(!stage().flipped, "a new card comes front up")

    key(Qt.Key_Left)
    key(Qt.Key_H)
    compare(cardsScreen.current, 0)
    verify(tile(1) !== null && tile(2) !== null, "paging back puts them back")
    compare(stage().card.id, first)
  }

  // The stage stops at the ends instead of going round: past the last card
  // the grid is empty, and wrapping would bring the whole deck back at once.
  function test_the_walk_stops_at_the_ends() {
    key(Qt.Key_Left)
    compare(cardsScreen.current, 0)
    for (var i = 0; i < 6; i++) key(Qt.Key_Right)
    compare(cardsScreen.current, 4)
    compare(cardsScreen.upNextCount, 0)
    compare(item("upNext").text, "That was the last card")
    click("cardsRestart")
    compare(cardsScreen.current, 0)
  }

  // A click on a tile puts its card on the stage, front up; the cards before
  // it count as passed, as if paged to.
  function test_clicking_a_tile_makes_it_current() {
    key(Qt.Key_Space)
    var target3 = cardsScreen.filtered[3].id
    click("cardTile:" + target3)
    compare(cardsScreen.current, 3)
    compare(stage().card.id, target3)
    verify(!stage().flipped, "front up")
    verify(tile(1) === null && tile(2) === null && tile(3) === null, "it and the cards before it left the grid")
    verify(tile(4) !== null)
    compare(item("upNext").text.toLowerCase(), "next up · 1 · 3 passed")
    verify(stage().activeFocus, "the keys go on from the clicked card")
    key(Qt.Key_Left)
    compare(cardsScreen.current, 2)
  }

  // A new filter is a new walk; a refresh of the deck (every visit, and the
  // window coming to the front) keeps the place.
  function test_a_refresh_keeps_the_place_and_a_filter_starts_over() {
    key(Qt.Key_Right)
    key(Qt.Key_Right)
    var here = stage().card.id
    var before = cardsScreen.all
    app.store.refreshDeck()
    tryVerify(function() { return cardsScreen.all !== before }, 5000, "the deck was read again")
    compare(cardsScreen.current, 2)
    compare(stage().card.id, here)

    click("tagChip:security")
    tryVerify(function() { return cardsScreen.filtered.length === 3 })
    compare(cardsScreen.current, 0)
  }

  // The stage's keys are unmodified ones only: Alt+← is still the app's
  // history, not a page back.
  function test_alt_arrows_stay_the_apps() {
    key(Qt.Key_Right)
    key(Qt.Key_Left, Qt.AltModifier)
    tryCompare(app, "currentScreen", "home")
    app.setScreen("cards")
    compare(cardsScreen.current, 1, "Alt+← did not page")
  }

  // What the window's status line shows and runs for this screen.
  function test_status_line_contract() {
    compare(cardsScreen.statusMode, "CARDS")
    compare(cardsScreen.statusSegments[0].text, "1/5")
    var next = cardsScreen.statusHints.filter(function(h) { return h.label === "next" })[0]
    next.run()
    compare(cardsScreen.current, 1)
    compare(cardsScreen.statusSegments[0].text, "2/5")
    click("tagChip:http")
    tryCompare(cardsScreen.statusSegments, "length", 2)
    compare(cardsScreen.statusSegments[1].text, "#http")
    compare(cardsScreen.statusAlerts.length, 0)
    item("cardFilter").text = "no card says this"
    tryVerify(function() { return cardsScreen.statusAlerts.length === 1 })
    cardsScreen.statusAlerts[0].run()
    tryVerify(function() { return cardsScreen.filtered.length === 5 })
  }
}
