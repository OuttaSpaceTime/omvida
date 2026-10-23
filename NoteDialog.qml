import QtQuick
import QtQuick.Controls

import "Format.js" as Format
import "NoteEdit.js" as NoteEdit

// A card's note: what to do about it later, written without leaving the
// session (Ctrl+N in Study; a click on a note on the Cards stage). An edit to
// make, something to understand better, anything: free markdown, kept with
// the card in the deck (flashcard-mcp's CardNote) until a fix session
// (Launch.fixNotesArgv, "fix all" on Home, "fix it" on Cards) resolves it.
// One per card, so noting a card again opens its note.
//
// The source is typed as markdown (NoteEdit.js: Enter carries a list on,
// Ctrl+B and Ctrl+I mark the selection) and rendered under it as it is
// typed. Ctrl+Enter saves, Esc leaves it as it was; a note emptied and saved
// is deleted, as is one deleted here. Saving writes through the deck server
// (Store.saveNote), the only note write the app makes; the deck reload that
// follows is how every list hears of it.
Modal {
  id: root
  objectName: "noteDialog"

  required property App app
  property var card: null
  // The card has a note: a binding, so a note resolved while the dialog is
  // up turns it back into a new one.
  readonly property bool existing: card !== null && !!app.store.notes[card.id]
  property bool saving: false

  title: existing ? "Note on this card" : "Note this card"
  cardWidth: Theme.noteDialogWidth

  // `prefill` starts a new note (the grader's flag, when there is one); an
  // existing note is opened as it is.
  function open(card, prefill) {
    if (!card) return
    var note = app.store.notes[card.id]
    root.card = card
    root.saving = false
    editor.text = note ? note.body : (prefill || "")
    root.opened = true
    editor.forceActiveFocus()
    editor.cursorPosition = editor.length
  }

  function save() {
    if (!root.card || root.saving) return
    var body = editor.text.trim()
    if (body === "" && !root.existing) { root.close(); return }
    root.saving = true
    app.store.saveNote(root.card.id, body, function(err) {
      root.saving = false
      if (err) { app.toast("note: " + err); return }
      root.close()
      app.toast(body === "" ? "Note deleted" : "Noted. Fix it later from Home or Cards")
    })
  }

  function remove() {
    editor.text = ""
    root.save()
  }

  function apply(e) {
    if (!e) return false
    editor.remove(e.from, e.to)
    editor.insert(e.from, e.insert)
    if (e.start === e.end) editor.cursorPosition = e.start
    else editor.select(e.start, e.end)
    return true
  }

  UiText {
    objectName: "noteCardFront"
    width: parent.width
    wrapMode: Text.Wrap
    maximumLineCount: 3
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: root.card ? Format.stripHtml(root.card.front) : ""
    font.pixelSize: Theme.bodySmallSize
    color: Theme.dim
  }

  // The source, on the code fill: it is markdown being typed, not the
  // rendered note, which is the preview's.
  Rectangle {
    width: parent.width
    height: Math.max(Theme.bodyMetrics.lineSpacing * 3, Math.min(editor.implicitHeight - Theme.spaceMd * 2, Theme.bodyMetrics.lineSpacing * Theme.noteEditorLines)) + Theme.spaceMd * 2
    color: Theme.codeFill
    Flickable {
      id: editorFlick
      anchors.fill: parent
      clip: true
      contentHeight: editor.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar {}
      TextArea.flickable: TextArea {
        id: editor
        objectName: "noteEditor"
        padding: Theme.spaceMd
        wrapMode: TextEdit.Wrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.bodySize
        color: Theme.ink
        placeholderText: "What should change, or what you want to understand"
        placeholderTextColor: Theme.faint
        selectByMouse: true
        background: null
        Keys.onPressed: function(event) {
          var ctrl = event.modifiers & Qt.ControlModifier
          var enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
          if ((ctrl && enter) || (ctrl && event.key === Qt.Key_S)) root.save()
          else if (event.key === Qt.Key_Escape) root.close()
          else if (ctrl && event.key === Qt.Key_B) root.apply(NoteEdit.wrap(editor.text, editor.selectionStart, editor.selectionEnd, "**"))
          else if (ctrl && event.key === Qt.Key_I) root.apply(NoteEdit.wrap(editor.text, editor.selectionStart, editor.selectionEnd, "*"))
          else if (enter && event.modifiers === Qt.NoModifier && editor.selectionStart === editor.selectionEnd) {
            if (!root.apply(NoteEdit.continueList(editor.text, editor.cursorPosition))) return
          } else return
          event.accepted = true
        }
      }
    }
  }

  // The note as it will read.
  Column {
    visible: editor.text.trim() !== ""
    width: parent.width
    spacing: Theme.spaceXs
    SectionLabel { text: "Preview" }
    UiText {
      objectName: "notePreview"
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.MarkdownText
      text: editor.text
      lineHeight: Theme.proseLineHeight
      font.pixelSize: Theme.bodySmallSize
      color: Theme.secondaryInk
    }
  }

  Item {
    width: parent.width
    height: Theme.controlHeight + Theme.spaceSm
    Row {
      anchors.bottom: parent.bottom
      spacing: Theme.spaceSm
      ActionButton {
        objectName: "noteSave"
        filled: true
        label: root.saving ? "Saving…" : "Save"
        onActivated: root.save()
      }
      Row {
        spacing: Theme.spaceXl
        PlainButton { large: true; label: "Cancel"; onActivated: root.close() }
        PlainButton {
          objectName: "noteDelete"
          visible: root.existing
          large: true
          label: "Delete note"
          tint: Theme.redText
          onActivated: root.remove()
        }
      }
    }
    UiText {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: Theme.controlHeight
      verticalAlignment: Text.AlignVCenter
      text: "markdown · ctrl+enter save · esc cancel"
      font.pixelSize: Theme.captionSize
      color: Theme.faint
    }
  }
}
