import QtQuick
import QtQuick.Controls

import "Launch.js" as Launch
import "Format.js" as Format

// Add → Flashcards / Wiki entry: name a topic, and Claude Code opens in kitty
// in the study repo with the skill and the topic. The topic starts as what is
// on screen (the open page's title, the card being studied), and that is also
// passed along as context, so "cards on this" is one Enter away.
//
// Styled as the rest of the app now is: the topic is typed on a line, not in
// a box (the study answer's prompt), and the footer is one filled action with
// Cancel as quiet text after it. The "Enter" the action used to print is the
// default every dialog has; Esc cancels.
Modal {
  id: root

  property var app: null
  property string kind: "flashcard"   // flashcard | wiki
  property string context: ""

  title: kind === "wiki" ? "New wiki entry" : "New flashcards"

  function open(k, topic, context) {
    root.kind = k
    var t = topic, c = context
    if (t === "" && c === "" && app) {
      var s = app.currentScreen
      if (s === "wiki" && app.wikiPath !== "" && app.store.pagesByPath[app.wikiPath]) {
        t = app.store.pagesByPath[app.wikiPath].title
        c = "wiki page [[" + app.wikiPath + "]]"
      } else if (s === "study" && app.currentCard) {
        t = ""
        c = "flashcard " + app.currentCard.id + ": " + Format.stripHtml(app.currentCard.front)
      }
    }
    field.text = t
    root.context = c
    root.opened = true
    field.forceActiveFocus()
    field.selectAll()
  }

  function submit() {
    var topic = field.text.trim()
    if (topic === "" && root.context === "") return
    var argv = root.kind === "wiki"
      ? Launch.skillArgv(Paths.studyDir, "Omvida · New wiki page", "/study-walkthrough --write", topic, root.context)
      : Launch.skillArgv(Paths.studyDir, "Omvida · New flashcards", "/study-flashcard", topic, root.context)
    root.close()
    root.app.launch(argv, "Opened Claude Code in kitty")
  }

  onClosed: if (app) app.focusScreen()

  UiText {
    width: parent.width
    wrapMode: Text.Wrap
    text: root.kind === "wiki"
      ? "Opens Claude Code with /study-walkthrough --write: it calibrates to what you know, then writes the page."
      : "Opens Claude Code with /study-flashcard: it suggests a few card fronts on the topic, and you pick which to create."
    font.pixelSize: Theme.bodySmallSize
    color: Theme.dim
  }

  TextField {
    id: field
    objectName: "topicField"
    width: parent.width
    placeholderText: "Topic"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.bodySize
    color: Theme.ink
    placeholderTextColor: Theme.faint
    leftPadding: 0
    background: Item {
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.hairlineWidth
        color: field.activeFocus ? Theme.accentColor : Theme.border
      }
    }
    Keys.onReturnPressed: root.submit()
    Keys.onEnterPressed: root.submit()
    Keys.onEscapePressed: root.close()
  }

  Row {
    visible: root.context !== ""
    width: parent.width
    spacing: Theme.spaceSm
    UiText {
      width: parent.width - clear.width - Theme.spaceSm
      text: "Context: " + root.context
      elide: Text.ElideRight
      font.pixelSize: Theme.captionSize
      color: Theme.faint
      anchors.verticalCenter: parent.verticalCenter
    }
    ActionButton { id: clear; small: true; quiet: true; icon: "close"; tip: "Leave the context out"; onActivated: root.context = "" }
  }

  Row {
    topPadding: Theme.spaceSm
    spacing: Theme.spaceSm
    ActionButton {
      objectName: "topicSubmit"
      filled: true
      label: "Open in Claude Code"
      onActivated: root.submit()
    }
    ActionButton { quiet: true; label: "Cancel"; onActivated: root.close() }
  }
}
