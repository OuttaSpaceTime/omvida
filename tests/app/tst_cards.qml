import QtQuick

// The deck explorer: its filters, and the walk through them, the stage at
// the top showing the current card and the grid below only what comes after.
OmvidaTest {
  name: "cards"

  // The screen's tag limit as the app set it, put back before each test
  // (one lowers it, to make "N more tags" appear in a five-card deck).
  property int tagLimitAtStart: -1

  function stage() { return item("cardsStage") }
  function tile(i) { return findNamed(target, "cardTile:" + cardsScreen.filtered[i].id) }

  // Every test starts on a fresh visit to Cards, no filter, at the first
  // card, with the stage holding the keyboard as it does after a click on
  // the rail.
  function init() {
    cardsScreen.clearFilters()
    cardsScreen.filtersOpen = true
    if (tagLimitAtStart < 0) tagLimitAtStart = cardsScreen.tagLimit
    cardsScreen.tagLimit = tagLimitAtStart
    cardsScreen.closeTags()
    app.setScreen("home")
    app.setScreen("cards")
    tryVerify(function() { return cardsScreen.filtered.length === 5 }, 5000)
    cardsScreen.showCard(0)
    tryVerify(function() { return stage().activeFocus }, timeout, "the stage has the keyboard")
  }

  function test_state_and_text_filters() {
    click("stateChip:suspended")
    tryVerify(function() { return cardsScreen.filtered.length === 1 })
    // Selected, it moves up to the selected row; a click there drops it.
    click("selected:state:suspended")
    tryVerify(function() { return cardsScreen.filtered.length === 5 })
    item("cardFilter").text = "etag"
    tryVerify(function() { return cardsScreen.filtered.length === 1 })
    item("cardFilter").text = ""
    click("tagChip:http")
    tryVerify(function() { return cardsScreen.filtered.length === 2 })
    compare(item("filteredCount").text, "2 cards")
  }

  // The selected filters sit on top and leave the list of choices; folding
  // the section keeps only them (and the text field) in view.
  function test_selected_filters_stay_on_top_and_survive_folding() {
    click("tagChip:http")
    tryVerify(function() { return cardsScreen.filtered.length === 2 })
    click("stateChip:review")
    tryVerify(function() { return cardsScreen.filtered.length === 2 })
    item("selected:tag:http")
    item("selected:state:review")
    verify(findNamed(target, "tagChip:http") === null, "a selected tag leaves the choices")
    var picked = item("selectedFilters"), field = item("cardFilter")
    verify(picked.mapToItem(null, 0, 0).y < field.mapToItem(null, 0, 0).y, "selected filters sit above the field")

    click("filtersToggle")
    tryVerify(function() { return findNamed(target, "tagChip:security") === null }, 2000, "folded: the choices are hidden")
    item("selected:tag:http")
    item("cardFilter")
    compare(cardsScreen.filtered.length, 2, "folding changes nothing that is selected")

    click("filtersToggle")
    item("tagChip:web")
    click("selected:tag:http")
    // "review" is still selected: the three review cards.
    tryVerify(function() { return cardsScreen.filtered.length === 3 })
  }

  // Tags narrow together: a card must carry every picked one, and the tags
  // left to pick are only those of the cards still shown, counted as the
  // cards each pick would leave.
  function test_tags_narrow_together() {
    click("tagChip:security")
    tryVerify(function() { return cardsScreen.filtered.length === 3 })
    verify(findNamed(target, "tagChip:http") === null, "no security card is tagged http, so http is not offered")
    compare(item("tagChip:web").count, 1)
    click("tagChip:web")
    tryVerify(function() { return cardsScreen.filtered.length === 1 })
    item("selected:tag:security")
    item("selected:tag:web")
    compare(cardsScreen.statusSegments[1].text, "#security · #web")
    // The states count what the tags left, not the whole deck.
    compare(cardsScreen.stateList, [{ state: "review", count: 1 }])
    click("selected:tag:security")
    tryVerify(function() { return cardsScreen.filtered.length === 3 })
    compare(cardsScreen.filters.tags, ["web"])
  }

  // The filter column never scrolls: past the first few tags, "N more tags"
  // opens the tag panel, where a field finds a tag by name, Enter picks it,
  // Backspace in the empty field drops the last pick and Esc closes.
  function test_more_tags_opens_the_tag_panel() {
    verify(!("contentY" in item("cardsAside")), "the filter column is not a scroller")
    cardsScreen.tagLimit = 1
    compare(item("moreTags").label, "2 more tags ›")
    click("moreTags")
    tryVerify(function() { return item("tagPanelField").activeFocus }, timeout, "the panel's field has the keyboard")
    compare(item("statusHint:close").visible, true)

    type("ht")
    tryVerify(function() { return findNamed(target, "tagRow:security") === null })
    item("tagRow:http")
    key(Qt.Key_Return)
    compare(cardsScreen.filters.tags, ["http"])
    compare(item("tagPanelField").text, "", "cleared for the next name")
    verify(cardsScreen.tagPanelOpen, "still open for another pick")
    tryVerify(function() { return findNamed(target, "tagRow:web") !== null })
    compare(item("tagRow:web").modelData.count, 2)
    verify(findNamed(target, "tagRow:security") === null, "no http card is tagged security")

    key(Qt.Key_Backspace)
    compare(cardsScreen.filters.tags, [])
    click("tagRow:security")
    compare(cardsScreen.filters.tags, ["security"])
    click("tagPanelSelected:security")
    compare(cardsScreen.filters.tags, [])

    key(Qt.Key_Escape)
    verify(!cardsScreen.tagPanelOpen)
    tryVerify(function() { return stage().activeFocus }, timeout, "the stage has the keyboard again")
  }

  // The stage is as tall as the column of filters beside it, or its least
  // height when the column is shorter (a small deck's few tags): the column
  // never runs on past the card. Its front sits mid-card, set left in a
  // block with equal margins.
  function test_stage_keeps_its_height_and_centres_the_card() {
    var face = item("flipCard")
    var aside = item("cardsAside")
    // The stage, not the card: a card still turning in is rotated, and a
    // rotated item's corners map elsewhere.
    var faceEnd = stage().mapToItem(null, 0, stage().height).y, asideEnd = aside.mapToItem(null, 0, aside.height).y
    verify(faceEnd >= asideEnd - 1, "the filter column ends with the card or above it: " + faceEnd + " vs " + asideEnd)
    var front = item("flipFront")
    compare(front.horizontalAlignment, Text.AlignLeft)
    compare(front.x, face.width - front.x - front.width, "equal margins")
    var mid = front.y + front.height / 2
    verify(Math.abs(mid - face.height / 2) < face.height / 10, "the front sits mid-card: " + mid + " of " + face.height)
  }

  // A flip turns the card over, not a cut: partway through, it is still
  // turning.
  function test_the_stage_card_turns_over() {
    var face = item("flipCard")
    var turn = face.transform[0]
    compare(turn.angle, 0)
    key(Qt.Key_Space)
    wait(80)   // a third of the turn
    verify(turn.angle > 0 && turn.angle < 180, "mid-turn: " + turn.angle)
    tryCompare(turn, "angle", 180, 2000)
  }

  // Paging shows the next card front up at once, even from an answer: it
  // doesn't turn back over (which would show the next card's answer).
  function test_next_shows_the_front_at_once() {
    key(Qt.Key_Space)
    tryCompare(item("flipCard").transform[0], "angle", 180, 2000)
    key(Qt.Key_Right)
    compare(stage().flipped, false)
    compare(item("flipCard").transform[0].angle, 0)
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
    // A refresh that changed nothing keeps the same list (and the grid's
    // tiles); one that did hands over a new list, which must keep the place.
    sqlWrite("UPDATE Card SET reps = reps + 1 WHERE id = 'fixturecard0004'")
    app.store.refreshDeck()
    tryVerify(function() { return cardsScreen.all !== before }, 5000, "the deck was read again")
    compare(cardsScreen.current, 2)
    compare(stage().card.id, here)

    click("tagChip:security")
    tryVerify(function() { return cardsScreen.filtered.length === 3 })
    compare(cardsScreen.current, 0)
  }

  function test_a_refresh_that_changed_nothing_keeps_the_list() {
    var before = cardsScreen.all
    var reads = app.store.refreshedAt
    app.store.refreshDeck()
    tryVerify(function() { return app.store.refreshedAt !== reads }, 5000)
    wait(500)
    verify(cardsScreen.all === before, "the same list, so no tile is rebuilt")
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
    compare(item("statusMode").text, "CARDS")
    // Cards gets the shared hints after its own, like every reading screen.
    verify(item("statusLine").hints.some(function(h) { return h.keys === "⌃K" }), "shared hints")
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
