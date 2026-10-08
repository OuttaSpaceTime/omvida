pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "StatusBits.js" as StatusBits
import "bar/Model.js" as Overview

// The window's bottom line, the way helix or vim keep one: what mode the
// screen is in, where you are, the keys that work right now and anything
// that needs a look. It replaced Study's session line, its button rows and its
// footer of key hints, so the card has the screen to itself, and every screen
// gets the same place to say what its keys are.
//
// It draws whatever the current screen declares. The contract (also in
// docs/ui-spec.md), every property optional:
//
//   readonly property string statusMode      // "STUDY"; "" = the screen's name uppercased
//   readonly property color statusModeColor  // the mode block's fill; default Theme.accentColor
//   readonly property var statusSegments     // [{ text, color? }] left, after the mode
//   readonly property var statusHints        // [{ keys, label, run: function() {} }] clickable
//   readonly property var statusAlerts       // [{ text, color?, tip?, run? }] right edge
//
//   readonly property bool statusShared      // default true: see below
//
// A hint without `run` is drawn as a legend, not a button. A screen that
// declares none of these gets its name only (HOME, WIKI, CARDS, GRAPH).
// After a screen's own hints and alerts the line adds what every screen
// shares: ⌃K search, ⌃N add, alt+← back, and the pressure verdict while it
// is not ok (StatusBits.js). Study, whose keys and pressure are its
// session's, sets statusShared to false.
//
// The properties are read off a `var`, not typed, so a screen opts in by
// declaring them and nothing here has to know the screen's type.
//
// Narrow windows: the mode and the alerts always show, the segments clip,
// and the hints drop from the end, whole, rather than overlap (layout
// rule 7). So a screen lists its hints most important first.
Rectangle {
  id: root

  property var app: null
  property var screen: null
  property string screenName: ""

  function prop(name, fallback) {
    var s = root.screen
    if (!s || s[name] === undefined || s[name] === null) return fallback
    return s[name]
  }
  readonly property string mode: {
    var m = String(prop("statusMode", ""))
    return m !== "" ? m : root.screenName.toUpperCase()
  }
  readonly property color modeColor: prop("statusModeColor", Theme.accentColor)
  readonly property var segments: prop("statusSegments", [])
  readonly property bool shared: prop("statusShared", true)
  readonly property var hints: shared ? StatusBits.common(app, prop("statusHints", [])) : prop("statusHints", [])
  readonly property var alerts: shared && app
    ? prop("statusAlerts", []).concat(StatusBits.pressure(app, Overview.clearance(app.store.overview), Theme.verdictColor))
    : prop("statusAlerts", [])

  implicitHeight: Theme.statusLineHeight
  color: Theme.paper

  // How many hints fit, left to right, in what the mode, the segments and
  // the alerts leave. Read from the hints' own widths, never from the row
  // they sit in, whose width this decides.
  readonly property int hintsShown: {
    var room = root.width - modeBlock.width - segBox.width - alertRow.width - Theme.spaceSm * 2
    var used = 0
    for (var i = 0; i < hintRepeater.count; i++) {
      var it = hintRepeater.itemAt(i)
      if (!it) return i
      used += it.implicitWidth
      if (used > room) return i
    }
    return hintRepeater.count
  }

  Rectangle {
    id: modeBlock
    objectName: "statusMode"
    readonly property string text: root.mode
    height: parent.height
    width: modeText.implicitWidth + Theme.spaceMd * 2
    color: root.modeColor
    UiText {
      id: modeText
      anchors.centerIn: parent
      text: root.mode
      font.pixelSize: Theme.captionSize
      font.bold: true
      font.capitalization: Font.AllUppercase
      font.letterSpacing: Theme.labelTracking
      color: Theme.paper
    }
  }

  // Segments: where you are. Clipped, never pushed past the alerts.
  Item {
    id: segBox
    x: modeBlock.width
    height: parent.height
    width: Math.max(0, Math.min(segRow.implicitWidth, root.width - modeBlock.width - alertRow.width))
    clip: true
    Row {
      id: segRow
      height: parent.height
      Repeater {
        model: root.segments
        delegate: Item {
          id: segment
          required property var modelData
          required property int index
          objectName: "statusSegment:" + segment.index
          readonly property string text: segment.modelData.text
          height: segRow.height
          width: segText.implicitWidth + Theme.spaceMd * 2
          UiText {
            id: segText
            anchors.centerIn: parent
            text: segment.modelData.text
            font.pixelSize: Theme.captionSize
            color: segment.modelData.color !== undefined ? segment.modelData.color : Theme.dim
          }
          Rectangle {
            visible: segment.index < root.segments.length - 1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.hairlineWidth
            height: parent.height
            color: Theme.hairline
          }
        }
      }
    }
  }

  // Hints: the keys that work now, each also a button.
  Row {
    id: hintRow
    anchors.right: alertRow.left
    anchors.rightMargin: Theme.spaceSm
    height: parent.height
    Repeater {
      id: hintRepeater
      model: root.hints
      delegate: PlainButton {
        id: hint
        required property var modelData
        required property int index
        size: Theme.captionSize
        objectName: "statusHint:" + hint.modelData.label
        visible: hint.index < root.hintsShown
        height: hintRow.height
        keys: hint.modelData.keys || ""
        label: hint.modelData.label || ""
        interactive: typeof hint.modelData.run === "function"
        onActivated: hint.modelData.run()
      }
    }
  }

  // Alerts: what needs a look, each behind a hairline, its text in its own
  // colour; the tip on hover, the action (if any) on click.
  Row {
    id: alertRow
    anchors.right: parent.right
    height: parent.height
    Repeater {
      model: root.alerts
      delegate: Rectangle {
        id: alert
        required property var modelData
        required property int index
        objectName: "statusAlert:" + alert.index
        readonly property string text: alert.modelData.text
        readonly property bool clickable: typeof alert.modelData.run === "function"
        height: alertRow.height
        width: alertText.implicitWidth + Theme.spaceMd * 2
        color: alertArea.containsMouse && alert.clickable ? Theme.hoverFill : "transparent"
        Rectangle { width: Theme.hairlineWidth; height: parent.height; color: Theme.hairline }
        UiText {
          id: alertText
          anchors.centerIn: parent
          text: alert.modelData.text
          font.pixelSize: Theme.captionSize
          color: alert.modelData.color !== undefined ? alert.modelData.color : Theme.dim
        }
        MouseArea {
          id: alertArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: alert.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: if (alert.clickable) alert.modelData.run()
          ToolTip.visible: alertArea.containsMouse && (alert.modelData.tip || "") !== ""
          ToolTip.delay: Theme.tooltipDelay
          ToolTip.text: alert.modelData.tip || ""
        }
      }
    }
  }

  Rectangle {
    anchors.top: parent.top
    width: parent.width
    height: Theme.hairlineWidth
    color: Theme.hairline
  }
}
