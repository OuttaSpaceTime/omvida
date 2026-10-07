pragma ComponentBehavior: Bound
import QtQuick

import "Format.js" as Format
import "bar/Model.js" as Overview

// Where studying stands, from the deck's overview (flashcard-mcp
// src/app/overview.ts): the pressure verdict with its clearance, the
// calibration verdict, the last seven days of reviews, and how the deck has
// matured. Verdicts are shown verbatim, never re-derived (the study repo's
// rule: one implementation, or the surfaces drift). The wording is the bar
// panel's own (bar/Model.js), so the bar and the app say the same thing.
Column {
  id: root

  property var overview: null
  spacing: Theme.spaceMd

  readonly property var p: overview ? overview.pressure : null
  readonly property var c: overview ? overview.calibration : null

  function pressureLine() {
    if (!p) return "Loading the deck…"
    if (p.verdict === "ok" && p.flashcardsDue === 0) return "Nothing due. You're caught up."
    var s = Format.plural(p.flashcardsDue, "review") + " due"
    if (p.newToday > 0) s += " · " + p.newToday + " added today"
    return s
  }

  Row {
    spacing: Theme.spaceMd
    UiText {
      objectName: "pressureVerdict"
      text: root.p ? root.p.verdict : "…"
      font.pixelSize: Theme.headingSize
      font.bold: true
      color: root.p ? Theme.verdictColor(root.p.verdict) : Theme.faint
    }
    UiText {
      anchors.baseline: parent.children[0].baseline
      text: root.pressureLine()
    }
  }

  UiText {
    visible: text !== ""
    text: Overview.clearance(root.overview)
    font.pixelSize: Theme.bodySmallSize
    color: Theme.secondaryInk
  }

  Row {
    visible: root.c !== null
    spacing: Theme.spaceSm
    UiText {
      text: "Calibration"
      font.pixelSize: Theme.bodySmallSize
      color: Theme.dim
    }
    UiText {
      text: root.c ? root.c.verdict + (root.c.marginal ? " (marginal)" : "") : ""
      font.pixelSize: Theme.bodySmallSize
      color: root.c ? Theme.verdictColor(root.c.verdict) : Theme.dim
    }
    UiText {
      text: root.c && root.c.true_retention !== null
        ? "· true retention " + Format.pct(root.c.true_retention) + " over " + root.c.reviews + " reviews, " + root.c.window_days + " days"
        : (root.c ? "· " + root.c.reviews + " reviews in the window" : "")
      font.pixelSize: Theme.bodySmallSize
      color: Theme.dim
    }
  }

  // The week: one bar per day, Again in red on top of the rest.
  Row {
    visible: root.overview !== null
    spacing: Theme.spaceLg
    Row {
      id: spark
      spacing: Theme.spaceXs
      readonly property int peak: Overview.weekPeak(root.overview)
      Repeater {
        model: root.overview ? root.overview.week : []
        delegate: Column {
          id: dayBar
          required property var modelData
          required property int index
          spacing: Theme.spaceXxs
          Item {
            width: Theme.sparkBarWidth
            height: Theme.sparkHeight
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(dayBar.modelData.reviews > 0 ? Theme.spaceXxs : 0, parent.height * dayBar.modelData.reviews / spark.peak)
              color: dayBar.index === 6 ? Theme.accentColor : Theme.alpha(Theme.accentColor, 0.45)
            }
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: parent.height * dayBar.modelData.again / spark.peak
              color: Theme.redText
            }
          }
          UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Overview.weekday(dayBar.modelData.day)
            font.pixelSize: Theme.captionSize
            color: dayBar.index === 6 ? Theme.ink : Theme.faint
          }
        }
      }
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.spaceXs
      UiText {
        text: root.overview ? Format.plural(root.overview.reviewedToday, "review") + " today" : ""
        font.pixelSize: Theme.bodySmallSize
      }
      UiText {
        text: root.overview ? (root.overview.streak > 0 ? Format.plural(root.overview.streak, "day") + " streak" : "no streak") : ""
        font.pixelSize: Theme.bodySmallSize
        color: Theme.dim
      }
    }
  }

  // Maturity: one stacked bar, new to internalized.
  Column {
    id: maturity
    visible: root.overview !== null
    width: parent.width
    spacing: Theme.spaceXs
    readonly property var parts: Overview.maturityParts(root.overview)
    readonly property var colors: ({
      new: Theme.stateColor("new"), learning: Theme.stateColor("learning"),
      familiar: Theme.alpha(Theme.greenText, 0.55), internalized: Theme.greenText
    })
    Row {
      width: parent.width
      Repeater {
        model: maturity.parts
        delegate: Rectangle {
          id: maturitySegment
          required property var modelData
          height: Theme.statBarHeight
          width: maturity.width * maturitySegment.modelData.f
          color: maturity.colors[maturitySegment.modelData.key]
        }
      }
    }
    Row {
      spacing: Theme.spaceLg
      Repeater {
        model: maturity.parts
        delegate: UiText {
          id: maturityLabel
          required property var modelData
          text: maturityLabel.modelData.n + " " + maturityLabel.modelData.key
          font.pixelSize: Theme.captionSize
          color: Theme.dim
        }
      }
    }
  }
}
