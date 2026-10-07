import QtQuick

// A leech: a card that keeps failing blocks the session until it is
// rewritten or split in Claude Code, deleted, or kept as is (flashcard-mcp
// leeches.ts). The session's `blocked` holds the card.
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
  }
  Rectangle {
    width: parent.width
    height: leechCol.implicitHeight + Theme.spaceLg * 2
    color: Theme.fill
    border.color: Theme.hairline
    border.width: Theme.borderWidth
    Column {
      id: leechCol
      x: Theme.spaceLg
      y: Theme.spaceLg
      width: parent.width - Theme.spaceLg * 2
      spacing: Theme.spaceMd
      CardFace { width: parent.width; html: root.session.blocked ? root.session.blocked.card.front : ""; size: Theme.subtitleSize }
      Rectangle { width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }
      CardFace { width: parent.width; html: root.session.blocked ? root.session.blocked.card.back : ""; color: Theme.secondaryInk }
    }
  }
  Row {
    spacing: Theme.spaceSm
    ActionButton { objectName: "leechRewrite"; filled: true; icon: "pencil"; label: "Rewrite in Claude"; onActivated: root.session.leechFix("rewrite") }
    ActionButton { objectName: "leechSplit"; label: "Split in Claude"; onActivated: root.session.leechFix("split") }
    ActionButton { objectName: "leechDrop"; label: "Delete"; tint: Theme.redText; onActivated: dropConfirm.visible = true }
    ActionButton { objectName: "leechKeep"; label: "Keep as is"; onActivated: root.session.leechResolve("resolveLeech", "kept as is") }
  }
  Row {
    id: dropConfirm
    visible: false
    spacing: Theme.spaceSm
    UiText { text: "Delete this card and its history?"; font.pixelSize: Theme.bodySmallSize; color: Theme.redText; anchors.verticalCenter: parent.verticalCenter }
    ActionButton { objectName: "leechDropConfirm"; small: true; label: "Delete"; tint: Theme.redText; onActivated: { dropConfirm.visible = false; root.session.leechResolve("deleteCard", "deleted") } }
    ActionButton { small: true; label: "Cancel"; onActivated: dropConfirm.visible = false }
  }
  Row {
    spacing: Theme.spaceSm
    ActionButton { objectName: "leechContinue"; label: "Continue"; hint: "Enter"; onActivated: root.session.loadNext() }
    UiText {
      text: "after fixing it in Claude Code"
      font.pixelSize: Theme.captionSize
      color: Theme.faint
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
