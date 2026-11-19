pragma ComponentBehavior: Bound
import QtQuick

import "bar/Model.js" as Overview

// Reviews by day around today, a bar each, from the deck's overview (`load`):
// what was studied behind today, what is expected ahead, and today holding
// both. The further from today, the wider a bar's span (single days, then 2d,
// 4d and 8d totals); the deck server draws those lines, so this chart and the
// bar panel's cannot disagree. The wide bars are totals and are meant to stand
// taller: every bar shares one scale, its count printed above it.
Column {
  id: root
  objectName: "loadChart"

  property var overview: null
  readonly property var bars: Overview.loadBars(root.overview)
  readonly property int peak: Overview.loadPeak(root.bars)
  // Solid, not translucent: the legend's rich text takes a plain #rrggbb.
  readonly property color studiedColor: Qt.tint(Theme.background, Theme.alpha(Theme.foreground, 0.45))

  visible: root.bars.length > 0
  spacing: Theme.spaceSm

  Item {
    width: parent.width
    height: title.implicitHeight
    SectionLabel { id: title; width: parent.width; divided: true; text: "Reviews by day" }
    UiText {
      anchors.right: parent.right
      anchors.baseline: title.baseline
      textFormat: Text.StyledText
      text: "<font color=\"" + root.studiedColor + "\">■</font> studied  "
          + "<font color=\"" + Theme.redText + "\">■</font> again  "
          + "<font color=\"" + Theme.accentColor + "\">■</font> expected"
      font.pixelSize: Theme.captionSize
      color: Theme.faint
    }
  }

  Row {
    id: columns
    width: parent.width
    spacing: Theme.segmentGap

    Repeater {
      model: root.bars
      delegate: Column {
        id: day
        required property var modelData
        required property int index
        readonly property int total: day.modelData.reviews + day.modelData.due
        // The smallest count still shows.
        function barHeight(n) { return n > 0 ? Math.max(Theme.spaceXxs, Theme.loadChartHeight * n / root.peak) : 0 }

        objectName: "loadBar:" + day.index
        width: (columns.width + columns.spacing) / root.bars.length - columns.spacing
        spacing: Theme.spaceXxs

        Item {
          width: parent.width
          height: Theme.loadChartHeight + count.implicitHeight
          Column {
            anchors.bottom: parent.bottom
            width: parent.width
            UiText {
              id: count
              objectName: "loadCount:" + day.index
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: day.total > 0 ? day.total : ""
              font.pixelSize: Theme.captionSize
              color: day.modelData.today ? Theme.foreground : Theme.dim
            }
            Rectangle { width: parent.width; height: day.barHeight(day.modelData.due); color: Theme.accentColor }
            Rectangle { width: parent.width; height: day.barHeight(day.modelData.reviews - day.modelData.again); color: root.studiedColor }
            Rectangle { width: parent.width; height: day.barHeight(day.modelData.again); color: Theme.redText }
          }
        }
        UiText {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: day.modelData.label
          font.pixelSize: Theme.captionSize
          font.bold: day.modelData.today
          color: day.modelData.today ? Theme.foreground : Theme.faint
        }
      }
    }
  }
}
