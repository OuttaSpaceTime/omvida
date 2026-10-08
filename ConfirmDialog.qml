import QtQuick

// "Are you sure?" before something that cannot be undone: deleting a card
// (Del on the deck explorer's stage, or on the card being studied). The window keeps one, and a
// screen asks through app.confirm(title, quote, note, action, accept).
//
// What goes is quoted (`quote`, cut to a few lines), so the question names
// the thing rather than "this"; `note` says what else goes, kept apart so a
// long quote cannot push it out of the dialog. The action is the one filled button, in red;
// Cancel is quiet text after it, as in the topic dialog. Enter or y takes the
// action, Esc or n cancels, and so does a click on the scrim. Every other
// unmodified key is swallowed while it is open, so a stray arrow cannot move
// the screen under it.
//
// The status line asking (a red DELETE mode, ↵ delete, esc keep) came first
// and was rejected: easy to miss for a step that loses a card's history.
Modal {
  id: root
  objectName: "confirmDialog"

  property string quote: ""
  property string note: ""
  property string action: "Delete"
  property var acceptFn: null

  function open(title, quote, note, action, accept) {
    root.title = title
    root.quote = quote
    root.note = note
    root.action = action
    root.acceptFn = accept
    root.opened = true
    keys.forceActiveFocus()
  }

  function accept() {
    var f = root.acceptFn
    root.acceptFn = null
    root.close()
    if (f) f()
  }

  UiText {
    objectName: "confirmQuote"
    visible: root.quote !== ""
    width: parent.width
    wrapMode: Text.Wrap
    maximumLineCount: Theme.cardTileLines
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: root.quote
    lineHeight: Theme.proseLineHeight
  }

  UiText {
    visible: root.note !== ""
    width: parent.width
    wrapMode: Text.Wrap
    text: root.note
    font.pixelSize: Theme.bodySmallSize
    color: Theme.dim
  }

  Row {
    topPadding: Theme.spaceSm
    spacing: Theme.spaceSm
    ActionButton {
      objectName: "confirmAccept"
      filled: true
      fill: Theme.redText
      label: root.action
      onActivated: root.accept()
    }
    PlainButton { size: Theme.bodySize; objectName: "confirmCancel"; label: "Cancel"; onActivated: root.close() }
  }

  Item {
    id: keys
    Keys.onPressed: function(event) {
      if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Y) root.accept()
      else if (event.key === Qt.Key_Escape || event.key === Qt.Key_N) root.close()
      event.accepted = true
    }
  }
}
