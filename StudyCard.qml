pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Format.js" as Format

// One card of a study session: the previous card's result, the front, the
// answer box, then once revealed the back and Claude's suggestion, and the
// rating and action buttons. All state is the session's (StudySession.qml).
Column {
  id: root

  property var session: null
  property alias answerField: answer
  spacing: Theme.spaceXl

  // The answer box keeps the keyboard while a card is up, so typing starts at
  // once and the rating keys always reach it.
  function focusAnswer() { answer.forceActiveFocus() }

  Binding { target: root.session; property: "answer"; value: answer.text }
  Connections {
    target: root.session
    function onAnswerReset() { answer.text = "" }
  }

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
      color: Theme.dim
    }
  }

  // ---- the card ---------------------------------------------------------------------
  Column {
    visible: root.session.inCard || root.session.phase === "loading"
    width: parent.width
    spacing: Theme.spaceLg

    UiText {
      visible: root.session.next && root.session.next.leech
      width: parent.width
      wrapMode: Text.Wrap
      text: root.session.next && root.session.next.leech
        ? "This card has lapsed " + root.session.next.leech.lapses + " times. Answer it as usual; after the rating you decide what to do with it."
        : ""
      font.pixelSize: Theme.bodySmallSize
      color: Theme.orangeText
    }

    CardFace {
      objectName: "cardFront"
      width: parent.width
      html: root.session.card ? root.session.card.front : ""
      size: Theme.cardFrontSize
      opacity: root.session.phase === "loading" ? 0.4 : 1
    }

    Row {
      visible: root.session.card && root.session.card.tags.length > 0
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

    // The answer. Always focused while a card is up, so typing starts at
    // once; read-only after the reveal, but it keeps the keyboard so the
    // rating keys keep working.
    Rectangle {
      width: parent.width
      height: Math.max(Theme.answerMinHeight, answer.implicitHeight + Theme.spaceMd * 2)
      color: Theme.fill
      border.color: answer.activeFocus && root.session.phase === "answering" ? Theme.accentColor : Theme.hairline
      border.width: Theme.borderWidth

      TextArea {
        id: answer
        objectName: "answerField"
        anchors.fill: parent
        anchors.margins: Theme.spaceXs
        readOnly: root.session.phase !== "answering"
        wrapMode: TextEdit.Wrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.answerSize
        color: Theme.ink
        placeholderText: root.session.phase === "answering" ? "Your answer. Shift+Enter reveals, Shift+1–4 rates without typing." : "(no answer typed)"
        placeholderTextColor: Theme.faint
        selectByMouse: true
        background: null
        Keys.onPressed: function(event) { if (root.session.handleKey(event)) event.accepted = true }
      }
    }

    // ---- revealed -----------------------------------------------------------
    Column {
      visible: root.session.phase === "grading" || root.session.phase === "revealed" || (root.session.phase === "submitting" && root.session.revealedAt > 0)
      width: parent.width
      spacing: Theme.spaceLg

      Rectangle { width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }

      CardFace {
        objectName: "cardBack"
        width: parent.width
        html: root.session.card ? root.session.card.back : ""
        size: Theme.answerSize
      }

      // Claude's suggestion and why.
      Rectangle {
        objectName: "suggestionBox"
        visible: root.session.phase === "grading" || root.session.suggestion !== null || root.session.gradeError !== ""
        width: parent.width
        height: sugCol.implicitHeight + Theme.spaceMd * 2
        color: Theme.fill
        border.color: root.session.suggestion ? Theme.ratingColor(root.session.suggestion.rating) : Theme.hairline
        border.width: Theme.borderWidth

        Column {
          id: sugCol
          x: Theme.spaceMd
          y: Theme.spaceMd
          width: parent.width - Theme.spaceMd * 2
          spacing: Theme.spaceSm
          UiText {
            objectName: "suggestionLine"
            text: root.session.phase === "grading" ? (root.session.acceptPending ? "Claude is reading your answer… (will accept its rating)" : "Claude is reading your answer…")
                 : root.session.suggestion ? "Suggested: " + Format.ratingName(root.session.suggestion.rating) + " (" + root.session.suggestion.rating + ")"
                 : "No suggestion: " + root.session.gradeError
            font.bold: root.session.suggestion !== null
            color: root.session.suggestion ? Theme.ratingColor(root.session.suggestion.rating) : (root.session.gradeError !== "" ? Theme.redText : Theme.dim)
          }
          UiText {
            objectName: "suggestionReason"
            visible: root.session.suggestion !== null
            width: parent.width
            wrapMode: Text.Wrap
            text: root.session.suggestion ? root.session.suggestion.reason : ""
            lineHeight: Theme.proseLineHeight
          }
          Row {
            visible: root.session.suggestion !== null && root.session.suggestion.quality !== null
            width: parent.width
            spacing: Theme.spaceMd
            Glyph { icon: "alert"; color: Theme.orangeText; font.pixelSize: Theme.bodySmallSize; anchors.verticalCenter: parent.verticalCenter }
            UiText {
              width: parent.width - fixBtn.width - Theme.spaceMd * 2 - Theme.bodySmallSize
              wrapMode: Text.Wrap
              text: root.session.suggestion && root.session.suggestion.quality
                ? "Card issue, " + root.session.suggestion.quality.issue.replace(/_/g, " ") + ": " + root.session.suggestion.quality.detail : ""
              font.pixelSize: Theme.bodySmallSize
              color: Theme.orangeText
              anchors.verticalCenter: parent.verticalCenter
            }
            ActionButton { id: fixBtn; small: true; label: "Fix in Claude"; onActivated: root.session.fixCard() }
          }
        }
      }
    }

    // ---- ratings -----------------------------------------------------------------
    // A Flow, so a narrow window wraps the actions onto a second line
    // instead of pushing Skip past the edge (layout rule 7).
    Flow {
      width: parent.width
      spacing: Theme.spaceSm
      visible: root.session.inCard
      Repeater {
        model: [1, 2, 3, 4]
        delegate: ActionButton {
          id: rateButton
          required property int modelData
          objectName: "rate:" + rateButton.modelData
          label: Format.ratingName(rateButton.modelData)
          hint: "⇧" + rateButton.modelData
          tint: Theme.ratingColor(rateButton.modelData)
          filled: root.session.suggestion !== null && root.session.suggestion.rating === rateButton.modelData
          enabled: root.session.phase !== "submitting"
          onActivated: root.session.submit(rateButton.modelData)
        }
      }
      Item { width: Theme.spaceLg; height: Theme.hairlineWidth }
      ActionButton {
        objectName: "revealButton"
        visible: root.session.phase === "answering"
        label: "Reveal"
        hint: "⇧⏎"
        onActivated: root.session.reveal(false)
      }
      ActionButton {
        objectName: "discussButton"
        icon: "discuss"
        label: "Discuss"
        hint: "Ctrl+D"
        onActivated: root.session.discuss()
      }
      ActionButton {
        objectName: "skipButton"
        label: "Skip"
        hint: "Ctrl+S"
        onActivated: root.session.skip()
      }
    }

    UiText {
      visible: root.session.inCard
      width: parent.width
      wrapMode: Text.Wrap
      text: root.session.phase === "answering"
        ? "Shift+Enter reveal · Alt+Enter reveal and accept Claude's rating · Shift+1–4 rate now"
        : "Alt+Enter accept the suggestion · Shift+Enter Good · Shift+1–4 your rating · Ctrl+D discuss"
      font.pixelSize: Theme.captionSize
      color: Theme.faint
    }
  }
}
