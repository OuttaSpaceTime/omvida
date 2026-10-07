pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// A page's flashcards, the viewer's modal: an overview (fronts, each answer
// revealed on its own) or flip-through.
Modal {
  id: root

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
    spacing: Theme.spaceSm
    Chip { label: "Overview"; selected: root.mode === "overview"; onActivated: root.mode = "overview" }
    Chip { objectName: "pageCardsFlip"; label: "Flip through"; selected: root.mode === "flip"; onActivated: { root.mode = "flip"; flip.forceActiveFocus() } }
  }

  Item {
    id: keys
    width: Theme.hairlineWidth; height: Theme.hairlineWidth
    Keys.onEscapePressed: root.close()
  }

  GlideFlickable {
    visible: root.mode === "overview"
    width: parent.width
    height: Math.min(grid.implicitHeight, root.height * 0.6)
    contentHeight: grid.implicitHeight
    ScrollBar.vertical: ScrollBar {}
    Grid {
      id: grid
      width: parent.width
      columns: Math.max(1, Math.floor(width / Theme.cardGridCellWidth))
      readonly property real cellWidth: (width - spacing * (columns - 1)) / columns
      spacing: Theme.spaceMd
      Repeater {
        model: root.mode === "overview" ? root.cards : []
        delegate: CardTile {
          id: cardItem
          required property var modelData
          width: grid.cellWidth
          card: cardItem.modelData
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
