pragma ComponentBehavior: Bound
import QtQuick

import "Format.js" as Format
import "bar/Model.js" as Overview

// A rest day's offer on Study: today's share of the week to study ahead, if
// there is time (the overview's `ahead`, flashcard-mcp's study-ahead.ts). What
// it holds, the study days ahead as they stand and as the share leaves them,
// and the one way in, A. Once the share is studied it says so and offers
// nothing: the share is the day's, fixed, so there is no "again".
//
// The counts and their mix are the deck server's, shown as they come; the
// wording is bar/Model.js's, which the bar panel shares.
Column {
  id: root
  objectName: "aheadPanel"

  property var plan: null
  signal studyAhead()

  readonly property int count: Overview.aheadCount(root.plan)
  spacing: Theme.spaceMd

  SectionLabel { width: parent.width; divided: true; text: "Rest day" }

  UiText {
    objectName: "aheadHeadline"
    width: parent.width
    wrapMode: Text.Wrap
    text: root.count > 0 ? "If you have time: " + Format.plural(root.count, "card") + " ahead"
                         : "Today's share is studied. The rest of the day is off."
    font.pixelSize: Theme.subtitleSize
  }

  UiText {
    objectName: "aheadLine"
    visible: root.count > 0
    width: parent.width
    wrapMode: Text.Wrap
    text: Overview.aheadLine(root.plan)
    color: Theme.secondaryInk
  }

  UiText {
    objectName: "aheadDays"
    visible: text !== ""
    width: parent.width
    wrapMode: Text.Wrap
    text: Overview.aheadDays(root.plan)
    font.pixelSize: Theme.bodySmallSize
    color: Theme.dim
  }

  PlainButton {
    objectName: "studyAheadButton"
    visible: root.count > 0
    keys: "a"
    label: "study ahead"
    size: Theme.bodySize
    tint: Theme.accentColor
    onActivated: root.studyAhead()
  }
}
