import QtQuick

// A filter chip: a label, an optional count and colour dot, selected or not.
Rectangle {
  id: root

  property string label: ""
  property int count: -1
  property color dot: "transparent"
  property bool selected: false
  signal activated()

  implicitHeight: Theme.smallControlHeight
  implicitWidth: row.implicitWidth + Theme.spaceLg
  color: selected ? Theme.accentFill : (area.containsMouse ? Theme.hoverFill : "transparent")
  border.color: selected ? Theme.accentColor : Theme.hairline
  border.width: Theme.borderWidth

  Row {
    id: row
    anchors.centerIn: parent
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
      color: root.selected ? Theme.accentColor : Theme.secondaryInk
      anchors.verticalCenter: parent.verticalCenter
    }
    UiText {
      visible: root.count >= 0
      text: root.count
      font.pixelSize: Theme.captionSize
      color: Theme.faint
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    anchors.margins: -Theme.chipHitSlop
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
