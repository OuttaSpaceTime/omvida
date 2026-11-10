pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Format.js" as Format

// Where Ctrl+Q's checks show: docked above the status line, drawn over the
// bottom of the screen. It was in the layout until 2026-11-10, and the screen
// jumped each time a result came or went. Each stays until it is dismissed; it
// can be discussed in Claude Code first. A toast said this
// until 2026-11-03: one line for four seconds, about a card that had perhaps
// just been deleted and split. A modal was the other way, rejected: the point
// of Ctrl+Q is that the session goes on.
//
// A widget: it shows what it is given and signals what was clicked (the window
// holds the checks, CardCheck.qml). Its only button is a report's ✕: the keys,
// ctrl+shift+Q and ctrl+shift+D on the oldest finished report, are the
// window's and listed in Study's key list (StudyScreen.qml), not written here.
Rectangle {
  id: root

  property var reports: []
  signal dismissAsked(var report)

  // A line of a report, gone when it has nothing to say.
  component ReportLine: UiText {
    visible: text !== ""
    wrapMode: Text.Wrap
    font.pixelSize: Theme.bodySmallSize
    color: Theme.secondaryInk
  }

  visible: reports.length > 0
  height: visible ? Math.min(col.implicitHeight + Theme.spaceMd * 2, Theme.checkSlotMaxHeight) : 0
  color: Theme.codeFill

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Theme.hairlineWidth
    color: Theme.hairline
  }

  GlideFlickable {
    anchors.fill: parent
    contentHeight: col.implicitHeight + Theme.spaceMd * 2
    clip: true
    ScrollBar.vertical: ScrollBar {}

    Column {
      id: col
      x: Theme.pageX(root.width)
      y: Theme.spaceMd
      width: Theme.pageWidth(root.width)
      spacing: Theme.spaceMd

      Repeater {
        model: root.reports
        delegate: Column {
          id: report
          required property var modelData
          required property int index
          readonly property bool running: modelData.state === "running"
          objectName: "checkReport:" + index
          width: col.width
          spacing: Theme.spaceXs

          Item {
            width: parent.width
            implicitHeight: Math.max(headline.implicitHeight, close.implicitHeight)
            UiText {
              id: headline
              objectName: "checkHeadline:" + report.index
              anchors.left: parent.left
              anchors.right: close.left
              anchors.rightMargin: Theme.spaceLg
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              text: Format.checkHeadline(report.modelData)
              font.bold: true
              font.pixelSize: Theme.bodySmallSize
              color: report.modelData.state === "failed" || report.modelData.outcome === "unchanged" ? Theme.redText
                     : report.modelData.outcome === "fixed" || report.modelData.outcome === "split" ? Theme.accentColor
                     : Theme.dim
            }
            PlainButton {
              id: close
              objectName: "checkDismiss:" + report.index
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: !report.running
              icon: "close"
              tip: "Dismiss"
              onActivated: root.dismissAsked(report.modelData)
            }
          }
          ReportLine {
            objectName: "checkFront:" + report.index
            width: parent.width
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            text: Format.stripHtml(report.modelData.card.front)
            color: Theme.dim
          }
          ReportLine {
            objectName: "checkText:" + report.index
            width: parent.width
            text: report.modelData.text
            color: Theme.ink
          }
          ReportLine {
            objectName: "checkAsked:" + report.index
            width: parent.width
            text: report.modelData.asked.length > 1 ? "Asked " + report.modelData.asked.length + " things: " + report.modelData.asked.join("; ") : ""
          }
          ReportLine {
            objectName: "checkExtra:" + report.index
            width: parent.width
            text: report.modelData.extra.length > 0 ? "Beyond what it asked: " + report.modelData.extra.join("; ") : ""
          }
          Repeater {
            model: report.modelData.cards
            delegate: ReportLine {
              required property var modelData
              required property int index
              objectName: "checkCard:" + report.index + ":" + index
              width: col.width
              text: "→ " + Format.stripHtml(modelData.front)
            }
          }
        }
      }
    }
  }
}
