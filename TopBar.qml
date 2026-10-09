import QtQuick

// The bar over every screen: the search box (a button that opens the
// palette, so typing never happens in two places), a status note, and Add.
//
// Nothing here is boxed: Add is a quiet text button, and the search box is a
// faint fill with no border, a prompt rather than a field. Their keys
// (Ctrl+K, Ctrl+N) are named in the window's status line, not here. No back
// arrow: Alt+← goes back, and the status line offers "back" whenever there is
// history, so the arrow was a second way to do it that sat greyed out on
// every first screen.
Rectangle {
  id: root

  property string status: ""
  signal searchRequested()
  signal addRequested()

  height: Theme.topBarHeight
  color: Theme.paper

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Theme.hairlineWidth
    color: Theme.hairline
  }

  Rectangle {
    id: searchBox
    objectName: "searchBox"
    anchors.left: parent.left
    anchors.leftMargin: Theme.spaceLg
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(Theme.paletteWidth, root.width - add.width - Theme.space4xl * 2)
    height: Theme.controlHeight
    color: searchArea.containsMouse ? Theme.hoverFill : Theme.fill

    Row {
      anchors.left: parent.left
      anchors.leftMargin: Theme.spaceMd
      anchors.right: parent.right
      anchors.rightMargin: Theme.spaceMd
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.spaceSm
      clip: true
      Glyph { id: searchGlyph; icon: "search"; font.pixelSize: Theme.bodySize; color: Theme.faint; anchors.verticalCenter: parent.verticalCenter }
      UiText {
        width: parent.width - searchGlyph.width - Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter
        text: "Search the wiki and cards, or ask Claude"
        font.pixelSize: Theme.bodySmallSize
        color: Theme.faint
        elide: Text.ElideRight
      }
    }
    MouseArea {
      id: searchArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.IBeamCursor
      onClicked: root.searchRequested()
    }
  }

  UiText {
    anchors.left: searchBox.right
    anchors.leftMargin: Theme.spaceLg
    anchors.right: add.left
    anchors.rightMargin: Theme.spaceLg
    anchors.verticalCenter: parent.verticalCenter
    text: root.status
    font.pixelSize: Theme.captionSize
    color: Theme.redText
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignRight
  }

  PlainButton {
    id: add
    large: true
    objectName: "addButton"
    anchors.right: parent.right
    anchors.rightMargin: Theme.spaceLg
    anchors.verticalCenter: parent.verticalCenter
    icon: "plus"
    label: "Add"
    onActivated: root.addRequested()
  }
}
