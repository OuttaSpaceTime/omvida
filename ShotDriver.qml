import QtQuick
import Quickshell
import Quickshell.Io

// Screenshot driver, loaded only when OMVIDA_SHOT_DIR is set (bin/shot):
// puts the real app in one state, grabs PNGs and quits. Offscreen, against
// the sandbox's fixtures (bin/sandbox), so no window appears and no real data
// is touched. Omvision's ShotDriver.qml has the history of why.
Rectangle {
  id: driver

  // Handed over by omvida.qml (contentRoot.inject).
  property var app: null
  property var study: null
  property var studyView: null
  property var wiki: null
  property var searchPalette: null
  property var cardsScreen: null
  property var addMenu: null
  property Item target: null

  readonly property string outDir: Quickshell.env("OMVIDA_SHOT_DIR")
  readonly property string screen: Quickshell.env("OMVIDA_SHOT_SCREEN") || "home"
  readonly property string action: Quickshell.env("OMVIDA_SHOT_ACTION") || ""
  readonly property int settleMs: parseInt(Quickshell.env("OMVIDA_SHOT_SETTLE") || "2500")
  readonly property var frames: String(Quickshell.env("OMVIDA_SHOT_FRAMES") || "0")
                                  .split(",").map(function(s) { return parseInt(s) })
                                  .filter(function(n) { return n >= 0 })
  property int frameIndex: 0
  // The answer the study actions type (answer, accept); answer:<text> types its own.
  readonly property string sampleAnswer: "It stays fresh for sixty seconds"

  color: Theme.paper

  function nameFor(ms) {
    var base = driver.screen + (driver.action !== "" ? "-" + driver.action : "")
    return base.replace(/[^A-Za-z0-9_-]+/g, "_") + "-" + ms + "ms.png"
  }

  function applyScreen() {
    var s = driver.screen
    if (s.indexOf("wiki:") === 0) driver.app.openPage(s.slice(5), "")
    else if (s.indexOf("folder:") === 0) driver.app.openFolder(s.slice(7))
    else driver.app.setScreen(s)
  }

  // Actions put the app in a state a click or key would. Study actions run a
  // session on the sandbox's deck.
  function runAction() {
    var a = driver.action, arg = ""
    var i = a.indexOf(":")
    if (i !== -1) { arg = a.slice(i + 1); a = a.slice(0, i) }
    var study = driver.study
    if (a === "search") driver.app.openSearch(arg || "csrf")
    else if (a === "ask") { driver.app.openSearch(arg || "What is an origin?"); driver.searchPalette.ask() }
    else if (a === "add") driver.app.openAdd(arg || "flashcard", "", "")
    else if (a === "addmenu") driver.addMenu.opened = true
    else if (a === "study") study.start()
    // An answer typed and revealed; with accept, then rated `arg` (default
    // Good) once Claude's verdict is in, to catch the rating's moment with -f.
    else if (a === "answer" || a === "accept") {
      let text = a === "answer" && arg || driver.sampleAnswer
      study.start()
      whenPhase.run("answering", function() {
        driver.studyView.answerField.text = text
        driver.study.reveal(false)
        if (a === "accept") whenPhase.run("revealed", function() { driver.study.submit(parseInt(arg || "3")) })
      })
    }
    else if (a === "pagecards") driver.wiki.openPageCards()
    // On Cards: page the stage forward n cards (default 3) as → would, or
    // flip its card as Space would.
    else if (a === "cardsnext") { for (let n = parseInt(arg || "3"); n > 0; n--) driver.cardsScreen.page(1) }
    else if (a === "cardsflip") driver.cardsScreen.flipStage()
    // On Cards: pick tags (comma-separated) as a click on each would; or
    // open the tag panel, picking any tags given first. Filters only read.
    else if (a === "cardstags" || a === "cardspanel") {
      arg.split(",").filter(function(t) { return t !== "" }).forEach(function(t) { driver.cardsScreen.addTag(t) })
      if (a === "cardspanel") driver.cardsScreen.openTags()
    }
    // Del's dialog on Cards or on a study card, open; the shot never answers
    // it, so nothing is deleted.
    else if (a === "cardsdelete") driver.cardsScreen.askDelete()
    else if (a === "studydelete") { study.start(); whenPhase.run("answering", function() { driver.study.askDelete() }) }
    else if (a === "done") { study.start(); rateAll.start() }
    else if (a === "keys") { study.start(); whenPhase.run("answering", function() { driver.study.keysWanted() }) }
    else if (a === "graphlocal") driver.app.openGraph(true)
    // On a wiki page: fold the side panel, open the graph rail, or both
    // (panels:side, panels:graph, panels:side,graph), as `[` and `]` would.
    else if (a === "panels") {
      let which = (arg || "side,graph").split(",")
      if (which.indexOf("side") !== -1) driver.wiki.sideOpen = false
      if (which.indexOf("graph") !== -1) driver.wiki.graphOpen = true
    }
    else if (a === "syncfail") { study.start(); whenPhase.run("answering", function() { driver.study.syncNote = "Anki sync failed: offline (fixture)" }) }
    else if (a === "leech") leechDeck.running = (Quickshell.env("OMVIDA_SANDBOX") || "") !== ""
    // The note dialog over a study card, with `arg` (or a sample) typed in;
    // the shot never saves it.
    else if (a === "note") {
      study.start()
      whenPhase.run("answering", function() {
        driver.studyView.answerField.text = "half an answer"
        driver.app.openNote(driver.study.card, arg || "Split it:\n- what **max-age** counts from\n- what happens after\n\nAnd why not `Expires`?")
      })
    }
    // Notes and a past session in the sandbox deck, as Study and Claude Code
    // would leave them: Home's past sessions, and on Cards (notes:cards) the
    // "noted" filter picked. Refused under -R.
    else if (a === "notes") notesDeck.running = (Quickshell.env("OMVIDA_SANDBOX") || "") !== ""
    // The wiki panel's "From study" list: the first three pages, as a
    // finished session would leave them, and the first one open. Memory only.
    else if (a === "studypages") {
      let pages = driver.app.store.wikiIndex.pages.slice(0, 3).map(function(p) { return { path: p.path, title: p.title, lapsed: 0 } })
      pages[1].lapsed = 1
      driver.app.addStudyPages(pages)
      driver.app.openPage(pages[0].path, "")
    }
  }

  Process {
    id: notesDeck
    command: ["python3", Paths.root + "/tests/fixtures/seed_deck.py", Quickshell.env("FLASHCARD_DB") || "", "--notes"]
    onRunningChanged: if (!running) {
      driver.app.store.refreshDeck()
      if (driver.action === "notes:cards") driver.cardsScreen.setFilter("noted", true)
    }
  }

  // Rating every card Good until the queue is empty: the summary.
  Timer {
    id: rateAll
    interval: 100
    repeat: true
    onTriggered: {
      var study = driver.study
      if (study.phase === "done") stop()
      else if (study.phase === "answering") study.submit(3)
    }
  }

  // A leech, as tests/app/tst_leech.qml makes one: the CSRF card at six
  // lapses and the only one due, rated, so the next card is blocked. Only
  // ever on the sandbox's deck (bin/sandbox sets OMVIDA_SANDBOX; bin/shot -R
  // refuses this action).
  Process {
    id: leechDeck
    command: ["python3", "-c",
      "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); "
      + "c.execute(\"UPDATE Card SET lapses = 6 WHERE id = 'fixturecard0003'\"); "
      + "c.execute(\"UPDATE Card SET due = '2099-01-01T00:00:00.000+00:00' WHERE id != 'fixturecard0003'\"); c.commit()",
      Quickshell.env("FLASHCARD_DB") || ""]
    // Not onExited: its QProcess::ExitStatus parameter is a type qmllint
    // cannot see (the baselined warnings elsewhere).
    onRunningChanged: if (!running) { driver.study.start(); whenPhase.run("answering", function() { driver.study.submit(3) }) }
  }

  // Once the session reaches `phase`, `then` runs: with a card up
  // ("answering"), typing and revealing an answer, a failed sync's note (the
  // fixtures have no sync script, so a real failure cannot happen here) or
  // the rating that blocks on a leech; with the back up ("revealed"), a
  // rating. `then` may wait for the next phase in turn: the timer has
  // stopped before it runs.
  Timer {
    id: whenPhase
    property string phase: ""
    property var then: null
    function run(p, fn) { phase = p; then = fn; start() }
    interval: 50
    repeat: true
    onTriggered: {
      if (driver.study.phase !== phase) return
      stop()
      then()
    }
  }

  Timer {
    id: settle
    interval: driver.settleMs
    running: driver.app !== null
    onTriggered: {
      driver.applyScreen()
      actionTimer.start()
    }
  }
  Timer {
    id: actionTimer
    interval: 400
    onTriggered: { if (driver.action !== "") driver.runAction(); grabTimer.start() }
  }
  Timer {
    id: grabTimer
    interval: driver.frames[driver.frameIndex] || (driver.action === "" ? 300 : 1500)
    onTriggered: driver.grab()
  }

  function grab() {
    var ms = driver.frames[driver.frameIndex] || 0
    var path = driver.outDir + "/" + driver.nameFor(ms)
    driver.target.grabToImage(function(result) {
      result.saveToFile(path)
      console.info("[omvida-shot] " + path)
      driver.frameIndex++
      if (driver.frameIndex < driver.frames.length) {
        grabTimer.interval = Math.max(1, driver.frames[driver.frameIndex] - ms)
        grabTimer.start()
      } else Qt.quit()
    })
  }
}
