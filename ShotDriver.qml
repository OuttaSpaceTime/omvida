import QtQuick
import Quickshell

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
    else if (a === "answer") { study.start(); answerLater.text = arg || "It stays fresh for sixty seconds"; answerLater.start() }
    else if (a === "pagecards") driver.wiki.openPageCards()
    // On Cards: page the stage forward n cards (default 3) as → would, or
    // flip its card as Space would.
    else if (a === "cardsnext") { for (var n = parseInt(arg || "3"); n > 0; n--) driver.cardsScreen.page(1) }
    else if (a === "cardsflip") driver.cardsScreen.flipStage()
  }

  // Typing and revealing once the session has a card up.
  Timer {
    id: answerLater
    property string text: ""
    interval: 200
    repeat: true
    onTriggered: {
      var study = driver.study
      if (study.phase !== "answering") return
      stop()
      driver.studyView.answerField.text = text
      study.reveal(false)
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
