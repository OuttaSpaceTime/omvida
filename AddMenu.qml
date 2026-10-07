pragma ComponentBehavior: Bound
import QtQuick

// The Add dropdown: a flashcard or a wiki entry. Each opens the topic dialog,
// which then opens Claude Code in kitty.
Rectangle {
  id: root

  property bool opened: false
  signal picked(string kind)

  function toggle() { root.opened = !root.opened }

  visible: opened
  z: 10
  width: Theme.menuWidth
  height: col.implicitHeight + Theme.spaceSm * 2
  color: Theme.paper
  border.color: Theme.border
  border.width: Theme.borderWidth

  // Clicks outside close it.
  MouseArea {
    parent: root.parent
    anchors.fill: parent
    visible: root.opened
    z: 9
    onClicked: root.opened = false
  }

  Column {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: Theme.spaceSm

    Repeater {
      model: [
        { kind: "flashcard", label: "Flashcards", icon: "cards", note: "/study-flashcard" },
        { kind: "wiki", label: "Wiki entry", icon: "page", note: "/study-walkthrough --write" }
      ]
      delegate: Rectangle {
        id: addItem
        required property var modelData
        objectName: "add:" + addItem.modelData.kind
        width: col.width
        height: Theme.controlHeight + Theme.spaceSm
        color: itemArea.containsMouse ? Theme.hoverFill : "transparent"
        Row {
          anchors.left: parent.left
          anchors.leftMargin: Theme.spaceMd
          anchors.verticalCenter: parent.verticalCenter
          spacing: Theme.spaceSm
          Glyph { icon: addItem.modelData.icon; anchors.verticalCenter: parent.verticalCenter; color: Theme.accentColor }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            UiText { text: addItem.modelData.label }
            UiText { text: addItem.modelData.note; font.pixelSize: Theme.captionSize; color: Theme.faint }
          }
        }
        MouseArea {
          id: itemArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.opened = false; root.picked(addItem.modelData.kind) }
        }
      }
    }
  }
}
