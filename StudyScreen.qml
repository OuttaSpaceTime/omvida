import QtQuick
import QtQuick.Controls

import "Format.js" as Format
import "StatusBits.js" as StatusBits
import "bar/Model.js" as Overview

// The Study screen: a view over the session (StudySession.qml, which App.qml
// owns). The card, a leech and the summary are components of their own; this
// file places them and tells the window's status line (StatusLine.qml) the
// mode, where the session is, the keys that work now and what needs a look,
// so the card is the only thing on the screen.
Item {
  id: root

  required property App app
  required property StudySession session
  property alias answerField: card.answerField

  // The window's focusScreen() calls this when Study is shown or an overlay
  // over it closes.
  function takeFocus() {
    if (!root.visible) return false
    if (root.session.inCard) card.focusAnswer()
    else keyCatcher.forceActiveFocus()
    return true
  }
  Connections {
    target: root.session
    // A card takes the keyboard into its answer box; a leech, the summary
    // and an error into keyCatcher, for Enter and Esc. The answer box hides
    // in those phases, and a hidden item's focus goes nowhere useful.
    function onPhaseChanged() {
      var p = root.session.phase
      if (p === "answering" || p === "blocked" || p === "done" || p === "error") Qt.callLater(root.takeFocus)
    }
    // Not on every "revealed": a grade coming in under the note dialog must not
    // take the keyboard from it. A card back from an undo was asked for, by key.
    function onAnswerRestored() { Qt.callLater(root.takeFocus) }
  }

  // The summary's log entry is written once it is no longer shown: by then
  // any page opened from it is in the entry's Wiki explored line.
  readonly property bool showingSummary: visible && session.phase === "done"
  onShowingSummaryChanged: if (!showingSummary) session.writeLog()

  // ---- the status line ---------------------------------------------------------------
  // StatusLine.qml has the contract. The position and deck are segments; the
  // pressure verdict, new cards held back and the Anki sync are alerts. The
  // queue's review/new split is left out: the position's total already says
  // how much is left.
  readonly property string phase: root.session.phase

  // Study's keys and pressure are its session's, not the reading screens'
  // ctrl+K, ctrl+N and back (StatusLine.qml).
  readonly property bool statusShared: false
  readonly property string statusMode: {
    switch (phase) {
    case "syncing": return "SYNC"
    case "blocked": return "LEECH"
    case "done": return "DONE"
    case "error": return "ERROR"
    }
    if (root.session.isCode && root.session.picked === 0) return "CODE"
    return root.session.backShown ? "RATE" : "STUDY"
  }
  readonly property color statusModeColor: {
    if (phase === "blocked") return Theme.orangeText
    if (phase === "error") return Theme.redText
    if (root.session.backShown && root.session.suggestion) return Theme.ratingColor(root.session.suggestion.rating)
    return Theme.accentColor
  }

  readonly property var statusSegments: {
    var s = root.session
    if (s.cardShown && s.next && s.card) {
      let out = []
      let pos = Format.position(s.next)
      if (pos !== "") out.push({ text: pos, color: Theme.ink })
      out.push({ text: s.card.deck })
      if (s.next.repeat) out.push({ text: "repeat" })
      if (s.isCode && s.code.gaveUp) out.push({ text: "the solution", color: Theme.orangeText })
      if (root.app.store.notes[s.card.id]) out.push({ text: "noted", color: Theme.accentColor })
      return out
    }
    switch (phase) {
    case "idle":
      let due = root.app.store.overview ? root.app.store.overview.pressure.flashcardsDue : 0
      return [{ text: Format.plural(due, "card") + " due" }]
    case "syncing": return [{ text: "syncing with anki…" }]
    case "starting": case "loading": return [{ text: "starting…" }]
    case "blocked": return s.blocked ? [{ text: "lapsed " + s.blocked.lapses + " times", color: Theme.orangeText }, { text: s.blocked.card.deck }] : []
    case "error": return [{ text: "something went wrong", color: Theme.redText }]
    case "done":
      let d = s.summaryData
      if (!d || d.reviews === 0) return [{ text: "nothing reviewed" }]
      let done = [{ text: Format.plural(d.cards, "card"), color: Theme.ink }]
      if (d.minutes !== null) done.push({ text: Format.durationText(d.minutes) })
      done.push({ text: "accuracy " + Format.pct(d.accuracy) })
      return done
    }
    return []
  }

  // The status line names one key, the one that lists the others: Study's
  // keys change with every phase, and a row of them under the card was more
  // to read than the card. The list (KeyHelp.qml) is `keyList`, whose rows
  // run what their keys do.
  readonly property var statusHints: [{ keys: "alt+?", label: "keys", run: function() { keysHelp.open() } }]
  readonly property var keyList: {
    var s = root.session
    var discuss = { keys: "ctrl+D", label: "discuss", run: function() { s.discuss() } }
    var skip = { keys: "ctrl+S", label: "skip", run: function() { s.skip() } }
    var note = { keys: "ctrl+N", label: "note", run: function() { s.note() } }
    var check = { keys: "ctrl+Q", label: "check quality", run: function() { s.checkCard() } }
    var end = { keys: "esc", label: "end", run: function() { s.endNow() } }
    var del = { keys: "del", label: "delete", run: function() { s.askDelete() } }
    // On a card both are always listed, so the keys can be found before the
    // slip they are for: hidden until there was a rating to take back, the list
    // of a session's first card didn't have them, and looked like they were
    // missing. With none to take, a row is a legend, not a button (the key says
    // so in a toast). With an answer typed Ctrl+Z is the box's (StudyKeys.js),
    // so it isn't listed as a rating's. A leech or the summary has no card to
    // redo on, and offers undo only when it would do something.
    var cardKeys = [discuss, note, check, skip, end, del]
    var undoRow = { keys: "ctrl+Z", label: "undo rating" }
    if (s.canUndo) undoRow.run = function() { s.undo() }
    var redoRow = { keys: "ctrl+shift+Z", label: "redo rating" }
    if (s.canRedo) redoRow.run = function() { s.redo() }
    var history = phase === "answering" && s.hasTyped ? [] : [undoRow, redoRow]
    var undoOnly = s.canUndo ? [undoRow] : []
    // A code card has no rating to choose, on purpose: see StudySession.
    if (s.isCode && phase === "answering") {
      let block = s.code.blockFocused
      let several = s.card.exercise.answers > 1
      // Which blank has the keyboard says what Enter and Tab do (CodeBlank.qml).
      // The rows with no `run` are a legend: they are keys for typing.
      let rows = [{ keys: block ? "shift+enter" : "enter, shift+enter", label: "check", run: function() { s.code.check() } }]
      if (block) rows.push({ keys: "enter", label: "new line, indented" },
                           { keys: "tab", label: "indent" },
                           { keys: "shift+tab", label: "outdent" })
      if (several) rows.push({ keys: block ? "ctrl+tab" : "tab", label: "next blank" })
      let giveUp = { keys: "ctrl+G", label: "give up" }
      if (s.code.canGiveUp) giveUp.run = function() { s.code.giveUp() }
      rows.push(giveUp)
      // With code typed, Ctrl+Z is the box's (StudyKeys.js), and worth saying so.
      let typing = s.hasTyped ? [{ keys: "ctrl+Z", label: "undo typing" }] : []
      return rows.concat(cardKeys, history, typing)
    }
    if (s.isCode && s.code.rating > 0)
      return [{ keys: "shift+enter", label: s.code.gaveUp ? "next, rated " + Format.ratingName(s.code.rating).toLowerCase() : "next", run: function() { s.submit(s.code.rating) } }]
        .concat(cardKeys, history)
    if (s.frontShown) return [
      { keys: "shift+enter", label: "reveal", run: function() { s.reveal(false) } },
      { keys: "alt+enter", label: "reveal+accept", run: function() { s.reveal(true) } },
      // The mouse has no Shift: a click reveals, where the keycaps are.
      { keys: "shift+1-4", label: "reveal and pick", run: function() { s.reveal(false) } }
    ].concat(cardKeys, history)
    if (root.session.backShown) {
      // shift+enter submits the rating in play: the pick, else claude's
      // suggestion, else good (StudyKeys.js). alt+enter stays for taking the
      // suggestion over a different pick, or waiting for it while it grades.
      let rows = []
      let picked = s.picked
      let suggested = s.suggestion ? s.suggestion.rating : 0
      let inPlay = picked || suggested || 3
      rows.push({ keys: "shift+enter", label: Format.ratingName(inPlay).toLowerCase(), run: function() { s.submit(inPlay) } })
      if (phase === "grading") rows.push({ keys: "alt+enter", label: s.acceptPending ? "taking claude's rating" : "take claude's rating", run: function() { s.acceptPending = true } })
      else if (suggested && suggested !== picked) rows.push({ keys: "alt+enter", label: "take " + Format.ratingName(suggested).toLowerCase(), run: function() { s.submit(suggested) } })
      // shift+1-4 is a legend here: the keycaps above are its buttons. The
      // first press picks, the second submits.
      return rows.concat([{ keys: "shift+1-4", label: "pick, twice to rate" }], cardKeys, history)
    }
    switch (phase) {
    case "idle": return [{ keys: "enter", label: "start", run: function() { s.start() } }]
    case "syncing": return [{ keys: "", label: "skip the sync", run: function() { s.skipSync() } }]
    case "blocked": return [{ keys: "enter", label: "continue", run: function() { s.loadNext() } }, end].concat(undoOnly)
    case "error": return [{ keys: "enter", label: "try again", run: function() { s.start() } }]
    case "done": return [
      { keys: "enter", label: "study again", run: function() { s.start() } },
      { keys: "", label: "wiki", run: function() { root.app.nav.setScreen("wiki") } },
      { keys: "", label: "home", run: function() { root.app.nav.setScreen("home") } }
    ].concat(undoOnly)
    }
    return []
  }

  // Pressure, from this session's start (or the deck overview before one),
  // shown only when it is not ok; new cards the server held back for it; and
  // the Anki sync's note, which a click repeats as a toast.
  readonly property var statusAlerts: {
    var s = root.session
    var pressure = s.info && s.info.pressure ? s.info.pressure
                 : (root.app.store.overview ? root.app.store.overview.pressure : null)
    var out = StatusBits.pressure(root.app, pressure, Overview.clearance(root.app.store.overview), Theme.verdictColor)
    if (s.info && s.info.newHeldBack > 0 && phase !== "done")
      out.push({ text: s.info.newHeldBack + " new held back", tip: "new cards held back while pressure is " + pressure.verdict })
    var note = s.syncNote
    if (note !== "") {
      let failed = note.indexOf("Anki sync failed") === 0
      out.push({ text: failed ? "sync ✕" : "synced", color: failed ? Theme.redText : Theme.dim, tip: note,
                 run: function() { root.app.toast(note) } })
    }
    return out
  }

  // Keys when no field has focus (blocked, done, idle): Enter starts or
  // continues, Esc ends a blocked session.
  Item {
    id: keyCatcher
    focus: true
    Keys.onPressed: function(event) { event.accepted = root.session.handleKey(event) }
  }

  // The column sits in the middle of the screen when it fits, as a prompt
  // would, and scrolls from the top when it does not.
  GlideFlickable {
    id: flick
    anchors.fill: parent
    contentHeight: Math.max(height, col.implicitHeight + Theme.space3xl * 2)
    ScrollBar.vertical: ScrollBar {}

    Column {
      id: col
      x: Theme.pageX(root.width)
      y: Math.max(Theme.space3xl, Math.round((flick.height - col.implicitHeight) / 2))
      width: Theme.pageWidth(root.width)
      spacing: Theme.spaceXl

      // ---- idle / syncing / starting / error -------------------------------------
      Column {
        visible: root.phase === "idle" || root.session.opening || root.phase === "error"
        width: parent.width
        spacing: Theme.spaceLg
        ProgressPanel { width: parent.width; overview: root.app.store.overview; visible: root.phase === "idle" }
        UiText {
          visible: root.session.opening
          text: root.phase === "syncing" ? "Syncing with Anki…" : "Starting…"
          color: Theme.dim
        }
        UiText {
          visible: root.phase === "error"
          width: parent.width
          wrapMode: Text.Wrap
          text: root.session.errorText
          color: Theme.redText
        }
        PlainButton {
          objectName: "startSessionButton"
          visible: root.phase === "idle" || root.phase === "error"
          keys: "enter"
          label: root.phase === "error" ? "try again" : "start a session"
          size: Theme.bodySize
          tint: Theme.accentColor
          onActivated: root.session.start()
        }
      }

      StudyCard {
        id: card
        objectName: "studyCard"
        width: parent.width
        session: root.session
      }

      LeechPanel {
        visible: root.phase === "blocked"
        width: parent.width
        session: root.session
      }

      SessionSummary {
        visible: root.phase === "done"
        width: parent.width
        session: root.session
        app: root.app
      }
    }
  }

  KeyHelp {
    id: keysHelp
    anchors.fill: parent
    keys: root.keyList
    onClosed: root.takeFocus()
  }
  Connections {
    target: root.session
    function onKeysWanted() { if (keysHelp.opened) keysHelp.close(); else keysHelp.open() }
  }
}
