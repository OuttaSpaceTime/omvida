import QtQuick

// Home and the other reading screens: the Glance panel's actions, and what each screen hands the window's status line (its hints run
// what their keys run).
OmvidaTest {
  name: "home"

  function init() {
    if (searchPalette.opened) searchPalette.close()
    app.setScreen("home")
  }

  function test_the_glance_shows_the_due_figure_and_verdict() {
    var o = app.store.overview
    compare(item("dueFigure").text, String(o.pressure.flashcardsDue))
    compare(item("pressureVerdict").text, o.pressure.verdict, "verbatim")
    compare(item("calibrationVerdict").text.indexOf(o.calibration.verdict), 0, "verbatim")
  }

  // The deck and the wiki moved from a bordered "Browse the deck" button to
  // square icons beside Study now.
  function test_square_icons_open_the_deck_and_the_wiki() {
    click("homeCardsButton")
    tryCompare(app, "currentScreen", "cards")
    app.setScreen("home")
    click("homeWikiButton")
    tryCompare(app, "currentScreen", "wiki")
  }

  // The line shows a screen's own hints, then the ones every reading screen
  // shares (StatusLine.qml).
  function test_home_hands_the_status_line_its_counts_and_keys() {
    var home = item("homeScreen"), line = item("statusLine")
    compare(item("statusMode").text, "HOME")
    verify(home.statusSegments[0].text.indexOf("4 pages") === 0, home.statusSegments[0].text)
    var keys = line.hints.map(function(h) { return h.keys })
    compare(keys.slice(0, 3), ["⌃2", "⌃K", "⌃N"])
    // The search hint is Ctrl+K: it opens the palette.
    line.hints.filter(function(h) { return h.keys === "⌃K" })[0].run()
    tryVerify(function() { return searchPalette.opened })
  }

  // The Add menu holds the keyboard while open, so Esc closes it on any
  // screen, and the keyboard goes back to the screen.
  function test_escape_closes_the_add_menu_anywhere() {
    app.toggleAdd()
    verify(app.addMenuOpen)
    key(Qt.Key_Escape)
    tryVerify(function() { return !app.addMenuOpen }, 2000)
    compare(app.currentScreen, "home")
  }

  // Ctrl+K and Ctrl+N no longer print in the top bar; the keys still work.
  function test_keys_left_the_top_bar_but_still_work() {
    key(Qt.Key_K, Qt.ControlModifier)
    tryVerify(function() { return searchPalette.opened })
    key(Qt.Key_Escape)
    tryVerify(function() { return !searchPalette.opened })
  }

  function test_wiki_and_graph_hand_their_own_status() {
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.loadedPath === "web/http-caching" }, 8000)
    compare(item("statusMode").text, "WIKI")
    compare(wiki.statusSegments[0].text, "web/http-caching")
    var back = item("statusLine").hints.filter(function(h) { return h.keys === "alt+←" })
    compare(back.length, 1, "history behind the page, so a back hint")
    back[0].run()
    tryCompare(app, "currentScreen", "home")

    app.setScreen("graph")
    var graph = item("graphScreen")
    compare(item("statusMode").text, "GRAPH")
    verify(graph.statusSegments[0].text.indexOf("page") !== -1, graph.statusSegments[0].text)
  }
}
