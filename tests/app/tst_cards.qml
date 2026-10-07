import QtQuick

// The deck explorer's filters.
OmvidaTest {
  name: "cards"

  function test_state_and_text_filters() {
    app.setScreen("cards")
    tryVerify(function() { return cardsScreen.filtered.length === 5 }, 5000)
    click("stateChip:suspended")
    tryVerify(function() { return cardsScreen.filtered.length === 1 })
    click("stateChip:suspended")
    tryVerify(function() { return cardsScreen.filtered.length === 5 })
    item("cardFilter").text = "etag"
    tryVerify(function() { return cardsScreen.filtered.length === 1 })
    item("cardFilter").text = ""
    click("tagChip:http")
    tryVerify(function() { return cardsScreen.filtered.length === 2 })
  }

  function test_retention_comes_from_the_deck() {
    app.setScreen("cards")
    tryVerify(function() { return cardsScreen.calibration !== null }, 5000)
    compare(cardsScreen.calibration.verdict, "low-signal")
  }
}
