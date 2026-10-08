pragma ComponentBehavior: Bound
import QtQuick

import "Format.js" as Format
import "bar/Model.js" as Overview

// Where studying stands, from the deck's overview (flashcard-mcp
// src/app/overview.ts), laid out as the bar overlay's "Glance" (the style the
// user chose): the reviews due as one big figure with its word, the pressure
// verdict in a small outlined chip, one dim sentence (what clears the
// pressure, today's reviews), how the deck has matured as a thin segmented bar
// with its legend, and one line for retention and the calibration verdict.
//
// Verdicts are shown verbatim, never re-derived (the study repo's rule: one
// implementation, or the surfaces drift). The sentences are bar/Model.js's, so
// the bar and the app say the same thing.
//
// The old panel's week chart, with a letter under each day, became a small
// sparkline beside the figure: Glance has no chart, but the week (and the
// Again share in red) is the only place the app shows how the last days went,
// so it stays, at a size that does not compete with the figure.
Column {
  id: root

  property var overview: null
  spacing: Theme.spaceLg

  readonly property var p: overview ? overview.pressure : null
  readonly property var c: overview ? overview.calibration : null

  // The dim sentence under the figure: what clears the pressure, then the
  // day so far. Model.today() carries the new-card pool ("8 new waiting"),
  // which pressure leaves out of the count above it.
  function sentence() {
    if (!p) return "Loading the deck…"
    var parts = []
    if (p.verdict === "ok" && p.flashcardsDue === 0) parts.push("Nothing due. You're caught up")
    var clear = Overview.clearance(root.overview)
    if (clear !== "") parts.push(clear)
    if (p.newToday > 0) parts.push(p.newToday + " added today")
    parts.push(Overview.today(root.overview))
    return parts.join(" · ")
  }

  function retentionLine() {
    if (!c) return ""
    return c.true_retention !== null
      ? "Retention " + Format.pct(c.true_retention) + " over " + Format.plural(c.reviews, "review") + ", " + c.window_days + " days"
      : Format.plural(c.reviews, "review") + " in the window"
  }

  // ---- the figure and the verdict ----------------------------------------------
  Item {
    width: parent.width
    height: hero.implicitHeight

    Row {
      id: hero
      spacing: Theme.spaceMd
      UiText {
        id: heroFigure
        objectName: "dueFigure"
        text: root.p ? root.p.flashcardsDue : "–"
        font.pixelSize: Theme.heroSize
        font.bold: true
      }
      UiText {
        anchors.baseline: heroFigure.baseline
        text: "due"
        color: Theme.secondaryInk
      }
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: hero.verticalCenter
      spacing: Theme.spaceLg

      // The week: one bar per day, today last in the accent, Again in red.
      // A week with no reviews draws nothing: seven empty days were a dashed
      // line that read as a broken control.
      Row {
        id: spark
        visible: root.overview !== null && root.overview.week.some(function(d) { return d.reviews > 0 })
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXxs
        readonly property int peak: Overview.weekPeak(root.overview)
        Repeater {
          model: root.overview ? root.overview.week : []
          delegate: Item {
            id: dayBar
            required property var modelData
            required property int index
            width: Theme.glanceSparkBarWidth
            height: Theme.glanceSparkHeight
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(dayBar.modelData.reviews > 0 ? Theme.spaceXxs : Theme.hairlineWidth, parent.height * dayBar.modelData.reviews / spark.peak)
              color: dayBar.modelData.reviews === 0 ? Theme.hairline
                     : (dayBar.index === 6 ? Theme.accentColor : Theme.alpha(Theme.accentColor, 0.45))
            }
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: parent.height * dayBar.modelData.again / spark.peak
              color: Theme.redText
            }
          }
        }
      }

      // The pressure verdict, outlined in its colour.
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: verdictText.implicitWidth + Theme.spaceLg
        height: verdictText.implicitHeight + Theme.spaceXs
        color: "transparent"
        border.color: verdictText.color
        border.width: Theme.borderWidth
        UiText {
          id: verdictText
          objectName: "pressureVerdict"
          anchors.centerIn: parent
          text: root.p ? root.p.verdict : "…"
          font.pixelSize: Theme.captionSize
          color: root.p ? Theme.verdictColor(root.p.verdict) : Theme.faint
        }
      }
    }
  }

  UiText {
    width: parent.width
    wrapMode: Text.Wrap
    text: root.sentence()
    font.pixelSize: Theme.bodySmallSize
    color: Theme.dim
  }

  // ---- maturity: a thin segmented bar and its legend ---------------------------------
  Column {
    id: maturity
    visible: root.overview !== null
    width: parent.width
    spacing: Theme.spaceSm
    // Empty states draw no segment, so no gap doubles up around nothing.
    readonly property var parts: Overview.maturityParts(root.overview)
    readonly property var shown: parts.filter(function(x) { return x.n > 0 })
    readonly property var colors: ({
      new: Theme.stateColor("new"), learning: Theme.stateColor("learning"),
      familiar: Theme.alpha(Theme.greenText, 0.55), internalized: Theme.greenText
    })
    // Text can't take the familiar segment's half-strength green and stay
    // readable, so its number is set in the full green, as internalized's is.
    function numberColor(key) { return key === "familiar" ? Theme.greenText : colors[key] }
    Row {
      id: segments
      width: parent.width
      spacing: Theme.segmentGap
      readonly property real free: width - spacing * Math.max(0, maturity.shown.length - 1)
      Repeater {
        model: maturity.shown
        delegate: Rectangle {
          id: maturitySegment
          required property var modelData
          height: Theme.segmentBarHeight
          width: segments.free * maturitySegment.modelData.f
          color: maturity.colors[maturitySegment.modelData.key]
        }
      }
    }
    Flow {
      width: parent.width
      spacing: Theme.spaceLg
      Repeater {
        model: maturity.parts
        delegate: Row {
          id: legendItem
          required property var modelData
          spacing: Theme.spaceXs
          UiText {
            text: legendItem.modelData.n
            font.pixelSize: Theme.captionSize
            font.weight: Font.Medium
            color: legendItem.modelData.n > 0 ? maturity.numberColor(legendItem.modelData.key) : Theme.secondaryInk
          }
          UiText {
            text: legendItem.modelData.key
            font.pixelSize: Theme.captionSize
            color: Theme.dim
          }
        }
      }
    }
  }

  // ---- retention and calibration, one line -------------------------------------
  Flow {
    visible: root.c !== null
    width: parent.width
    UiText {
      text: root.retentionLine() + " · "
      font.pixelSize: Theme.captionSize
      color: Theme.dim
    }
    UiText {
      objectName: "calibrationVerdict"
      text: root.c ? root.c.verdict + (root.c.marginal ? " (marginal)" : "") : ""
      font.pixelSize: Theme.captionSize
      color: root.c ? Theme.verdictColor(root.c.verdict) : Theme.dim
    }
  }
}
