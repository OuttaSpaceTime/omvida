import QtQuick

// A modal card over a scrim, as Omvision's dialogs: square, a 2px border,
// dialogWidth wide. Esc and a click on the scrim close it. Children go in its
// column (`content`).
Item {
  id: root

  property bool opened: false
  property string title: ""
  property int cardWidth: Theme.dialogWidth
  default property alias content: body.data
  signal closed()

  function close() { root.opened = false; root.closed() }

  visible: opened
  z: 30

  Rectangle {
    anchors.fill: parent
    color: Theme.scrim
    MouseArea { anchors.fill: parent; onClicked: root.close() }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.min(root.cardWidth, root.width - Theme.spaceXl * 2)
    height: Math.min(col.implicitHeight + Theme.spaceXl * 2, root.height - Theme.spaceXl * 2)
    color: Theme.paper
    border.color: Theme.border
    border.width: Theme.dialogBorderWidth
    MouseArea { anchors.fill: parent } // clicks inside stay inside

    Column {
      id: col
      anchors.fill: parent
      anchors.margins: Theme.spaceXl
      spacing: Theme.spaceLg
      UiText {
        text: root.title
        visible: root.title !== ""
        font.pixelSize: Theme.titleSize
        font.bold: true
      }
      Column {
        id: body
        width: parent.width
        spacing: Theme.spaceMd
      }
    }
  }
}
