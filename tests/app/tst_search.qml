import QtQuick

// The searchPalette: titles as you type, qmd text hits, cards, and asking Claude.
OmvidaTest {
  name: "search"

  function init() { if (searchPalette.opened) searchPalette.close() }

  function test_ctrl_k_finds_a_page_and_enter_opens_it() {
    key(Qt.Key_K, Qt.ControlModifier)
    tryVerify(function() { return searchPalette.opened })
    type("caching")
    tryVerify(function() { return searchPalette.rows.length > 0 && searchPalette.rows[0].kind === "page" }, 3000)
    key(Qt.Key_Return)
    tryCompare(app, "wikiPath", "web/http-caching")
    verify(!searchPalette.opened)
  }

  function test_wiki_text_and_cards() {
    app.openSearch("forgery")
    tryVerify(function() { return searchPalette.rows.some(function(r) { return r.kind === "text" && r.path === "security/csrf" }) }, 5000, "qmd's hit")
    app.openSearch("ETag")
    tryVerify(function() { return searchPalette.rows.some(function(r) { return r.kind === "card" }) }, 5000, "a card hit")
  }

  function test_ctrl_enter_asks_claude_and_continue_resumes_in_kitty() {
    app.openSearch("What is an origin?")
    key(Qt.Key_Return, Qt.ControlModifier)
    tryVerify(function() { return searchPalette.askDone }, 8000)
    verify(searchPalette.askText.indexOf("scheme, host and port") !== -1)
    tryVerify(function() { return searchPalette.askBlocks !== null }, 5000, "rendered like a page")
    verify(JSON.stringify(searchPalette.askBlocks).indexOf("wiki:security/csrf") !== -1, "the wikilink resolved")
    var ask = claudeCalls().filter(function(a) { return a.indexOf("stream-json") !== -1 }).slice(-1)[0]
    verify(ask[ask.indexOf("--allowedTools") + 1].indexOf("Bash") === -1, "no Bash for a headless ask")
    var before = kittyCalls().length
    click("askContinue")
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    var argv = kittyCalls()[before]
    compare(argv.slice(-2), ["--resume", "fake-session-1"])
  }
}
