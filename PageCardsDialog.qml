pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Cards.js" as Cards
import "Format.js" as Format

// A page's flashcards, the viewer's modal: an overview (fronts, each answer
// revealed on its own) or flip-through.
Modal {
  id: root

  required property Store store
  property var cards: []
  property string mode: "overview"
  cardWidth: Theme.pageMeasure + Theme.space3xl

  function open(title, cards) {
    root.title = "Cards · " + title
    root.cards = cards
    root.mode = "overview"
    root.opened = true
    keys.forceActiveFocus()
  }

  Row {
    spacing: Theme.spaceXs
    Chip { label: "Overview"; selected: root.mode === "overview"; onActivated: root.mode = "overview" }
    Chip { objectName: "pageCardsFlip"; label: "Flip through"; selected: root.mode === "flip"; onActivated: { root.mode = "flip"; flip.forceActiveFocus() } }
  }

  Item {
    id: keys
    width: Theme.hairlineWidth; height: Theme.hairlineWidth
    Keys.onEscapePressed: root.close()
  }

  // The scroller is wider than the column by the tiles' hover bleed, either
  // side, so a fill in the first or last column is not clipped flush at its
  // text (layout rule 3); the grid keeps to the column.
  GlideFlickable {
    visible: root.mode === "overview"
    x: -Theme.hoverBleed
    width: parent.width + Theme.hoverBleed * 2
    height: Math.min(grid.implicitHeight, root.height * 0.6)
    contentHeight: grid.implicitHeight
    ScrollBar.vertical: ScrollBar {}
    CardGrid {
      id: grid
      x: Theme.hoverBleed
      width: parent.width - Theme.hoverBleed * 2
      Repeater {
        model: root.mode === "overview" ? root.cards : []
        // A click shows the back in the front's place, and another the front.
        delegate: CardTile {
          id: cardItem
          required property var modelData
          property bool revealed: false
          objectName: "pageCardTile:" + cardItem.modelData.id
          width: grid.cellWidth
          height: grid.tileHeight
          card: cardItem.modelData
          caption: Cards.tileCaption(cardItem.modelData, true, !!root.store.notes[cardItem.modelData.id])
          text: Format.stripHtml(cardItem.revealed ? cardItem.modelData.back : cardItem.modelData.front)
          marked: cardItem.revealed
          onClicked: cardItem.revealed = !cardItem.revealed
        }
      }
    }
  }

  FlipThrough {
    id: flip
    visible: root.mode === "flip"
    width: parent.width
    height: Theme.cardFaceMinHeight * 2
    cards: root.cards
    Keys.onEscapePressed: root.close()
  }
}
