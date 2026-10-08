import QtQuick

// A button that is only its words: the key that does the same thing in bold,
// then what it does ("⇧↵ reveal"), with a hover fill and no border. The
// status line's hints are these, and so are the few actions the study
// screen's leech and summary still show, so a click target reads exactly
// like the key hint it stands for. ActionButton's box was the alternative;
// a row of those is what this screen set out to lose.
//
// The label is inset by `inset` on both sides; a caller that wants the words
// on the page's left edge pulls the button left by `inset` (layout rule 2).
Rectangle {
  id: root

  property string keys: ""
  property string label: ""
  property color tint: Theme.secondaryInk
  property int size: Theme.bodySmallSize
  // False makes it a legend: the same words, no hover and no click. The
  // status line uses it for a key the mouse has no use for (⇧1-4 once the
  // keycaps are on screen).
  property bool interactive: true
  readonly property int inset: Theme.spaceSm
  signal activated()

  readonly property bool hovered: area.containsMouse

  implicitHeight: Theme.smallControlHeight
  implicitWidth: row.implicitWidth + root.inset * 2
  color: hovered && enabled && interactive ? Theme.hoverFill : "transparent"
  opacity: enabled ? 1 : 0.45

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Theme.spaceXs
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
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.enabled && root.interactive
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
