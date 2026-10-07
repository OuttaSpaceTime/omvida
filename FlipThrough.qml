import QtQuick

import "Cards.js" as Cards
import "Format.js" as Format

// One card at a time: the front, a flip to the back (click, Space or Enter),
// ← and → (or h and l) to move, and a progress bar. The viewer's
// flip-through, for a page's cards (PageCardsDialog) and for the stage at
// the top of the deck explorer (CardsScreen).
//
// The two uses differ in a few switches, whose defaults are the dialog's:
// `wraps` (the dialog goes round; the explorer stops at the ends, because
// past its last card there is nothing left in the grid below), `controls`
// (the explorer draws its own quiet controls and puts the key hints in the
// window's status line), `frontSize`, and `keepPlace` (below).
FocusScope {
  id: root

  property var cards: []
  property int index: 0
  property bool flipped: false
  property bool wraps: true
  property bool controls: true
  property int frontSize: Theme.titleSize
  // With keepPlace, a new list that still holds the current card keeps it
  // current (and keeps it flipped): the deck explorer's list is rebuilt on
  // every refresh of the deck, which happens behind the user's back whenever
  // the window comes to the front, and should not throw them back to the
  // first card. Without it (the dialog), a new list starts at its first card.
  // The place is remembered as an id set only by the moves below, not bound
  // to `card`: a binding would follow the index to whatever card a new list
  // put there and then "keep" that one.
  property bool keepPlace: false
  property string placeId: ""
  readonly property real progress: cards.length ? (index + 1) / cards.length : 0
  readonly property var card: cards.length > 0 ? cards[Math.min(index, cards.length - 1)] : null
  readonly property bool atStart: index <= 0
  readonly property bool atEnd: index >= cards.length - 1

  implicitHeight: col.implicitHeight

  onCardsChanged: {
    var i = keepPlace ? Cards.indexOfId(cards, placeId) : -1
    if (i === -1) { index = 0; flipped = false; placeId = "" }
    else index = i
  }

  // Make card i the current one, front up.
  function show(i) {
    if (i < 0 || i >= cards.length) return
    index = i
    flipped = false
    placeId = cards[i].id || ""
  }

  function move(d) {
    if (cards.length === 0) return
    var i = index + d
    if (wraps) i = (i + cards.length) % cards.length
    else if (i < 0 || i >= cards.length) return
    show(i)
  }

  // Back to the first card and forget the place: the explorer calls it when
  // its filters change, since the place in the old list means nothing in
  // the new one even if the card happens to be in both.
  function forget() {
    placeId = ""
    index = 0
    flipped = false
  }

  // Unmodified keys only: Alt+←/→ is the app's history and Ctrl+L is not
  // ours either, and they reach the app because this handler passes them on.
  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.flipped = !root.flipped; event.accepted = true }
    else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) { root.move(1); event.accepted = true }
    else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) { root.move(-1); event.accepted = true }
  }

  Column {
    id: col
    width: parent.width
    spacing: Theme.spaceMd

    Rectangle {
      width: parent.width
      height: Theme.hairlineWidth * 2
      color: Theme.hairline
      Rectangle {
        height: parent.height
        width: root.cards.length ? parent.width * root.progress : 0
        color: Theme.accentColor
      }
    }

    Flipable {
      id: flipable
      objectName: "flipCard"
      width: parent.width
      height: Math.max(Theme.cardFaceMinHeight, Math.max(frontCol.implicitHeight, backCol.implicitHeight) + Theme.spaceXl * 2)

      front: Rectangle {
        anchors.fill: parent
        color: Theme.fill
        border.color: Theme.hairline
        border.width: Theme.borderWidth
        Column {
          id: frontCol
          x: Theme.spaceXl; y: Theme.spaceXl
          width: parent.width - Theme.spaceXl * 2
          spacing: Theme.spaceMd
          SectionLabel { text: root.card ? root.card.deck + " · " + Cards.stateOf(root.card) : "" }
          CardFace { objectName: "flipFront"; width: parent.width; html: root.card ? root.card.front : ""; size: root.frontSize }
        }
      }
      back: Rectangle {
        anchors.fill: parent
        color: Theme.paper
        border.color: Theme.accentColor
        border.width: Theme.borderWidth
        Column {
          id: backCol
          x: Theme.spaceXl; y: Theme.spaceXl
          width: parent.width - Theme.spaceXl * 2
          spacing: Theme.spaceMd
          SectionLabel { text: "Answer" }
          CardFace { width: parent.width; html: root.card ? root.card.back : "" }
          UiText {
            text: root.card ? "due " + root.card.dueDay + " · " + Format.plural(root.card.reps, "review") + " · " + Format.plural(root.card.lapses, "lapse") : ""
            font.pixelSize: Theme.captionSize
            color: Theme.faint
          }
        }
      }
      transform: Rotation {
        origin.x: flipable.width / 2
        origin.y: flipable.height / 2
        axis { x: 0; y: 1; z: 0 }  // check: allow-px the rotation axis, a unit vector
        angle: root.flipped ? 180 : 0
        Behavior on angle { NumberAnimation { duration: Theme.flipDuration; easing.type: Easing.InOutQuad } }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.forceActiveFocus(); root.flipped = !root.flipped } }
    }

    Row {
      visible: root.controls
      spacing: Theme.spaceMd
      ActionButton { small: true; label: "←"; onActivated: root.move(-1) }
      UiText {
        text: root.cards.length ? (root.index + 1) + " / " + root.cards.length : "no cards"
        font.pixelSize: Theme.bodySmallSize
        color: Theme.dim
        anchors.verticalCenter: parent.verticalCenter
      }
      ActionButton { small: true; label: "→"; onActivated: root.move(1) }
      UiText {
        text: "Space flips · ← → move"
        font.pixelSize: Theme.captionSize
        color: Theme.faint
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
