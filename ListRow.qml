import QtQuick

// A row in a page list: a title, an optional topic chip and a right-aligned
// note, its hover fill bleeding to the list's edges (Omvision's rule 3).
Rectangle {
  id: root

  property string title: ""
  property string topic: ""
  property string note: ""
  property string badge: ""
  property int inset: 0
  signal activated()

  height: Theme.listRowHeight
  color: area.containsMouse ? Theme.hoverFill : "transparent"

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
