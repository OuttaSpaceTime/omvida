import QtQuick

import "Format.js" as Format

// Where the window is and how it got there: the screen on show, the open
// wiki page or folder, the graph's scope, and back and forward. State and
// moves only, no view: App.qml owns one (app.nav), the screens read it and
// call its moves, and what a move means for other parts (the palette closes,
// the study log notes the page, the wiki scrolls to a heading) is App's to
// wire through the signals below. So it runs under qmltestrunner with no
// window (tests/unit/tst_navigator.qml).
//
// It lived in omvida.qml at first, beside the window, the overlays and the
// IPC, and each move reached into the palette, the study session and the
// wiki screen by id; nothing could test it without the whole app.
QtObject {
  id: root

  property string currentScreen: "home" // home | study | wiki | cards | graph
  property string wikiPath: ""          // the open page, or "" for a folder
  property string wikiFolder: ""        // the open folder when no page is
  property var history: []              // previous {screen, path, folder}
  property var forwardStack: []
  // The graph screen: two hops around the open page, or every page.
  property bool graphLocal: false

  // A page or folder is about to open, before the screen changes: `path` is
  // the page, "" for a folder. Before, because leaving Study's summary writes
  // the session log, and a page opened from it belongs in that entry.
  signal navigating(string path)
  // A heading of the open page to scroll to, "" for the top.
  signal anchorRequested(string anchor)

  function setScreen(s) {
    if (s === root.currentScreen) return
    pushHistory()
    root.currentScreen = s
  }

  // Where a launch lands (bin/omvida's start screen) is no step to go back from.
  function forgetHistory() {
    root.history = []
    root.forwardStack = []
  }

  function here() { return { screen: root.currentScreen, path: root.wikiPath, folder: root.wikiFolder } }

  function pushHistory() {
    root.history = root.history.concat([here()]).slice(-50)
    root.forwardStack = []
  }

  function restore(entry) {
    root.wikiPath = entry.path
    root.wikiFolder = entry.folder
    root.currentScreen = entry.screen
  }

  function goBack() { step("history", "forwardStack") }
  function goForward() { step("forwardStack", "history") }

  // One step back or forward: the last place on `from` is restored, and
  // here goes on `to`.
  function step(from, to) {
    var stack = root[from]
    if (stack.length === 0) return
    var entry = stack[stack.length - 1]
    root[to] = root[to].concat([here()])
    root[from] = stack.slice(0, -1)
    restore(entry)
  }

  function openPage(path, anchor) {
    root.navigating(path)
    if (root.currentScreen !== "wiki" || root.wikiPath !== path) pushHistory()
    root.wikiFolder = ""
    root.wikiPath = path
    root.currentScreen = "wiki"
    root.anchorRequested(anchor || "")
  }

  function openFolder(folder) {
    root.navigating("")
    pushHistory()
    root.wikiPath = ""
    root.wikiFolder = folder
    root.currentScreen = "wiki"
  }

  function openGraph(local) {
    root.graphLocal = local
    setScreen("graph")
  }

  // What a link in any rich text means: wiki:path#anchor, anchor:slug (same
  // page), or an outside URL for the browser.
  function followLink(href) {
    var m
    if ((m = /^wiki:([^#]+)(?:#(.*))?$/.exec(href))) openPage(m[1], m[2] || "")
    else if ((m = /^anchor:(.*)$/.exec(href))) root.anchorRequested(m[1])
    else if (Format.isExternalUrl(href)) Qt.openUrlExternally(href)
  }
}
