import QtQuick

import "Cards.js" as Cards
import "Format.js" as Format

// A card in a grid: the front, and the back under it once clicked.
Rectangle {
  id: root

  property var card: null
  property bool revealed: false

  height: tcol.implicitHeight + Theme.spaceLg * 2
  color: area.containsMouse ? Theme.hoverFill : Theme.fill
  border.color: revealed ? Theme.accentColor : Theme.hairline
  border.width: Theme.borderWidth

  Column {
    id: tcol
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
    CardFace { width: parent.width; html: root.card ? root.card.front : "" }
    Rectangle { visible: root.revealed; width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }
    CardFace { visible: root.revealed; width: parent.width; html: root.revealed && root.card ? root.card.back : ""; color: Theme.secondaryInk; size: Theme.bodySmallSize }
  }
  MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.revealed = !root.revealed }
}
