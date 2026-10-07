import QtQuick

import "Cards.js" as Cards
import "Format.js" as Format

// One card at a time: the front, a flip to the back (click, Space or Enter),
// ← and → to move, and a progress bar. The viewer's flip-through, for a
// page's cards and for whatever the deck explorer's filters leave.
FocusScope {
  id: root

  property var cards: []
  property int index: 0
  property bool flipped: false
  readonly property real progress: cards.length ? (index + 1) / cards.length : 0
  readonly property var card: cards.length > 0 ? cards[Math.min(index, cards.length - 1)] : null

  onCardsChanged: { index = 0; flipped = false }

  function move(d) {
    if (cards.length === 0) return
    index = (index + d + cards.length) % cards.length
    flipped = false
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.flipped = !root.flipped; event.accepted = true }
    else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) { root.move(1); event.accepted = true }
    else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) { root.move(-1); event.accepted = true }
  }

  Column {
    anchors.fill: parent
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
          CardFace { width: parent.width; html: root.card ? root.card.front : ""; size: Theme.titleSize }
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
