import QtQuick

// A leech: a card that keeps failing blocks the session until it is
// rewritten or split in Claude Code, deleted, or kept as is (flashcard-mcp
// leeches.ts). The session's `blocked` holds the card.
//
// Drawn as quietly as the card it replaces: the why in prose, the card
// between hairlines, and the decisions as plain words (PlainButton), not a
// row of boxes. The status line carries the mode (LEECH), the lapse count
// and the way on (Enter continues, Esc ends).
Column {
  id: root

  property var session: null
  spacing: Theme.spaceLg

  UiText {
    width: parent.width
    wrapMode: Text.Wrap
    text: root.session.blocked
      ? "This card has lapsed " + root.session.blocked.lapses + " times. A card failing this often is fighting you, not the concept: usually the front is too abstract to retrieve against. The session continues once you decide."
      : ""
    lineHeight: Theme.proseLineHeight
    color: Theme.secondaryInk
  }

  Rectangle { width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }
  CardFace { width: parent.width; html: root.session.blocked ? root.session.blocked.card.front : ""; size: Theme.subtitleSize }
  CardFace { width: parent.width; html: root.session.blocked ? root.session.blocked.card.back : ""; color: Theme.dim }
  Rectangle { width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }

  // The decisions, pulled left so the first word sits on the page's edge.
  Row {
    x: -rewrite.inset
    spacing: Theme.spaceSm
    PlainButton { id: rewrite; objectName: "leechRewrite"; label: "rewrite in claude"; tint: Theme.accentColor; onActivated: root.session.leechFix("rewrite") }
    PlainButton { objectName: "leechSplit"; label: "split in claude"; onActivated: root.session.leechFix("split") }
    PlainButton { objectName: "leechKeep"; label: "keep as is"; onActivated: root.session.leechResolve("resolveLeech", "kept as is") }
    PlainButton { objectName: "leechDrop"; label: "delete"; tint: Theme.redText; onActivated: dropConfirm.visible = true }
  }
  Row {
    id: dropConfirm
    visible: false
    spacing: Theme.spaceSm
    UiText { text: "Delete this card and its history?"; font.pixelSize: Theme.bodySmallSize; color: Theme.redText; anchors.verticalCenter: parent.verticalCenter }
    PlainButton { objectName: "leechDropConfirm"; label: "delete"; tint: Theme.redText; onActivated: { dropConfirm.visible = false; root.session.leechResolve("deleteCard", "deleted") } }
    PlainButton { label: "cancel"; onActivated: dropConfirm.visible = false }
  }
  Row {
    x: -cont.inset
    spacing: Theme.spaceXs
    PlainButton { id: cont; objectName: "leechContinue"; keys: "↵"; label: "continue"; anchors.verticalCenter: parent.verticalCenter; onActivated: root.session.loadNext() }
    UiText {
      text: "after fixing it in Claude Code"
      font.pixelSize: Theme.captionSize
      color: Theme.faint
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
