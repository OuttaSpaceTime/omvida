import QtQuick

import "Cards.js" as Cards
import "Format.js" as Format

// One card at a time: the front, a flip to the back (click, Space or Enter),
// ← and → (or h and l) to move, and a progress bar. The viewer's
// flip-through, for a page's cards (PageCardsDialog) and for the stage at
// the top of the deck explorer (CardsScreen).
//
// `stage` is the deck explorer's use, where the card is the one thing the
// screen shows:
//   - it stops at the ends instead of going round (past the last card there
//     is nothing left in the grid below),
//   - it draws no buttons of its own (the explorer's are quiet links, its
//     keys are in the window's status line),
//   - the card keeps one height (Theme.cardStageFaceHeight, so it ends with
//     the column beside it) and its text is centred: the front both ways and
//     large, the answer only up and down, since a list or a code block
//     centred line by line reads badly,
//   - it keeps its place: a new list that still holds the current card keeps
//     it current (and flipped). The explorer's list is rebuilt on every
//     refresh of the deck, behind the user's back whenever the window comes
//     to the front, and should not throw them back to the first card. The
//     place is an id set only by the moves below, not bound to `card`: a
//     binding would follow the index to whatever card a new list put there
//     and then "keep" that one.
// Without it (the page's cards dialog), a new list starts at its first card.
FocusScope {
  id: root

  property var cards: []
  property int index: 0
  property bool flipped: false
  property bool stage: false
  // On the stage, the height the whole flip-through should take (the deck
  // explorer gives the filter column's), so the card ends with the column
  // beside it; the card is never shorter than Theme.cardStageFaceHeight.
  property real stageHeight: 0
  readonly property real faceHeight: stage ? Math.max(Theme.cardStageFaceHeight, stageHeight - Theme.hairlineWidth * 2 - col.spacing) : 0
  // While the card turns over it is drawn as one picture (layer.enabled
  // below): re-rendering its rich text on every frame made it judder.
  readonly property bool moving: flipAnim.running
  property string placeId: ""
  readonly property real progress: cards.length ? (index + 1) / cards.length : 0
  readonly property var card: cards.length > 0 ? cards[Math.min(index, cards.length - 1)] : null

  implicitHeight: col.implicitHeight

  onCardsChanged: {
    var i = stage ? cards.findIndex(function(c) { return c.id === placeId }) : -1
    if (i === -1) forget()
    else index = i
  }

  // The stage's front in the largest size, from cardStageFrontSize down to
  // titleSize, that fits the face under its label: a long question shrinks
  // rather than growing the card or crowding the label.
  property int frontFit: Theme.cardStageFrontSize
  function fitFront() {
    if (!stage) return
    var room = faceHeight - frontFace.belowLabel - Theme.spaceXl
    var size = Theme.cardStageFrontSize
    for (; size > Theme.titleSize; size -= Theme.spaceXxs) {
      frontProbe.size = size
      if (frontProbe.implicitHeight <= room) break
    }
    frontFit = size
  }
  onCardChanged: Qt.callLater(fitFront)
  onFaceHeightChanged: Qt.callLater(fitFront)
  onWidthChanged: Qt.callLater(fitFront)

  // Make card i the current one, front up at once: turning back over from
  // the old card's answer would show the new card's answer on the way.
  property bool turning: false
  function show(i) {
    turning = true
    index = i
    flipped = false
    turning = false
    placeId = cards[i].id
  }

  function move(d) {
    if (cards.length === 0) return
    var i = index + d
    if (!stage) i = (i + cards.length) % cards.length
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

  // The current card is about to leave the list (the explorer deleted it):
  // move the place to the card after it, or before it at the end, so the
  // list without it keeps the walk there instead of starting over. Front up at
  // once, as in show(): the deleted card should not turn over on its way
  // out.
  function leaveCurrent() {
    var next = cards[index + 1] || cards[index - 1]
    placeId = next ? next.id : ""
    turning = true
    flipped = false
    turning = false
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
      // On the stage the front fits the face (fitFront), so only a long
      // answer can make the card taller.
      height: root.stage ? Math.max(root.faceHeight, backCol.implicitHeight + Theme.spaceXl * 2)
                         : Math.max(Theme.cardFaceMinHeight, Math.max(frontCol.implicitHeight, backCol.implicitHeight) + Theme.spaceXl * 2)

      front: Rectangle {
        anchors.fill: parent
        layer.enabled: root.moving
        layer.smooth: true
        color: Theme.fill
        border.color: Theme.hairline
        border.width: Theme.borderWidth
        // The label stays at the top; on the stage the front sits in the middle
        // of what is left, never over the label. frontCol is only measured.
        Column {
          id: frontCol
          x: Theme.spaceXl; y: Theme.spaceXl
          width: parent.width - Theme.spaceXl * 2
          spacing: Theme.spaceMd
          SectionLabel { id: frontLabel; text: root.card ? root.card.deck + " · " + Cards.stateOf(root.card) : "" }
          Item { width: parent.width; height: frontFace.implicitHeight }
        }
        // On the stage the text is set left, ragged right, as a block with
        // the same wide margin either side: centred line by line, a long
        // question read as a shape rather than a sentence.
        CardFace {
          id: frontFace
          objectName: "flipFront"
          readonly property real inset: root.stage ? Theme.cardStageInset : Theme.spaceXl
          x: inset
          width: parent.width - inset * 2
          readonly property real belowLabel: frontCol.y + frontLabel.height + frontCol.spacing
          y: root.stage ? Math.max(belowLabel, (parent.height - implicitHeight) / 2) : belowLabel
          html: root.card ? root.card.front : ""
          size: root.stage ? root.frontFit : Theme.titleSize
        }
        // Unseen, the same front at a trial size: fitFront() measures with it.
        CardFace {
          id: frontProbe
          visible: false
          width: frontFace.width
          html: frontFace.html
        }
      }
      back: Rectangle {
        anchors.fill: parent
        layer.enabled: root.moving
        layer.smooth: true
        color: Theme.paper
        border.color: Theme.accentColor
        border.width: Theme.borderWidth
        Column {
          id: backCol
          x: root.stage ? Theme.cardStageInset : Theme.spaceXl
          y: root.stage ? Math.max(Theme.spaceXl, (parent.height - implicitHeight) / 2) : Theme.spaceXl
          width: parent.width - x * 2
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
        Behavior on angle {
          enabled: !root.turning
          NumberAnimation { id: flipAnim; duration: Theme.flipDuration; easing.type: Easing.InOutCubic }
        }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.forceActiveFocus(); root.flipped = !root.flipped } }
    }

    Row {
      visible: !root.stage
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
