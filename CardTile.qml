import QtQuick

import "Cards.js" as Cards

// A card in a grid, the Cards screen's and a page's (PageCardsDialog): its
// state's dot and a caption over a few lines of plain text, under a hairline.
// One tile for both, so a card looks the same wherever a grid shows it; the
// page's grid had a filled, bordered box of its own, and a wall of boxes is
// what Home's topic tiles were pulled back from.
//
// The text is plain (Format.stripHtml) and not the card's rich text: Qt
// elides only plain text, and a clipped rich-text face would cut a line in
// half. Flip-through and the Cards stage show a card whole. Its grid,
// CardGrid.qml, gives every tile a full one's height.
Item {
  id: root

  property var card: null
  property string caption: ""
  // The card's place in the grid, faint on the right; "" for none.
  property string number: ""
  property string text: ""
  // The text is the card's back (a page's tile, clicked): dimmer, and the
  // rule over the tile in the accent colour.
  property bool marked: false
  // CardGrid's unseen probe, a full tile its tiles' height is measured off.
  property bool full: false
  readonly property alias faceText: face.text

  signal clicked()

  implicitHeight: content.implicitHeight + Theme.spaceMd * 2

  // The hover fill bleeds into the column gap; the text keeps to the
  // column's edge (layout rule 3).
  Rectangle {
    x: -Theme.hoverBleed
    width: parent.width + Theme.hoverBleed * 2
    height: parent.height
    color: area.containsMouse ? Theme.hoverFill : "transparent"
  }
  Rectangle { width: parent.width; height: Theme.hairlineWidth; color: root.marked ? Theme.accentColor : Theme.hairline }

  Column {
    id: content
    y: Theme.spaceMd
    width: parent.width
    spacing: Theme.spaceXs
    Item {
      width: parent.width
      height: captionText.implicitHeight
      Rectangle {
        id: dot
        width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.card ? Theme.stateColor(Cards.stateOf(root.card)) : "transparent"
      }
      UiText {
        id: captionText
        x: dot.width + Theme.spaceSm
        width: parent.width - x - numberText.implicitWidth - Theme.spaceSm
        elide: Text.ElideRight
        text: root.full ? "X" : root.caption
        font.pixelSize: Theme.captionSize
        color: Theme.faint
      }
      UiText {
        id: numberText
        anchors.right: parent.right
        text: root.number
        font.pixelSize: Theme.captionSize
        color: Theme.faint
      }
    }
    UiText {
      id: face
      width: parent.width
      textFormat: Text.PlainText
      text: root.full ? new Array(Theme.cardTileLines).fill("X").join("\n") : root.text
      color: root.marked ? Theme.secondaryInk : Theme.ink
      font.pixelSize: Theme.bodySmallSize
      lineHeight: Theme.proseLineHeight
      wrapMode: Text.Wrap
      maximumLineCount: Theme.cardTileLines
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
