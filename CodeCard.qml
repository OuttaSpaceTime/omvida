pragma ComponentBehavior: Bound
import QtQuick

import "Exercise.js" as Exercise
import "Format.js" as Format

// A code card: a card answered by running it (CodeAttempt, flashcard-mcp's
// exercises.ts).
//
//   what to solve, large
//   the code on its fill, the blanks in place; for a prediction, under each
//     expression, a prompt to type what it evaluates to
//   each case, expression over what it gives beside what it should
//   the error, if there is one, and what the code printed
//
// Nothing runs while typing; a check (Shift+Enter) is the only run. The results
// shake on a wrong answer or an error, and flash green on a pass, in the same
// breath as the words, so neither depends on seeing the motion. What a check said
// stays on screen until the code changes. A pass stays up with its why until
// Shift+Enter moves on.
Column {
  id: root

  required property StudySession session
  spacing: Theme.spaceLg

  readonly property var result: root.session.code.result
  readonly property var exercise: root.session.isCode ? root.session.card.exercise : null
  readonly property bool predict: root.exercise !== null && root.exercise.kind === "predict"
  readonly property color verdictColor: {
    if (!root.result || root.session.code.gaveUp) return Theme.dim
    if (root.result.status === "pass") return Theme.greenText
    if (root.result.status === "incomplete") return Theme.dim
    return root.result.status === "wrong" ? Theme.orangeText : Theme.redText
  }

  // Code in the code's face, wrapped by whoever sets its width. Plain, as a
  // card's expressions and outputs are not HTML.
  component CodeText: UiText {
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    font.pixelSize: Theme.bodySmallSize
  }
  // A case's output or what it should be: a caption over its value.
  component CaseColumn: Column {
    id: column
    property string caption
    property alias valueName: valueText.objectName
    property alias valueText: valueText.text
    property alias valueColor: valueText.color
    spacing: Theme.spaceXs
    UiText {
      text: column.caption
      font.pixelSize: Theme.captionSize
      color: Theme.dim
    }
    CodeText {
      id: valueText
      width: column.width
    }
  }

  // The blanks, by index, for the keyboard. They come and go with the card.
  property var fields: ({})
  function register(field) { root.fields[field.blank] = field }
  function unregister(field) { if (root.fields[field.blank] === field) delete root.fields[field.blank] }
  // The one last typed in: a dialog or the key list closing hands the keyboard
  // back to where it was, not to the top of the card.
  property int lastBlank: 0
  onExerciseChanged: lastBlank = 0
  function focusBlank() {
    var f = root.fields[root.lastBlank]
    if (f) f.forceActiveFocus()
    return !!f
  }
  function focusNext(index, back) {
    var count = root.exercise ? root.exercise.answers : 0
    var f = root.fields[(index + (back ? count - 1 : 1)) % Math.max(count, 1)]
    if (f) f.forceActiveFocus()
  }

  // For the tests: the animation of the last check.
  readonly property bool shaking: shake.running
  readonly property bool flashing: flash.running

  Connections {
    target: root.session.code
    function onChecked(status) {
      if (status === "pass") flash.restart()
      else if (status !== "incomplete") shake.restart()
    }
  }

  CardFace {
    objectName: "codeBrief"
    width: parent.width
    html: root.exercise ? root.exercise.brief : ""
    size: Theme.cardFrontSize
  }

  // ---- the code ----------------------------------------------------------------------
  Rectangle {
    objectName: "codeListing"
    width: parent.width
    height: listing.implicitHeight + Theme.spaceMd * 2
    color: Theme.codeFill

    Column {
      id: listing
      x: Theme.spaceMd
      y: Theme.spaceMd
      width: parent.width - Theme.spaceMd * 2
      spacing: Theme.spaceXs

      FontMetrics {
        id: codeFont
        font.family: Theme.fontFamily
        font.pixelSize: Theme.bodySmallSize
      }

      Repeater {
        model: root.exercise ? Exercise.lines(root.exercise.parts) : []
        // A Flow, not a Row: an answer too long for the line takes the code after
        // it to the next one, rather than off the listing.
        delegate: Flow {
          id: lineRow
          required property var modelData
          width: listing.width
          // An empty line of code keeps its height.
          height: Math.max(implicitHeight, codeFont.height)
          Repeater {
            model: lineRow.modelData
            delegate: Item {
              id: piece
              required property var modelData
              readonly property bool isBlank: piece.modelData.blank !== undefined
              width: Math.min(listing.width, !isBlank ? code.implicitWidth : piece.modelData.multiline ? listing.width : blankLoader.wanted)
              height: isBlank ? blankLoader.implicitHeight : code.implicitHeight

              Text {
                id: code
                visible: !piece.isBlank
                width: piece.width
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodySmallSize
                color: Theme.ink
                text: {
                  if (piece.isBlank) return ""
                  var html = root.session.code.html[piece.modelData.segment]
                  return Theme.richTextStyle + "<pre style=\"white-space:pre-wrap\">" + (html !== undefined ? html : Format.escapeHtml(piece.modelData.text)) + "</pre>"
                }
              }
              Loader {
                id: blankLoader
                active: piece.isBlank
                readonly property real wanted: blankLoader.item ? (blankLoader.item as CodeBlank).implicitWidth : 0
                sourceComponent: CodeBlank {
                  card: root
                  blank: piece.modelData.blank
                  multiline: !!piece.modelData.multiline
                  width: piece.width
                }
              }
            }
          }
        }
      }

      // A prediction's prompts: the expression, then a field for its value.
      Repeater {
        model: root.predict ? root.exercise.cases : []
        delegate: Column {
          id: prompt
          required property var modelData
          required property int index
          width: listing.width
          spacing: Theme.spaceXs
          CodeText {
            width: parent.width
            text: prompt.modelData.expr
          }
          Row {
            spacing: Theme.spaceSm
            UiText {
              id: promptMark
              text: "›"
              font.pixelSize: Theme.bodySmallSize
              font.bold: true
              color: Theme.accentColor
            }
            CodeBlank {
              card: root
              blank: prompt.index
              width: Math.min(implicitWidth, prompt.width - promptMark.width - Theme.spaceSm)
            }
          }
        }
      }
    }
  }

  // ---- the results -------------------------------------------------------------------
  Item {
    id: results
    objectName: "codeResults"
    width: parent.width
    height: resultsCol.implicitHeight
    transform: Translate { id: nudge }

    // Over in under half a second, and small: long enough to feel, short enough
    // not to stand between a wrong try and the next one.
    SequentialAnimation {
      id: shake
      NumberAnimation { target: nudge; property: "x"; to: Theme.codeShakeDistance; duration: Theme.codeShakeDuration / 4; easing.type: Easing.OutQuad }
      NumberAnimation { target: nudge; property: "x"; to: -Theme.codeShakeDistance; duration: Theme.codeShakeDuration / 4; easing.type: Easing.InOutQuad }
      NumberAnimation { target: nudge; property: "x"; to: Theme.codeShakeDistance / 2; duration: Theme.codeShakeDuration / 4; easing.type: Easing.InOutQuad }
      NumberAnimation { target: nudge; property: "x"; to: 0; duration: Theme.codeShakeDuration / 4; easing.type: Easing.OutQuad }
    }
    Rectangle {
      id: flashFill
      anchors.fill: parent
      color: Theme.ratingFill(3)
      opacity: 0
      SequentialAnimation {
        id: flash
        NumberAnimation { target: flashFill; property: "opacity"; to: 1; duration: Theme.codeFlashDuration / 3; easing.type: Easing.OutQuad }
        NumberAnimation { target: flashFill; property: "opacity"; to: 0; duration: Theme.codeFlashDuration * 2 / 3; easing.type: Easing.InQuad }
      }
    }

    Column {
      id: resultsCol
      width: parent.width
      spacing: Theme.spaceMd

      UiText {
        objectName: "codeVerdict"
        visible: root.result !== null
        // The solution passes, of course. That is no "✓ matches" for having given up.
        text: root.session.code.gaveUp ? "the solution" : (root.result && root.result.status === "pass" ? "✓ " : "") + Exercise.verdict(root.result)
        font.pixelSize: Theme.bodySmallSize
        font.bold: true
        color: root.verdictColor
      }

      // Every case, what it gives beside what it should. A prediction's real
      // value stays away until it is right: there the second is the guess.
      Repeater {
        model: root.exercise ? root.exercise.cases : []
        delegate: Item {
          id: caseRow
          required property var modelData
          required property int index
          readonly property var outcome: root.result && root.result.cases[caseRow.index] ? root.result.cases[caseRow.index] : null
          readonly property string goal: caseRow.modelData.goal !== null ? caseRow.modelData.goal : (outcome && outcome.goal !== null ? outcome.goal : "")
          readonly property string actual: outcome && outcome.actual !== null ? outcome.actual : ""
          visible: !root.predict || outcome !== null
          objectName: "codeCase:" + caseRow.index
          width: resultsCol.width
          height: visible ? caseCol.implicitHeight : 0

          Column {
            id: caseCol
            width: parent.width
            spacing: Theme.spaceXs
            CodeText {
              visible: !root.predict
              width: parent.width
              wrapMode: Text.NoWrap
              elide: Text.ElideRight
              font.pixelSize: Theme.captionSize
              color: Theme.dim
              text: caseRow.modelData.expr
            }
            Row {
              width: parent.width
              spacing: Theme.spaceMd
              CaseColumn {
                width: (parent.width - parent.spacing) / 2
                caption: "output"
                valueName: "codeActual:" + caseRow.index
                valueColor: caseRow.outcome && caseRow.outcome.pass ? Theme.greenText : caseRow.outcome ? Theme.redText : Theme.dim
                // An error is this case's output, verbatim, as a terminal
                // would have it: there is no other place to look for it.
                valueText: caseRow.outcome && caseRow.outcome.error ? caseRow.outcome.error : caseRow.actual !== "" ? caseRow.actual : "–"
              }
              CaseColumn {
                width: (parent.width - parent.spacing) / 2
                caption: root.predict ? "you said" : "expected"
                valueName: "codeExpected:" + caseRow.index
                valueText: caseRow.goal
              }
            }
          }
        }
      }

      // What stopped it before any case could run: a syntax error, say.
      CodeText {
        objectName: "codeError"
        visible: text !== ""
        width: parent.width
        font.pixelSize: Theme.captionSize
        color: Theme.redText
        text: Exercise.errorText(root.result)
      }

      Column {
        visible: output.text !== ""
        width: parent.width
        spacing: Theme.spaceXs
        UiText {
          text: "printed"
          font.pixelSize: Theme.captionSize
          color: Theme.dim
        }
        CodeText {
          id: output
          objectName: "codeOutput"
          width: parent.width
          font.pixelSize: Theme.captionSize
          color: Theme.secondaryInk
          text: Exercise.printed(root.result)
        }
      }

      // Once it is over, the why: the card's whole lesson.
      CardFace {
        objectName: "codeExplain"
        visible: root.session.code.explain !== ""
        width: parent.width
        html: root.session.code.explain
        size: Theme.bodySize
      }
    }
  }
}
