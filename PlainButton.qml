import QtQuick
import QtQuick.Controls

// The app's quiet button: only its words (and an optional icon), with a
// hover fill and no border. The key that does the same thing, if given, comes
// first in bold ("⇧↵ reveal"), so a status-line hint and the click target it
// stands for read alike. Bordered and filled buttons are ActionButton's.
//
// The button is as wide as its words, so a quiet button lines up with the
// text around it (layout rule 2) wherever it is placed, at a left edge or,
// anchored right, at a right one; the hover fill reaches `inset` past the
// words on both sides, beyond the button's bounds. A row of them sets its own
// spacing, at least Theme.spaceLg so two fills do not overlap. The width
// once kept an inset after the words as that gap, and every button anchored
// right needed a flag to drop it.
Item {
  id: root

  property string keys: ""
  property string label: ""
  property string icon: ""
  property string tip: ""
  property color tint: Theme.secondaryInk
  // A control's height and body type: a quiet action beside an ActionButton
  // (Cancel, the top bar's Add), so the pair sits on one line.
  property bool large: false
  property int size: large ? Theme.bodySize : Theme.bodySmallSize
  // False makes it a legend: the same words, no hover and no click. The
  // status line uses it for a key the mouse has no use for (⇧1-4 once the
  // keycaps are on screen).
  property bool interactive: true
  readonly property int inset: Theme.spaceSm
  signal activated()

  readonly property bool hovered: area.containsMouse

  implicitHeight: large ? Theme.controlHeight : Theme.smallControlHeight
  implicitWidth: row.implicitWidth
  opacity: enabled ? 1 : 0.45

  Rectangle {
    id: fill
    x: -root.inset
    width: row.implicitWidth + root.inset * 2
    height: parent.height
    color: root.hovered && root.enabled && root.interactive ? Theme.hoverFill : "transparent"
  }

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    // A key sits close to its label ("⇧↵ reveal"); an icon needs more air.
    spacing: root.icon !== "" ? Theme.spaceSm : Theme.spaceXs
    Glyph {
      visible: root.icon !== ""
      icon: root.icon
      anchors.verticalCenter: parent.verticalCenter
      font.pixelSize: root.size
      color: root.tint
    }
    UiText {
      visible: root.keys !== ""
      text: root.keys
      font.pixelSize: root.size
      font.bold: true
      color: Theme.ink
    }
    UiText {
      visible: root.label !== ""
      text: root.label
      font.pixelSize: root.size
      color: root.tint
    }
  }

  MouseArea {
    id: area
    anchors.fill: fill
    hoverEnabled: true
    enabled: root.enabled && root.interactive
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }

  ToolTip.visible: root.tip !== "" && area.containsMouse
  ToolTip.delay: Theme.tooltipDelay
  ToolTip.text: root.tip
}
