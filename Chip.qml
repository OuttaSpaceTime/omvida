import QtQuick

// A filter chip: a label, an optional count and colour dot, selected or not.
//
// In the Glance style an unselected chip is just its words, with a hover fill
// to say it is clickable, and the selected one is outlined in the accent like
// the overlay's verdict chip. A row of boxed chips, each with its own border,
// had read as a toolbar louder than what it filters; one outline among plain
// words says which is chosen with a single line.
//
// As PlainButton: the words start at the chip's own left edge, so a row of
// chips lines up with the text around it; the fill and outline reach
// chipInset past the words on both sides, and the width keeps that much
// after them as the gap to the next chip.
Item {
  id: root

  property string label: ""
  property int count: -1
  property color dot: "transparent"
  property bool selected: false
  signal activated()

  implicitHeight: Theme.smallControlHeight
  implicitWidth: row.implicitWidth + Theme.chipInset * 2
  opacity: enabled ? 1 : 0.45

  Rectangle {
    x: -Theme.chipInset
    width: row.implicitWidth + Theme.chipInset * 2
    height: parent.height
    color: !root.selected && area.containsMouse ? Theme.hoverFill : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: Theme.borderWidth
  }

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.spaceXs
    Rectangle {
      visible: root.dot.a > 0
      width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2
      color: root.dot
      anchors.verticalCenter: parent.verticalCenter
    }
    UiText {
      text: root.label
      font.pixelSize: Theme.bodySmallSize
      color: root.selected ? Theme.accentColor : Theme.dim
      anchors.verticalCenter: parent.verticalCenter
    }
    UiText {
      visible: root.count >= 0
      text: root.count
      font.pixelSize: Theme.captionSize
      font.weight: Font.Medium
      color: root.selected ? Theme.accentColor : Theme.faint
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: area
    x: -Theme.chipInset
    width: row.implicitWidth + Theme.chipInset * 2
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
