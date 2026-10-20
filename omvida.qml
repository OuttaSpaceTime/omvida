import QtQuick
import Quickshell
import Quickshell.Io

import "Launch.js" as Launch
import "Format.js" as Format


// Omvida: the study wiki and its flashcards, as a Quickshell app beside
// Omvision. Launched with bin/omvida (single instance; see there).
//
// This file owns navigation, the window and its overlays. The data and the two
// backends are Store.qml's (app.store); the study session is StudySession.qml's.
//
// Screens: Home (the dashboard), Study (the review loop), Wiki (reader with
// tree, context and links), Cards (the deck explorer) and Graph. Over them:
// the search palette, which also asks Claude, and the Add menu's topic
// dialog, which opens Claude Code in kitty.
ShellRoot {
  id: root

  // A test, screenshot or sandbox run never reloads itself when a file
  // changes. Quickshell's reload replaces the whole object tree while a test
  // is still running inside it, and Qt aborts ("destroyed while one of its
  // QML signal handlers is in progress"): editing during bin/check crashed
  // test instances, and Quickshell restarted them offscreen. Your own Omvida
  // still reloads on save.
  settings.watchFiles: (Quickshell.env("OMVIDA_TEST") || Quickshell.env("OMVIDA_SHOT_DIR") || Quickshell.env("OMVIDA_SANDBOX") || "") === ""

  property string currentScreen: "home" // home | study | wiki | cards | graph
  property string wikiPath: ""          // the open page, or "" for a folder
  property string wikiFolder: ""        // the open folder when no page is
  property var history: []              // previous {screen, path, folder}
  property var forwardStack: []

  readonly property alias store: dataStore
  readonly property var dueCount: dataStore.overview ? dataStore.overview.pressure.flashcardsDue : 0
  // The card on the Study screen, for the Add dialog's context.
  readonly property var currentCard: study.inCard ? study.card : null

  // Every way into Study (the rail, Ctrl+2, Home, IPC, `omvida study`) lands
  // here: the screen and a session together, so none shows an idle screen.
  function startStudy() {
    root.setScreen("study")
    study.startIfIdle()
  }
  function toast(msg) { toastItem.show(msg) }
  // Where the keyboard goes after a change of screen or when an overlay
  // closes: into the screen's own field if it has one (a screen declares
  // `takeFocus()`, returning false when it has nothing to focus: Study's
  // answer box, the Cards stage), else the window's root, whose keys are
  // the app's. Keys a screen's field doesn't use travel up to the root.
  function focusScreen() {
    var s = screens.current
    if (!s || typeof s.takeFocus !== "function" || !s.takeFocus()) contentRoot.forceActiveFocus()
  }
  // The Add menu: toggleAdd for the status line's ctrl+N hint (StatusBits.js);
  // addMenuOpen for the tests.
  readonly property bool addMenuOpen: addMenu.opened
  function toggleAdd() { addMenu.toggle() }

  function setScreen(s) {
    if (s === root.currentScreen) return
    pushHistory()
    root.currentScreen = s
  }

  function pushHistory() {
    root.history = root.history.concat([{ screen: root.currentScreen, path: root.wikiPath, folder: root.wikiFolder }]).slice(-50)
    root.forwardStack = []
  }

  function restore(entry) {
    root.wikiPath = entry.path
    root.wikiFolder = entry.folder
    root.currentScreen = entry.screen
  }

  function goBack() {
    if (root.history.length === 0) return
    var prev = root.history[root.history.length - 1]
    root.forwardStack = root.forwardStack.concat([{ screen: root.currentScreen, path: root.wikiPath, folder: root.wikiFolder }])
    root.history = root.history.slice(0, -1)
    restore(prev)
  }

  function goForward() {
    if (root.forwardStack.length === 0) return
    var next = root.forwardStack[root.forwardStack.length - 1]
    root.history = root.history.concat([{ screen: root.currentScreen, path: root.wikiPath, folder: root.wikiFolder }])
    root.forwardStack = root.forwardStack.slice(0, -1)
    restore(next)
  }

  // Navigation closes the palette, so nothing that shows links has to.
  function openPage(path, anchor) {
    if (palette.opened) palette.close()
    // Before the screen changes: leaving Study's summary writes the session
    // log, and a page opened from it belongs in that entry.
    study.notePageOpened(path)
    if (root.currentScreen !== "wiki" || root.wikiPath !== path) pushHistory()
    root.wikiFolder = ""
    root.wikiPath = path
    root.currentScreen = "wiki"
    wikiScreen.scrollTo(anchor || "")
  }

  function openFolder(folder) {
    if (palette.opened) palette.close()
    pushHistory()
    root.wikiPath = ""
    root.wikiFolder = folder
    root.currentScreen = "wiki"
  }

  // What a link in any rich text means: wiki:path#anchor, anchor:slug (same
  // page), or an outside URL for the browser.
  function followLink(href) {
    var m
    if ((m = /^wiki:([^#]+)(?:#(.*))?$/.exec(href))) openPage(m[1], m[2] || "")
    else if ((m = /^anchor:(.*)$/.exec(href))) wikiScreen.scrollTo(m[1])
    else if (/^https?:/.test(href)) Qt.openUrlExternally(href)
  }

  // Claude Code in kitty, detached: closing Omvida must not close it.
  function launch(argv, note) {
    Quickshell.execDetached(argv)
    if (note) toastItem.show(note)
  }

  function openSearch(text) { palette.open(text || "") }
  // The graph screen, all pages or around the open page.
  function openGraph(local) {
    graphScreen.local = local
    setScreen("graph")
  }
  function openPageCards(title, cards) { pageCardsDialog.open(title, cards) }
  function openAdd(kind, topic, context) { topicDialog.open(kind, topic, context) }

  // ---- card notes ---------------------------------------------------------------
  // A card's note (NoteDialog.qml), new or as it is; `prefill` starts a new
  // one. noteOpen for the tests.
  readonly property bool noteOpen: noteDialog.opened
  function openNote(card, prefill) { noteDialog.open(card, prefill) }
  // Every noted card (or those of `ids`) to Claude Code in one session
  // (Launch.fixNotesArgv), which resolves each note as it deals with it.
  function fixNotes(ids) {
    var noted = dataStore.notedIds(ids || null)
    if (noted.length === 0) { toast("No noted cards to fix"); return }
    launch(Launch.fixNotesArgv(Paths.studyDir, ids ? noted : null), "Opened Claude Code with " + Format.plural(noted.length, "noted card"))
  }

  // ---- pages from study ----------------------------------------------------------
  // The wiki pages a finished session pointed to (its summary's related
  // pages), kept in the wiki's side panel so they stay one click apart while
  // you read them: the summary is gone once a page is open, and was the only
  // place they were listed. Newest session's first, each page once, until
  // cleared (one by one or all) or the app closes. [{ path, title, lapsed, via, cards }]
  property var studyPages: []
  function addStudyPages(pages) {
    var paths = pages.map(function(p) { return p.path })
    root.studyPages = pages.concat(root.studyPages.filter(function(p) { return paths.indexOf(p.path) === -1 }))
  }
  function dropStudyPage(path) { root.studyPages = root.studyPages.filter(function(p) { return p.path !== path }) }
  function clearStudyPages() { root.studyPages = [] }
  // Ask before something that cannot be undone (ConfirmDialog.qml);
  // confirmOpen for the tests.
  readonly property bool confirmOpen: confirmDialog.opened
  // The IPC handler, for the tests: they call it as `qs ipc` would.
  readonly property alias ipc: ipc
  function confirm(title, quote, note, action, accept) { confirmDialog.open(title, quote, note, action, accept) }

  Store {
    id: dataStore
    active: contentRoot.windowActive
    studying: study.phase !== "idle" && study.phase !== "done" && study.phase !== "error"
    onWikiFilesChanged: wikiScreen.reloadPage()
  }

  // The study session, beside the clients it talks to: StudyScreen draws it,
  // the window asks it for the current card and a pending log entry.
  StudySession {
    id: study
    app: root
    deck: dataStore.deck
    wikiService: dataStore.wiki
  }

  // ---- IPC: bin/omvida and the bar widget ----------------------------------------
  IpcHandler {
    id: ipc
    target: "omvida"
    function show(): void { }
    function home(): void { root.setScreen("home") }
    function study(): void { root.startStudy() }
    function wiki(): void { root.setScreen("wiki") }
    function cards(): void { root.setScreen("cards") }
    function graph(): void { root.setScreen("graph") }
    function open(path: string): void { if (path !== "") root.openPage(path, "") }
    function search(text: string): void { root.openSearch(text) }
    // A card was written elsewhere (bin/omvida-deck-changed, from the study
    // repo's Claude Code hook): check the deck now rather than at the next poll.
    function deckChanged(): void { dataStore.deckPushed() }
  }

  function applyStart() {
    var cmd = Quickshell.env("OMVIDA_START") || "show"
    var arg = Quickshell.env("OMVIDA_START_ARG") || ""
    if (cmd === "study") root.startStudy()
    else if (cmd === "open" && arg !== "") root.openPage(arg, "")
    else if (cmd === "search") root.openSearch(arg)
    else if (["home", "wiki", "cards", "graph"].indexOf(cmd) !== -1) root.currentScreen = cmd
    root.history = []
  }

  // Closing the window ends the app (Omvision's lesson: Quickshell otherwise
  // outlives its windows, and each launch left another one behind).
  // A finished session whose log entry is still pending is written first,
  // with a deadline: quitting must never hang on the wiki service.
  Connections {
    target: Quickshell
    function onLastWindowClosed() {
      if (!study.logPending) { Qt.quit(); return }
      quitDeadline.start()
      study.writeLog(function() { Qt.quit() })
    }
  }
  Timer { id: quitDeadline; interval: 2000; onTriggered: Qt.quit() }

  FloatingWindow {
    id: window
    title: "Omvida"
    implicitWidth: parseInt(Quickshell.env("OMVIDA_SHOT_WIDTH") || "0") || Theme.windowWidth
    implicitHeight: parseInt(Quickshell.env("OMVIDA_SHOT_HEIGHT") || "0") || Theme.windowHeight
    minimumSize: Qt.size(Theme.windowMinWidth, Theme.windowMinHeight)
    color: Theme.paper

    Item {
      id: contentRoot
      objectName: "contentRoot"
      anchors.fill: parent
      focus: true
      Component.onCompleted: { forceActiveFocus(); root.applyStart() }

      readonly property bool windowActive: Window.active

      // App-wide keys. A focused field gets them first and passes on what it
      // doesn't use: the study answer box handles its own Shift/Alt+Enter and
      // lets these through. A dialog keeps its keys (Modal.qml).
      readonly property var screenKeys: ({
        [Qt.Key_1]: "home", [Qt.Key_2]: "study", [Qt.Key_3]: "wiki", [Qt.Key_4]: "cards", [Qt.Key_5]: "graph"
      })
      Keys.onPressed: function(event) {
        var ctrl = event.modifiers & Qt.ControlModifier, alt = event.modifiers & Qt.AltModifier
        if (ctrl && event.key === Qt.Key_K) { root.openSearch(""); event.accepted = true; return }
        if (ctrl && event.key === Qt.Key_N) { addMenu.toggle(); event.accepted = true; return }
        if (ctrl && screenKeys[event.key] !== undefined) {
          if (screenKeys[event.key] === "study") root.startStudy()
          else root.setScreen(screenKeys[event.key])
          event.accepted = true
          return
        }
        if (alt && event.key === Qt.Key_Left) { root.goBack(); event.accepted = true; return }
        if (alt && event.key === Qt.Key_Right) { root.goForward(); event.accepted = true; return }
        if (event.key === Qt.Key_Slash && !ctrl && !alt && root.currentScreen !== "study") {
          root.openSearch(""); event.accepted = true
        }
      }

      // Hiding a screen does not take the keyboard from it (Omvision's
      // lesson: typing then landed in the hidden journal). Every change of
      // screen takes it back here at once, then hands it to the new screen
      // a turn later, once that screen is visible and can hold it.
      Connections {
        target: root
        function onCurrentScreenChanged() {
          contentRoot.forceActiveFocus()
          Qt.callLater(root.focusScreen)
        }
      }

      Loader {
        anchors.fill: parent
        z: -1
        active: (Quickshell.env("OMVIDA_SHOT_DIR") || "") !== ""
        source: "ShotDriver.qml"
        onLoaded: contentRoot.inject(item)
      }

      // Test hook: OMVIDA_TEST names a .qml file that drives the real app
      // from inside (tests/app, docs/testing.md), as Omvision's does.
      Loader {
        anchors.fill: parent
        z: -1
        readonly property string testFile: Quickshell.env("OMVIDA_TEST") || ""
        active: testFile !== ""
        source: testFile === "" ? "" : (testFile.charAt(0) === "/" ? "file://" + testFile : Qt.resolvedUrl(testFile))
        onLoaded: contentRoot.inject(item)
      }

      // What the screenshot driver and a test file get handed: each of these
      // that the item declares.
      function inject(item) {
        var parts = { app: root, study: study, studyView: studyScreen, wiki: wikiScreen, cardsScreen: cardsScreen,
                      searchPalette: palette, addMenu: addMenu, target: contentRoot, window: window }
        for (let k in parts) if (k in item) item[k] = parts[k]
      }

      // The paper behind every screen: the window's own colour is not in a
      // grab (bin/shot, a failed test's screenshot), so it is painted here too.
      Rectangle { anchors.fill: parent; z: -2; color: Theme.paper }

      Sidebar {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        currentScreen: root.currentScreen
        dueCount: root.dueCount
        onNavigate: function(screen) {
          if (screen === "study") root.startStudy()
          else root.setScreen(screen)
        }
      }

      TopBar {
        id: topBar
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        status: dataStore.deck.failure !== "" ? dataStore.deck.failure : (dataStore.wiki.failure !== "" ? dataStore.wiki.failure : dataStore.status)
        onSearchRequested: root.openSearch("")
        onAddRequested: addMenu.toggle()
      }

      Item {
        id: screens
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: statusLine.top

        // The screen on show, for the status line.
        readonly property var current: ({ home: homeScreen, study: studyScreen, wiki: wikiScreen,
                                           cards: cardsScreen, graph: graphScreen })[root.currentScreen] || null

        HomeScreen {
          id: homeScreen
          anchors.fill: parent
          visible: root.currentScreen === "home"
          app: root
        }
        StudyScreen {
          id: studyScreen
          anchors.fill: parent
          visible: root.currentScreen === "study"
          session: study
        }
        WikiScreen {
          id: wikiScreen
          anchors.fill: parent
          visible: root.currentScreen === "wiki"
          app: root
          wikiService: dataStore.wiki
        }
        CardsScreen {
          id: cardsScreen
          anchors.fill: parent
          visible: root.currentScreen === "cards"
          app: root
        }
        GraphScreen {
          id: graphScreen
          anchors.fill: parent
          visible: root.currentScreen === "graph"
          app: root
        }
      }

      // The bottom line, as an editor's: each screen's mode, place, keys and
      // alerts (StatusLine.qml has the contract the screens fill in).
      StatusLine {
        id: statusLine
        objectName: "statusLine"
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.statusLineHeight
        app: root
        screen: screens.current
        screenName: root.currentScreen
      }

      AddMenu {
        id: addMenu
        x: parent.width - width - Theme.spaceLg
        y: topBar.height - Theme.spaceXs
        onPicked: function(kind) { root.openAdd(kind, "", "") }
        onClosed: root.focusScreen()
      }

      SearchPalette {
        id: palette
        anchors.fill: parent
        app: root
        deck: dataStore.deck
        wikiService: dataStore.wiki
      }

      PageCardsDialog {
        id: pageCardsDialog
        anchors.fill: parent
        onClosed: root.focusScreen()
      }

      TopicDialog {
        id: topicDialog
        anchors.fill: parent
        app: root
      }

      NoteDialog {
        id: noteDialog
        anchors.fill: parent
        app: root
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        onClosed: root.focusScreen()
      }

      Toast {
        id: toastItem
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: statusLine.top
        anchors.bottomMargin: Theme.spaceXl
      }
    }
  }
}
