import QtQuick

import "Cards.js" as Cards
import "Format.js" as Format

// A card in a page's grid: the front, and the back in its place once
// clicked. Every tile is as tall as a full one (its caption and
// cardTileLines lines of text), so the grid is one of equal cards, as on the
// Cards screen, rather than a ragged wall. Tiles sized to their own text
// were what this had, and the back opening under the front made a clicked
// tile taller still. That is also why the face is plain text
// (Format.stripHtml) and not the card's rich text: Qt elides only plain
// text, and a clipped rich-text face would cut a line in half. Flip-through
// shows a card whole.
Rectangle {
  id: root

  property var card: null
  property bool revealed: false
  readonly property alias faceText: face.text

  height: fullTile.implicitHeight + Theme.spaceLg * 2
  color: area.containsMouse ? Theme.hoverFill : Theme.fill
  border.color: revealed ? Theme.accentColor : Theme.hairline
  border.width: Theme.borderWidth

  // The unseen full tile the height is measured off, so it follows the
  // theme's type without a typed height.
  Column {
    id: fullTile
    visible: false
    spacing: Theme.spaceSm
    UiText { text: "X"; font.pixelSize: Theme.captionSize }
    UiText {
      textFormat: Text.PlainText
      text: new Array(Theme.cardTileLines).fill("X").join("\n")
      lineHeight: Theme.proseLineHeight
    }
  }

  Column {
    x: Theme.spaceLg; y: Theme.spaceLg
    width: parent.width - Theme.spaceLg * 2
    spacing: Theme.spaceSm
    Row {
      spacing: Theme.spaceSm
      Rectangle { width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2; color: root.card ? Theme.stateColor(Cards.stateOf(root.card)) : "transparent"; anchors.verticalCenter: parent.verticalCenter }
      UiText {
        text: root.card ? root.card.deck + (root.card.lapses > 0 ? " · " + Format.plural(root.card.lapses, "lapse") : "") : ""
        font.pixelSize: Theme.captionSize
        color: Theme.faint
      }
    }
    UiText {
      id: face
      width: parent.width
      textFormat: Text.PlainText
      text: root.card ? Format.stripHtml(root.revealed ? root.card.back : root.card.front) : ""
      color: root.revealed ? Theme.secondaryInk : Theme.ink
      lineHeight: Theme.proseLineHeight
      wrapMode: Text.Wrap
      maximumLineCount: Theme.cardTileLines
      elide: Text.ElideRight
    }
  }
  MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.revealed = !root.revealed }
}
