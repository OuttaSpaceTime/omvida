pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Format.js" as Format

// One card of a study session, drawn for the keyboard: no button rows and no
// hint footer, those are the status line's (StudyScreen.qml fills it).
//
//   answering   the front, large; under it a borderless prompt, `›` and the
//               answer box
//   revealed    the front cut to a dim recap; a two-column box, what you
//               typed beside the back; Claude's verdict as one line; and the
//               four rating keycaps, the suggested one outlined
//
// All state is the session's (StudySession.qml).
Column {
  id: root

  property var session: null
  property alias answerField: answer
  spacing: root.revealedLayout ? Theme.spaceXl : Theme.space2xl

  // The answer box keeps the keyboard while a card is up, so typing starts at
  // once and the rating keys always reach it.
  function focusAnswer() { answer.forceActiveFocus() }

  readonly property bool showCard: root.session.inCard || root.session.phase === "loading"
  // Grading, revealed, and a rating on its way after a reveal. A rating
  // given straight from the answer (Shift+1-4) keeps the answering layout
  // until the next card.
  readonly property bool revealedLayout: root.session.phase === "grading" || root.session.phase === "revealed"
    || (root.session.phase === "submitting" && root.session.revealedAt > 0)

  Binding { target: root.session; property: "answer"; value: answer.text }
  Connections {
    target: root.session
    function onAnswerReset() { answer.text = "" }
  }

  // The previous card's result: one faint line, so a rating is seen to land.
  Row {
    objectName: "lastResult"
    visible: root.session.lastResult !== null && root.session.inCard
    width: parent.width
    spacing: Theme.spaceSm
    Rectangle { width: Theme.selectionBarWidth; height: lastText.implicitHeight; color: root.session.lastResult ? Theme.ratingColor(root.session.lastResult.rating) : "transparent" }
    UiText {
      id: lastText
      width: parent.width - Theme.selectionBarWidth - Theme.spaceSm
      elide: Text.ElideRight
      text: root.session.lastResult ? root.session.lastResult.line + (root.session.lastResult.overridden ? " (your call)" : "") + "  ·  " + root.session.lastResult.front : ""
      font.pixelSize: Theme.captionSize
      color: Theme.faint
    }
  }

  UiText {
    visible: root.showCard && root.session.next !== null && !!root.session.next.leech
    width: parent.width
    wrapMode: Text.Wrap
    text: root.session.next && root.session.next.leech
      ? "This card has lapsed " + root.session.next.leech.lapses + " times. Answer it as usual; after the rating you decide what to do with it."
      : ""
    font.pixelSize: Theme.bodySmallSize
    color: Theme.orangeText
  }

  // ---- the front ---------------------------------------------------------------------
  Column {
    visible: root.showCard && !root.revealedLayout
    width: parent.width
    spacing: Theme.spaceMd
    CardFace {
      objectName: "cardFront"
      width: parent.width
      html: root.session.card ? root.session.card.front : ""
      size: Theme.cardFrontSize
      opacity: root.session.phase === "loading" ? 0.4 : 1
    }
    Row {
      visible: root.session.card !== null && root.session.card.tags.length > 0
      spacing: Theme.spaceSm
      Repeater {
        model: root.session.card ? root.session.card.tags : []
        delegate: UiText {
          id: tagItem
          required property var modelData
          text: "#" + tagItem.modelData
          font.pixelSize: Theme.captionSize
          color: Theme.faint
        }
      }
    }
  }

  // Once revealed, the front is only a reminder of the question: plain
  // text, a few lines at most, so the answer and the back get the room.
  UiText {
    objectName: "cardRecap"
    visible: root.showCard && root.revealedLayout
    width: parent.width
    text: root.session.card ? Format.stripHtml(root.session.card.front) : ""
    wrapMode: Text.Wrap
    maximumLineCount: Theme.recapLines
    elide: Text.ElideRight
    lineHeight: Theme.proseLineHeight
    font.pixelSize: Theme.bodySmallSize
    color: Theme.dim
  }

  // ---- the answer, and the back beside it ------------------------------------------
  // One box for both layouts, so the answer field is the same item before
  // and after the reveal and never loses the keyboard: the rating keys after
  // a reveal reach the session through it. Hiding it and handing the keys to
  // another item was the alternative; a key pressed in the same instant as
  // the reveal (Shift+Enter, then Alt+Enter) would have gone nowhere.
  //
  // Answering, it is a prompt: `›` and the field, no border. Revealed, it
  // splits in two behind a hairline: "› you" over the field (read-only now),
  // and "back" over the card's back on a faint fill. Only x, y, width and
  // visibility change between the two, never the anchors (layout rule 6).
  Item {
    id: answerBox
    visible: root.showCard
    width: parent.width
    readonly property bool split: root.revealedLayout
    readonly property int pad: split ? Theme.spaceLg : 0
    readonly property int half: split ? Math.floor(width / 2) : width
    readonly property int promptWidth: split ? 0 : promptGlyph.implicitWidth + Theme.spaceMd
    height: split ? Math.max(answer.y + answer.height, backCol.y + backCol.implicitHeight) + pad : answer.height

    Rectangle {
      visible: answerBox.split
      x: answerBox.half
      width: parent.width - answerBox.half
      height: parent.height
      color: Theme.fill
    }
    Rectangle {
      visible: answerBox.split
      x: answerBox.half
      width: Theme.hairlineWidth
      height: parent.height
      color: Theme.hairline
    }
    Rectangle {
      visible: answerBox.split
      anchors.fill: parent
      color: "transparent"
      border.color: Theme.hairline
      border.width: Theme.borderWidth
    }

    UiText {
      id: promptGlyph
      visible: !answerBox.split
      text: "›"
      font.pixelSize: Theme.answerSize
      font.bold: true
      color: Theme.accentColor
    }
    UiText {
      id: youCaption
      visible: answerBox.split
      x: answerBox.pad
      y: answerBox.pad
      text: "› you"
      font.pixelSize: Theme.captionSize
      color: Theme.dim
    }

    TextArea {
      id: answer
      objectName: "answerField"
      x: answerBox.split ? answerBox.pad : answerBox.promptWidth
      y: answerBox.split ? answerBox.pad + youCaption.implicitHeight + Theme.spaceSm : 0
      width: answerBox.split ? answerBox.half - answerBox.pad * 2 : answerBox.width - answerBox.promptWidth
      height: answerBox.split ? implicitHeight : Math.max(Theme.answerMinHeight, implicitHeight)
      // All four: the Basic style adds to the left of `padding`, which put
      // the answer a few pixels right of its "› you" caption.
      padding: 0
      leftPadding: 0
      rightPadding: 0
      readOnly: root.session.phase !== "answering"
      wrapMode: TextEdit.Wrap
      font.family: Theme.fontFamily
      font.pixelSize: answerBox.split ? Theme.bodySize : Theme.answerSize
      color: answerBox.split ? Theme.secondaryInk : Theme.ink
      placeholderText: root.session.phase === "answering" ? "answer, or leave empty" : "(nothing typed)"
      placeholderTextColor: Theme.faint
      selectByMouse: true
      background: null
      Keys.onPressed: function(event) { if (root.session.handleKey(event)) event.accepted = true }
    }

    Column {
      id: backCol
      visible: answerBox.split
      x: answerBox.half + answerBox.pad
      y: answerBox.pad
      width: answerBox.width - answerBox.half - answerBox.pad * 2
      spacing: Theme.spaceSm
      UiText {
        text: "back"
        font.pixelSize: Theme.captionSize
        color: Theme.dim
      }
      CardFace {
        objectName: "cardBack"
        width: parent.width
        html: root.session.card ? root.session.card.back : ""
        size: Theme.bodySize
      }
    }
  }

  // ---- Claude's verdict -----------------------------------------------------------
  // One line, the verdict in its rating's colour and the reason after it, as
  // the grader gave it. StyledText, so the two run on as one paragraph; the
  // reason is escaped, being Claude's text. `verdict` and `reason` are the
  // plain parts, for the tests.
  Column {
    objectName: "suggestionBox"
    visible: root.revealedLayout && (root.session.phase === "grading" || root.session.suggestion !== null || root.session.gradeError !== "")
    width: parent.width
    spacing: Theme.spaceSm

    UiText {
      id: verdictLine
      objectName: "suggestionLine"
      readonly property var suggestion: root.session.suggestion
      readonly property string verdict: root.session.phase === "grading" ? "claude: grading…"
        : suggestion ? "claude: " + Format.ratingName(suggestion.rating).toLowerCase()
        : "claude: no rating"
      readonly property string reason: root.session.phase === "grading" ? (root.session.acceptPending ? "its rating is taken when it arrives" : "")
        : suggestion ? suggestion.reason
        : root.session.gradeError
      readonly property color verdictColor: root.session.phase === "grading" ? Theme.dim
        : suggestion ? Theme.ratingColor(suggestion.rating) : Theme.redText
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.StyledText
      lineHeight: Theme.proseLineHeight
      font.pixelSize: Theme.bodySmallSize
      color: Theme.secondaryInk
      text: "<b><font color=\"" + verdictColor + "\">" + Format.escapeHtml(verdict) + "</font></b>"
        + (reason !== "" ? " — " + Format.escapeHtml(reason) : "")
    }

    // A card the grader flagged (two questions in one, a vague front): a
    // quiet line, and Claude Code to fix it. The button's width is reserved,
    // the text takes the rest (layout rule 4).
    Row {
      visible: root.session.suggestion !== null && root.session.suggestion.quality !== null
      width: parent.width
      spacing: Theme.spaceSm
      Glyph { id: issueGlyph; icon: "alert"; color: Theme.orangeText; font.pixelSize: Theme.bodySmallSize; anchors.verticalCenter: parent.verticalCenter }
      UiText {
        width: parent.width - issueGlyph.implicitWidth - fixButton.width - Theme.spaceSm * 2
        wrapMode: Text.Wrap
        text: root.session.suggestion && root.session.suggestion.quality
          ? "card issue, " + root.session.suggestion.quality.issue.replace(/_/g, " ") + ": " + root.session.suggestion.quality.detail : ""
        font.pixelSize: Theme.bodySmallSize
        color: Theme.orangeText
        anchors.verticalCenter: parent.verticalCenter
      }
      PlainButton {
        id: fixButton
        objectName: "fixCardButton"
        anchors.verticalCenter: parent.verticalCenter
        label: "fix in claude"
        tint: Theme.accentColor
        onActivated: root.session.fixCard()
      }
    }
  }

  // ---- the rating keycaps -----------------------------------------------------------
  // The digit is the key (with Shift), the word is the rating in its colour.
  // The suggestion is outlined in that colour and marked ◂; filling it, as
  // the old buttons did, made it louder than the card.
  Row {
    visible: root.revealedLayout
    spacing: Theme.spaceSm
    Repeater {
      model: [1, 2, 3, 4]
      delegate: Rectangle {
        id: keycap
        required property int modelData
        objectName: "rate:" + keycap.modelData
        readonly property bool suggested: root.session.suggestion !== null && root.session.suggestion.rating === keycap.modelData
        readonly property color tint: Theme.ratingColor(keycap.modelData)
        enabled: root.session.phase !== "submitting"
        opacity: enabled ? 1 : 0.45
        height: Theme.keycapHeight
        width: capRow.implicitWidth + Theme.spaceMd * 2
        color: capArea.containsMouse && enabled ? Theme.hoverFill : "transparent"
        border.color: keycap.suggested ? keycap.tint : Theme.border
        border.width: keycap.suggested ? Theme.keycapSuggestedBorder : Theme.borderWidth
        Row {
          id: capRow
          anchors.centerIn: parent
          spacing: Theme.spaceSm
          UiText { text: keycap.modelData; font.pixelSize: Theme.bodySmallSize; font.bold: true }
          UiText {
            text: Format.ratingName(keycap.modelData).toLowerCase() + (keycap.suggested ? " ◂" : "")
            font.pixelSize: Theme.bodySmallSize
            font.bold: keycap.suggested
            color: keycap.tint
          }
        }
        MouseArea {
          id: capArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: keycap.enabled
          cursorShape: Qt.PointingHandCursor
          onClicked: root.session.submit(keycap.modelData)
        }
      }
    }
  }
}
