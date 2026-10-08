import QtQuick
import QtQuick.Controls

import "Format.js" as Format
import "StatusBits.js" as StatusBits
import "bar/Model.js" as Overview

// The Study screen: a view over the session (StudySession.qml, which omvida.qml
// owns). The card, a leech and the summary are components of their own; this
// file places them and tells the window's status line (StatusLine.qml) the
// mode, where the session is, the keys that work now and what needs a look,
// so the card is the only thing on the screen.
Item {
  id: root

  property var session: null
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
  // Between cards (loading) the line keeps the answering keys, so it does
  // not flicker through a third set on every card.
  readonly property bool answeringKeys: phase === "answering" || phase === "loading" || (phase === "submitting" && !root.session.backShown)

  // Study's keys and pressure are its session's, not the reading screens'
  // ⌃K, ⌃N and back (StatusLine.qml).
  readonly property bool statusShared: false
  readonly property string statusMode: {
    switch (phase) {
    case "syncing": return "SYNC"
    case "blocked": return "LEECH"
    case "done": return "DONE"
    case "error": return "ERROR"
    }
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
    if ((s.inCard || phase === "loading") && s.next && s.card) {
      var out = []
      var pos = Format.position(s.next)
      if (pos !== "") out.push({ text: pos, color: Theme.ink })
      out.push({ text: s.card.deck })
      if (s.next.repeat) out.push({ text: "repeat" })
      return out
    }
    switch (phase) {
    case "idle":
      var due = s.app.store.overview ? s.app.store.overview.pressure.flashcardsDue : 0
      return [{ text: Format.plural(due, "card") + " due" }]
    case "syncing": return [{ text: "syncing with anki…" }]
    case "starting": case "loading": return [{ text: "starting…" }]
    case "blocked": return s.blocked ? [{ text: "lapsed " + s.blocked.lapses + " times", color: Theme.orangeText }, { text: s.blocked.card.deck }] : []
    case "error": return [{ text: "something went wrong", color: Theme.redText }]
    case "done":
      var d = s.summaryData
      if (!d || d.reviews === 0) return [{ text: "nothing reviewed" }]
      var done = [{ text: Format.plural(d.cards, "card"), color: Theme.ink }]
      if (d.minutes !== null) done.push({ text: Format.durationText(d.minutes) })
      done.push({ text: "accuracy " + Format.pct(d.accuracy) })
      return done
    }
    return []
  }

  readonly property var statusHints: {
    var s = root.session
    var discuss = { keys: "⌃D", label: "discuss", run: function() { s.discuss() } }
    var skip = { keys: "⌃S", label: "skip", run: function() { s.skip() } }
    var end = { keys: "esc", label: "end", run: function() { s.endNow() } }
    if (answeringKeys) return [
      { keys: "⇧↵", label: "reveal", run: function() { s.reveal(false) } },
      { keys: "⌥↵", label: "reveal+accept", run: function() { s.reveal(true) } },
      // The mouse has no Shift: a click reveals, where the keycaps are.
      { keys: "⇧1-4", label: "rate", run: function() { s.reveal(false) } },
      discuss, skip, end
    ]
    if (root.session.backShown) {
      var first
      if (phase === "grading") first = { keys: "⌥↵", label: s.acceptPending ? "taking claude's rating" : "take claude's rating", run: function() { s.acceptPending = true } }
      else if (s.suggestion) first = { keys: "⌥↵", label: "take " + Format.ratingName(s.suggestion.rating).toLowerCase(), run: function() { s.submit(s.suggestion.rating) } }
      else first = { keys: "⇧↵", label: "good", run: function() { s.submit(3) } }
      // ⇧1-4 is a legend here: the keycaps above are its buttons.
      return [first, { keys: "⇧1-4", label: "rate" }, discuss, skip, end]
    }
    switch (phase) {
    case "idle": return [{ keys: "↵", label: "start", run: function() { s.start() } }]
    case "syncing": return [{ keys: "", label: "skip the sync", run: function() { s.skipSync() } }]
    case "blocked": return [{ keys: "↵", label: "continue", run: function() { s.loadNext() } }, end]
    case "error": return [{ keys: "↵", label: "try again", run: function() { s.start() } }]
    case "done": return [
      { keys: "↵", label: "study again", run: function() { s.start() } },
      { keys: "", label: "wiki", run: function() { s.app.setScreen("wiki") } },
      { keys: "", label: "home", run: function() { s.app.setScreen("home") } }
    ]
    }
    return []
  }

  // Pressure, from this session's start (or the deck overview before one),
  // shown only when it is not ok; new cards the server held back for it; and
  // the Anki sync's note, which a click repeats as a toast.
  readonly property var statusAlerts: {
    var s = root.session
    var pressure = s.info && s.info.pressure ? s.info.pressure
                 : (s.app.store.overview ? s.app.store.overview.pressure : null)
    var out = StatusBits.pressure(s.app, pressure, Overview.clearance(s.app.store.overview), Theme.verdictColor)
    if (s.info && s.info.newHeldBack > 0 && phase !== "done")
      out.push({ text: s.info.newHeldBack + " new held back", tip: "new cards held back while pressure is " + (pressure ? pressure.verdict : "high") })
    var note = s.syncNote
    if (note !== "") {
      var failed = note.indexOf("Anki sync failed") === 0
      out.push({ text: failed ? "sync ✕" : "synced", color: failed ? Theme.redText : Theme.dim, tip: note,
                 run: function() { s.app.toast(note) } })
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
        visible: root.phase === "idle" || root.phase === "syncing" || root.phase === "starting" || root.phase === "error"
        width: parent.width
        spacing: Theme.spaceLg
        ProgressPanel { width: parent.width; overview: root.session.app.store.overview; visible: root.phase === "idle" }
        UiText {
          visible: root.phase === "syncing" || root.phase === "starting"
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
        // Plain words, pulled left so they sit on the page's edge.
        PlainButton {
          id: startButton
          objectName: "startSessionButton"
          x: -startButton.inset
          visible: root.phase === "idle" || root.phase === "error"
          keys: "↵"
          label: root.phase === "error" ? "try again" : "start a session"
          size: Theme.bodySize
          tint: Theme.accentColor
          onActivated: root.session.start()
        }
      }

      StudyCard {
        id: card
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
      }
    }
  }
}
