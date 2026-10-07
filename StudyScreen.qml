import QtQuick
import QtQuick.Controls

import "Format.js" as Format

// The Study screen: a view over the session (StudySession.qml, which omvida.qml
// owns). The session line and the start state are here; the card, a leech and
// the summary are components of their own.
Item {
  id: root

  property var session: null
  property alias answerField: card.answerField

  function focusAnswer() {
    if (!root.visible) return
    if (root.session.inCard) card.focusAnswer()
    else keyCatcher.forceActiveFocus()
  }

  onVisibleChanged: if (visible) Qt.callLater(focusAnswer)
  Connections {
    target: root.session
    function onPhaseChanged() { if (root.session.phase === "answering") Qt.callLater(root.focusAnswer) }
  }

  // The summary's log entry is written once it is no longer shown: by then
  // any page opened from it is in the entry's Wiki explored line.
  readonly property bool showingSummary: visible && session.phase === "done"
  onShowingSummaryChanged: if (!showingSummary) session.writeLog()

  // Keys when no field has focus (blocked, done, idle): Enter starts or
  // continues.
  Item {
    id: keyCatcher
    focus: true
    Keys.onPressed: function(event) {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return
      var phase = root.session.phase
      if (phase === "idle" || phase === "done" || phase === "error") { root.session.start(); event.accepted = true }
      else if (phase === "blocked") { root.session.loadNext(); event.accepted = true }
    }
  }

  GlideFlickable {
    anchors.fill: parent
    contentHeight: col.implicitHeight + Theme.space3xl * 2
    ScrollBar.vertical: ScrollBar {}

    Column {
      id: col
      x: Theme.pageX(root.width)
      y: Theme.space3xl
      width: Theme.pageWidth(root.width)
      spacing: Theme.spaceXl

      // ---- the session line ----------------------------------------------------
      Item {
        width: parent.width
        height: Math.max(headLeft.implicitHeight, endButton.height)
        visible: root.session.phase !== "idle"
        Column {
          id: headLeft
          anchors.left: parent.left
          anchors.right: endButton.left
          anchors.rightMargin: Theme.spaceLg
          spacing: Theme.spaceXs
          UiText {
            objectName: "positionLine"
            text: root.session.inCard ? Format.positionLine(root.session.next)
                 : root.session.phase === "blocked" ? "Leech"
                 : root.session.phase === "done" ? "Session complete"
                 : root.session.phase === "error" ? "Something went wrong"
                 : root.session.phase === "syncing" ? "Syncing with Anki…" : "Starting…"
            font.pixelSize: Theme.titleSize
            font.bold: true
          }
          UiText {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: {
              if (!root.session.info || root.session.phase === "done") return root.session.syncNote
              var s = Format.plural(root.session.info.total, "card") + " (" + root.session.info.reviewCards + " review, " + root.session.info.newCards + " new)"
              if (root.session.info.newHeldBack > 0) s += " · " + root.session.info.newHeldBack + " new held back (pressure: " + root.session.info.pressure.verdict + ")"
              if (root.session.syncNote !== "") s += " · " + root.session.syncNote
              return s
            }
            font.pixelSize: Theme.captionSize
            color: Theme.dim
          }
        }
        ActionButton {
          id: endButton
          objectName: "endSessionButton"
          anchors.right: parent.right
          visible: root.session.inCard || root.session.phase === "blocked" || root.session.phase === "loading"
          small: true
          label: "End session"
          onActivated: root.session.endNow()
        }
      }

      // ---- idle / syncing / error --------------------------------------------------
      Column {
        visible: root.session.phase === "idle" || root.session.phase === "syncing" || root.session.phase === "starting" || root.session.phase === "error"
        width: parent.width
        spacing: Theme.spaceXl
        ProgressPanel { width: parent.width; overview: root.session.app.store.overview; visible: root.session.phase === "idle" }
        UiText {
          visible: root.session.phase === "error"
          width: parent.width
          wrapMode: Text.Wrap
          text: root.session.errorText
          color: Theme.redText
        }
        Row {
          spacing: Theme.spaceMd
          ActionButton {
            objectName: "startSessionButton"
            visible: root.session.phase === "idle" || root.session.phase === "error"
            filled: true
            label: root.session.phase === "error" ? "Try again" : "Start session"
            hint: "Enter"
            onActivated: root.session.start()
          }
          ActionButton {
            visible: root.session.phase === "syncing"
            label: "Skip the sync"
            onActivated: root.session.skipSync()
          }
        }
      }

      StudyCard {
        id: card
        width: parent.width
        session: root.session
      }

      LeechPanel {
        visible: root.session.phase === "blocked"
        width: parent.width
        session: root.session
      }

      SessionSummary {
        visible: root.session.phase === "done"
        width: parent.width
        session: root.session
      }
    }
  }
}
