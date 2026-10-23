import QtQuick
import Quickshell
import Quickshell.Io

import "Launch.js" as Launch
import "Format.js" as Format

// The app: its parts (app.store, app.nav, app.study), the window and its
// overlays, and what a screen may ask of them: an overlay, a toast, a launch,
// the keyboard back. A type of its own, so screens and dialogs declare
// `required property App app` and qmllint checks what they use; omvida.qml is
// only the ShellRoot around it. docs/architecture.md, "The parts", has the
// wiring and why.
//
// Screens: Home, Study, Wiki, Cards and Graph. Over them: the search palette
// (which also asks Claude), the Add menu's topic dialog, a page's cards, a
// card's note and the confirm dialog.
Scope {
  id: root

  readonly property alias store: dataStore
  readonly property alias nav: navigator
  readonly property alias study: studySession

  // Every way into Study (the rail, Ctrl+2, Home, IPC, `omvida study`) lands
  // here: the screen and a session together, so none shows an idle screen.
  function startStudy() {
    navigator.setScreen("study")
    studySession.startIfIdle()
  }
  // A screen by name, Study through startStudy.
  function goTo(screen) {
    if (screen === "study") startStudy()
    else navigator.setScreen(screen)
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

  // Another program, detached, closing Omvida must not close it: Claude Code
  // in kitty (Launch.js has every argv) or an explorable's web app window.
  function launch(argv, note) {
    Quickshell.execDetached(argv)
    if (note) toastItem.show(note)
  }

  function openSearch(text) { palette.open(text || "") }
  function openPageCards(title, cards) { pageCardsDialog.open(title, cards) }
  function openAdd(kind, topic, context) { topicDialog.open(kind, topic, context) }
  // Ask before something that cannot be undone (ConfirmDialog.qml);
  // confirmOpen for the tests.
  readonly property bool confirmOpen: confirmDialog.opened
  function confirm(title, quote, note, action, accept) { confirmDialog.open(title, quote, note, action, accept) }
  // Deleting a card, from Study or the Cards stage, quoting its front;
  // `accept` deletes it (Store.deleteCard). A leech asks in its own panel
  // (LeechPanel.qml), beside the card it already shows.
  function confirmDeleteCard(card, accept) {
    confirm("Delete this card?", Format.stripHtml(card.front),
            "Its review history goes with it. This cannot be undone.", "Delete", accept)
  }

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

  Store {
    id: dataStore
    active: contentRoot.windowActive
    studying: studySession.running
    onWikiFilesChanged: wikiScreen.reloadPage()
  }

  Navigator {
    id: navigator
    // Navigation closes the palette, so nothing that shows links has to; and
    // a page opened from Study's summary (or mid-session) goes in its log.
    onNavigating: function(path) {
      if (palette.opened) palette.close()
      if (path !== "") studySession.notePageOpened(path)
    }
    onAnchorRequested: function(anchor) { wikiScreen.scrollTo(anchor) }
  }

  // StudyScreen draws it; the window asks it for a pending log entry, and
  // shows what it asks for.
  StudySession {
    id: studySession
    store: dataStore
    onToastRequested: function(text) { root.toast(text) }
    onLaunchRequested: function(argv, note) { root.launch(argv, note) }
    onNoteAsked: function(card, prefill) { root.openNote(card, prefill) }
    onDeleteAsked: function(card) { root.confirmDeleteCard(card, function() { studySession.deleteCard(card) }) }
  }

  // ---- IPC: bin/omvida and the bar widget ----------------------------------------
  // The handler, for the tests: they call it as `qs ipc` would.
  readonly property alias ipc: ipc
  IpcHandler {
    id: ipc
    target: "omvida"
    function show(): void { }
    function home(): void { root.goTo("home") }
    function study(): void { root.goTo("study") }
    function wiki(): void { root.goTo("wiki") }
    function cards(): void { root.goTo("cards") }
    function graph(): void { root.goTo("graph") }
    function open(path: string): void { if (path !== "") navigator.openPage(path) }
    function search(text: string): void { root.openSearch(text) }
    // A card was written elsewhere (bin/omvida-deck-changed, from the study
    // repo's Claude Code hook): check the deck now rather than at the next poll.
    function deckChanged(): void { dataStore.deckPushed() }
  }

  function applyStart() {
    var cmd = Quickshell.env("OMVIDA_START") || "show"
    var arg = Quickshell.env("OMVIDA_START_ARG") || ""
    if (cmd === "open" && arg !== "") navigator.openPage(arg)
    else if (cmd === "search") root.openSearch(arg)
    else if (["home", "study", "wiki", "cards", "graph"].indexOf(cmd) !== -1) root.goTo(cmd)
    navigator.forgetHistory()
  }

  // Closing the window ends the app (Omvision's lesson: Quickshell otherwise
  // outlives its windows, and each launch left another one behind).
  // A finished session's pending log entry is written first, within
  // Config.quitDeadline.
  Connections {
    target: Quickshell
    function onLastWindowClosed() {
      if (!studySession.logPending) { Qt.quit(); return }
      quitDeadline.start()
      studySession.writeLog(function() { Qt.quit() })
    }
  }
  Timer { id: quitDeadline; interval: Config.quitDeadline; onTriggered: Qt.quit() }

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
        if (ctrl && event.key === Qt.Key_N) { root.toggleAdd(); event.accepted = true; return }
        if (ctrl && screenKeys[event.key] !== undefined) { root.goTo(screenKeys[event.key]); event.accepted = true; return }
        if (alt && event.key === Qt.Key_Left) { navigator.goBack(); event.accepted = true; return }
        if (alt && event.key === Qt.Key_Right) { navigator.goForward(); event.accepted = true; return }
        if (event.key === Qt.Key_Slash && !ctrl && !alt && navigator.currentScreen !== "study") {
          root.openSearch(""); event.accepted = true
        }
      }

      // Hiding a screen does not take the keyboard from it (Omvision's
      // lesson: typing then landed in the hidden journal). Every change of
      // screen takes it back here at once, then hands it to the new screen
      // a turn later, once that screen is visible and can hold it.
      Connections {
        target: navigator
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
        var parts = { app: root, study: studySession, studyView: studyScreen, wiki: wikiScreen, cardsScreen: cardsScreen,
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
        currentScreen: navigator.currentScreen
        dueCount: dataStore.overview ? dataStore.overview.pressure.flashcardsDue : 0
        onNavigate: function(screen) { root.goTo(screen) }
      }

      TopBar {
        id: topBar
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        status: dataStore.deck.failure !== "" ? dataStore.deck.failure : (dataStore.wiki.failure !== "" ? dataStore.wiki.failure : dataStore.status)
        onSearchRequested: root.openSearch("")
        onAddRequested: root.toggleAdd()
      }

      Item {
        id: screens
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: statusLine.top

        // The screen on show, for the status line.
        readonly property var current: ({ home: homeScreen, study: studyScreen, wiki: wikiScreen,
                                           cards: cardsScreen, graph: graphScreen })[navigator.currentScreen] || null

        HomeScreen {
          id: homeScreen
          anchors.fill: parent
          visible: navigator.currentScreen === "home"
          app: root
        }
        StudyScreen {
          id: studyScreen
          anchors.fill: parent
          visible: navigator.currentScreen === "study"
          app: root
          session: studySession
        }
        WikiScreen {
          id: wikiScreen
          anchors.fill: parent
          visible: navigator.currentScreen === "wiki"
          app: root
        }
        CardsScreen {
          id: cardsScreen
          anchors.fill: parent
          visible: navigator.currentScreen === "cards"
          app: root
        }
        GraphScreen {
          id: graphScreen
          anchors.fill: parent
          visible: navigator.currentScreen === "graph"
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
        screenName: navigator.currentScreen
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
        onClosed: root.focusScreen()
      }

      PageCardsDialog {
        id: pageCardsDialog
        anchors.fill: parent
        store: dataStore
        onClosed: root.focusScreen()
      }

      TopicDialog {
        id: topicDialog
        anchors.fill: parent
        app: root
        onClosed: root.focusScreen()
      }

      NoteDialog {
        id: noteDialog
        anchors.fill: parent
        app: root
        onClosed: root.focusScreen()
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
