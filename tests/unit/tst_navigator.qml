import QtQuick
import QtTest
import "../.."

// Navigator.qml: where the window is, back and forward, and what a link
// means, with no window around it.
TestCase {
  name: "Navigator"

  Navigator { id: nav }

  SignalSpy { id: navigating; target: nav; signalName: "navigating" }
  SignalSpy { id: anchorSpy; target: nav; signalName: "anchorRequested" }

  function init() {
    nav.currentScreen = "home"
    nav.wikiPath = ""
    nav.wikiFolder = ""
    nav.graphLocal = false
    nav.forgetHistory()
    navigating.clear()
    anchorSpy.clear()
  }

  function test_set_screen_keeps_history_once_per_change() {
    nav.setScreen("cards")
    nav.setScreen("cards")
    compare(nav.currentScreen, "cards")
    compare(nav.history.length, 1, "the same screen again is no step")
    compare(nav.history[0].screen, "home")
  }

  function test_back_and_forward_restore_the_page_too() {
    nav.openPage("web/cookies", "")
    nav.openFolder("security")
    nav.goBack()
    compare(nav.currentScreen, "wiki")
    compare(nav.wikiPath, "web/cookies")
    compare(nav.wikiFolder, "")
    nav.goBack()
    compare(nav.currentScreen, "home")
    nav.goForward()
    nav.goForward()
    compare(nav.wikiPath, "")
    compare(nav.wikiFolder, "security")
    compare(nav.forwardStack.length, 0)
  }

  function test_a_new_step_drops_what_was_ahead() {
    nav.setScreen("cards")
    nav.goBack()
    compare(nav.forwardStack.length, 1)
    nav.setScreen("graph")
    compare(nav.forwardStack.length, 0)
  }

  function test_history_keeps_the_last_fifty() {
    for (let i = 0; i < 60; i++) nav.setScreen(i % 2 ? "home" : "cards")
    compare(nav.history.length, 50)
  }

  // The window closes the palette and notes the page for the study log on
  // `navigating`, which comes before the screen changes.
  function test_open_page_says_so_before_it_moves() {
    var seen = ""
    var hook = function(path) { seen = path + "@" + nav.currentScreen }
    nav.navigating.connect(hook)
    nav.openPage("security/csrf", "tokens")
    nav.navigating.disconnect(hook)
    compare(seen, "security/csrf@home")
    compare(nav.currentScreen, "wiki")
    compare(nav.wikiPath, "security/csrf")
    compare(anchorSpy.count, 1)
    compare(anchorSpy.signalArguments[0][0], "tokens")
  }

  function test_the_same_page_again_is_no_step() {
    nav.openPage("web/cookies", "")
    nav.openPage("web/cookies", "max-age")
    compare(nav.history.length, 1)
    compare(anchorSpy.count, 2, "but it still scrolls")
  }

  function test_open_folder_leaves_the_page() {
    nav.openPage("web/cookies", "")
    nav.openFolder("web")
    compare(nav.wikiPath, "")
    compare(nav.wikiFolder, "web")
    compare(navigating.signalArguments[1][0], "", "a folder is no page for the log")
  }

  function test_links() {
    nav.followLink("wiki:security/csrf#defences")
    compare(nav.wikiPath, "security/csrf")
    compare(anchorSpy.signalArguments[0][0], "defences")
    nav.followLink("anchor:intro")
    compare(nav.wikiPath, "security/csrf", "a same-page anchor stays on the page")
    compare(anchorSpy.signalArguments[1][0], "intro")
    // Not a link the app or the browser takes: nothing happens.
    nav.followLink("file:///etc/passwd")
    compare(nav.wikiPath, "security/csrf")
  }

  function test_open_graph_sets_its_scope() {
    nav.openGraph(true)
    compare(nav.currentScreen, "graph")
    verify(nav.graphLocal)
  }

  function test_forget_history() {
    nav.setScreen("cards")
    nav.goBack()
    nav.setScreen("graph")
    nav.forgetHistory()
    compare(nav.history.length, 0)
    compare(nav.forwardStack.length, 0)
    compare(nav.currentScreen, "graph")
  }
}
