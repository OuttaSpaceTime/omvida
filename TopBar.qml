import QtQuick

// The bar over every screen: back, the search box (a button that opens the
// palette, so typing never happens in two places), a status note, and Add.
Rectangle {
  id: root

  property string status: ""
  property bool canGoBack: false
  signal searchRequested()
  signal backRequested()
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

  ActionButton {
    id: back
    objectName: "backButton"
    anchors.left: parent.left
    anchors.leftMargin: Theme.spaceLg
    anchors.verticalCenter: parent.verticalCenter
    icon: "back"
    enabled: root.canGoBack
    onActivated: root.backRequested()
  }

  Rectangle {
    id: searchBox
    objectName: "searchBox"
    anchors.left: back.right
    anchors.leftMargin: Theme.spaceMd
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(Theme.paletteWidth, root.width - back.width - add.width - Theme.space4xl * 2)
    height: Theme.controlHeight
    color: searchArea.containsMouse ? Theme.hoverFill : Theme.fill
    border.color: Theme.hairline
    border.width: Theme.borderWidth

    Row {
      anchors.left: parent.left
      anchors.leftMargin: Theme.spaceMd
      anchors.right: kbdHint.left
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
    UiText {
      id: kbdHint
      anchors.right: parent.right
      anchors.rightMargin: Theme.spaceMd
      anchors.verticalCenter: parent.verticalCenter
      text: "Ctrl+K"
      font.pixelSize: Theme.captionSize
      color: Theme.faint
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

  ActionButton {
    id: add
    objectName: "addButton"
    anchors.right: parent.right
    anchors.rightMargin: Theme.spaceLg
    anchors.verticalCenter: parent.verticalCenter
    icon: "plus"
    label: "Add"
    hint: "Ctrl+N"
    onActivated: root.addRequested()
  }
}
