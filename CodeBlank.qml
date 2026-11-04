pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Exercise.js" as Exercise

// One blank in a code card: an underlined field in the code's own font, as
// wide as what is typed in it. Execute Program's and CodeRecall's way, the
// hidden part turned into a box. A whole editable listing was the prototype's,
// and left the rest of the code open to change by accident; here only the
// asked-for part takes the keyboard.
//
// Tab moves between blanks. A multi-line one is a block to write in, where Enter
// is a newline; in an inline one, Enter checks, as in Execute Program.
//
// A block indents as an editor does, two spaces at a time (Exercise.js has the
// rules): it starts at the body's indentation, Enter keeps the line's and goes
// one further after a line that opens something, an `end` comes back out, and
// Backspace takes an indent whole. So Tab is for indenting there, and Ctrl+Tab
// moves on, the first card asking for a body being one you can't tab through.
TextArea {
  id: root

  required property CodeCard card
  required property int blank
  property bool multiline: false
  readonly property StudySession session: root.card.session

  // The answer shown, the cursor after it, ready to go on from.
  function setAnswer(answer) {
    root.text = answer
    root.cursorPosition = root.length
  }

  function before() { return root.getText(0, root.cursorPosition) }

  function dropSelection() {
    if (root.selectedText !== "") root.remove(root.selectionStart, root.selectionEnd)
  }

  // Enter in a block.
  function newline() {
    root.dropSelection()
    var edit = Exercise.enterEdit(root.before())
    if (edit.dedent > 0) {
      let start = root.before().lastIndexOf("\n") + 1
      root.remove(start, start + edit.dedent)
    }
    root.insert(root.cursorPosition, edit.insert)
  }

  function indent() {
    root.dropSelection()
    root.insert(root.cursorPosition, Exercise.tabSpaces(root.before()))
  }

  function outdent() {
    var before = root.before()
    var count = Exercise.outdentCount(before, root.getText(root.cursorPosition, root.length))
    var start = before.lastIndexOf("\n") + 1
    if (count > 0) root.remove(start, start + count)
  }

  // Backspace within the indentation: true when it took the indent whole.
  function backspaceIndent() {
    if (root.selectedText !== "") return false
    var count = Exercise.backspaceCount(root.before())
    if (count < 2) return false
    root.remove(root.cursorPosition - count, root.cursorPosition)
    return true
  }

  objectName: "codeBlank:" + root.blank
  readOnly: root.session.phase !== "answering"
  padding: 0
  leftPadding: Theme.spaceXs
  rightPadding: Theme.spaceXs
  topPadding: 0
  bottomPadding: 0
  wrapMode: TextEdit.Wrap
  font.family: Theme.fontFamily
  font.pixelSize: Theme.bodySmallSize
  color: Theme.ink
  selectByMouse: true
  selectionColor: Theme.selectedFill
  background: Rectangle {
    color: root.activeFocus ? Theme.hoverFill : Theme.fill
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width
      height: Theme.borderWidth
      color: root.session.codeResult && root.session.codeResult.status === "pass" ? Theme.greenText : Theme.accentColor
    }
  }

  // Grows as it fills, from a size that says nothing of the answer's length, up
  // to what its card allows it (width), where it wraps. Measured apart from the
  // layout, as a wrapped contentWidth would depend on the width this decides. A
  // little over, so the measure's rounding can't wrap the last character.
  implicitWidth: Math.max(minWidth.advanceWidth, typedWidth.advanceWidth) + leftPadding + rightPadding + Theme.spaceXs
  implicitHeight: Math.max(contentHeight, root.multiline ? Theme.answerMinHeight : 0)
  TextMetrics {
    id: minWidth
    font: root.font
    text: "mmmmmmmm"
  }
  TextMetrics {
    id: typedWidth
    font: root.font
    text: root.text
  }

  Component.onCompleted: {
    root.setAnswer(root.session.codeAnswers[root.blank] || "")
    root.card.register(root)
  }
  Component.onDestruction: root.card.unregister(root)
  Connections {
    target: root.session
    function onCodeAnswersSet() { root.setAnswer(root.session.codeAnswers[root.blank] || "") }
  }

  onTextChanged: root.session.setCodeAnswer(root.blank, root.text)
  onActiveFocusChanged: if (activeFocus) {
    root.session.codeBlockFocused = root.multiline
    root.card.lastBlank = root.blank
  }
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      let back = event.key === Qt.Key_Backtab
      if (!root.multiline || (event.modifiers & Qt.ControlModifier)) root.card.focusNext(root.blank, back)
      else if (!root.readOnly) { if (back) root.outdent(); else root.indent() }
      event.accepted = true
    } else if (root.session.handleKey(event)) {
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      // An inline blank is one line: nothing a plain Enter could mean is left.
      // Nor in a block whose answer is settled, which only takes Shift+Enter now.
      if (root.multiline && !root.readOnly) root.newline()
      event.accepted = true
    } else if (event.key === Qt.Key_Backspace && root.multiline && !root.readOnly && event.modifiers === Qt.NoModifier) {
      event.accepted = root.backspaceIndent()
    }
  }
}
