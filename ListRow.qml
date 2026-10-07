import QtQuick

// A row in a page list: a title, an optional topic chip and a right-aligned
// note, its hover fill bleeding to the list's edges (Omvision's rule 3).
// `dot` marks the row with a small coloured dot, the Glance overlay's "next
// up" rows. It hangs in the margin left of the text, as a selection bar does,
// so the title still starts on the shared left edge (rule 2).
Rectangle {
  id: root

  property string title: ""
  property string topic: ""
  property string note: ""
  property string badge: ""
  property color dot: "transparent"
  property int inset: 0
  signal activated()

  height: Theme.listRowHeight
  color: area.containsMouse ? Theme.hoverFill : "transparent"

  Rectangle {
    visible: root.dot.a > 0
    x: root.inset - Theme.spaceMd - Theme.dotSize
    anchors.verticalCenter: parent.verticalCenter
    width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2
    color: root.dot
  }

  Row {
    id: left
    anchors.left: parent.left
    anchors.leftMargin: root.inset
    anchors.right: right.left
    anchors.rightMargin: Theme.spaceMd
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.spaceSm
    clip: true
    UiText {
      width: Math.min(implicitWidth, left.width - (chip.visible ? chip.width + Theme.spaceSm : 0))
      text: root.title
      elide: Text.ElideRight
      anchors.verticalCenter: parent.verticalCenter
    }
    UiText {
      id: chip
      visible: root.topic !== ""
      text: root.topic.split("/")[0]
      font.pixelSize: Theme.captionSize
      color: Theme.topicColor(root.topic)
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  Row {
    id: right
    anchors.right: parent.right
    anchors.rightMargin: root.inset
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.spaceMd
    UiText {
      visible: root.badge !== ""
      text: root.badge
      font.pixelSize: Theme.captionSize
      color: Theme.accentColor
    }
    UiText {
      visible: root.note !== ""
      text: root.note
      font.pixelSize: Theme.captionSize
      color: Theme.faint
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
