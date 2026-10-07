pragma ComponentBehavior: Bound
import QtQuick

import "Format.js" as Format
import "Launch.js" as Launch

// The end of a session: what was studied and how it went, the wiki pages
// connected to those cards (/study Phase 4), a walkthrough for what lapsed,
// and the way on.
Column {
  id: root
  objectName: "summary"

  property var session: null
  spacing: Theme.spaceXl


  UiText {
    visible: root.session.summaryData !== null && root.session.summaryData.reviews === 0
    text: root.session.info && root.session.info.total === 0
      ? "Nothing due. You're all caught up."
      : "Nothing was reviewed."
    font.pixelSize: Theme.subtitleSize
  }

  Column {
    visible: root.session.summaryData !== null && root.session.summaryData.reviews > 0
    spacing: Theme.spaceSm
    UiText {
      objectName: "summaryLine"
      text: root.session.summaryData
        ? Format.plural(root.session.summaryData.cards, "card")
          + (root.session.summaryData.repeats > 0 ? " (+" + root.session.summaryData.repeats + " repeats)" : "")
          + (root.session.summaryData.minutes !== null ? " in " + Format.durationText(root.session.summaryData.minutes) : "")
        : ""
      font.pixelSize: Theme.headingSize
      font.bold: true
    }
    UiText {
      text: root.session.summaryData
        ? "Accuracy " + Format.pct(root.session.summaryData.accuracy)
          + (root.session.app && root.session.app.store.overview && root.session.app.store.overview.streak > 0 ? " · " + Format.plural(root.session.app.store.overview.streak, "day") + " streak" : "")
          + (root.session.summaryData.overrides > 0 ? " · " + Format.plural(root.session.summaryData.overrides, "suggestion") + " overridden" : "")
        : ""
      color: Theme.secondaryInk
    }
    UiText {
      visible: root.session.summaryData && root.session.summaryData.lapses.length > 0
      width: root.width
      wrapMode: Text.Wrap
      text: root.session.summaryData ? "Lapses: " + root.session.summaryData.lapses.join("; ") : ""
      font.pixelSize: Theme.bodySmallSize
      color: Theme.redText
    }
    UiText {
      visible: root.session.rec.leeches.length > 0
      width: root.width
      wrapMode: Text.Wrap
      text: "Leeches: " + root.session.rec.leeches.join("; ")
      font.pixelSize: Theme.bodySmallSize
      color: Theme.orangeText
    }
  }

  // /study Phase 4: pages connected to what was actually studied.
  Column {
    visible: root.session.summaryData !== null && root.session.summaryData.reviews > 0
    width: parent.width
    spacing: Theme.spaceSm
    SectionLabel { text: "Related pages" }
    UiText {
      visible: root.session.related.length === 0
      text: "Nothing in the wiki maps to today's cards."
      font.pixelSize: Theme.bodySmallSize
      color: Theme.faint
    }
    Repeater {
      model: root.session.related
      delegate: ListRow {
        id: relatedRow
        required property var modelData
        objectName: "related:" + relatedRow.modelData.path
        width: root.width
        title: relatedRow.modelData.title
        topic: relatedRow.modelData.path.split("/").slice(0, -1).join("/")
        badge: relatedRow.modelData.lapsed > 0 ? "includes a lapse" : ""
        note: relatedRow.modelData.via === "cards" ? Format.plural(relatedRow.modelData.cards, "card") + " from today" : "shares a tag"
        onActivated: root.session.app.openPage(relatedRow.modelData.path, "")
      }
    }
  }

  // Offers: a walkthrough for what lapsed, cards for the gaps.
  Column {
    visible: root.session.summaryData !== null && root.session.summaryData.lapses.length > 0
    spacing: Theme.spaceSm
    SectionLabel { text: "Go deeper" }
    Repeater {
      model: root.session.summaryData ? root.session.summaryData.lapses.slice(0, 3) : []
      delegate: ActionButton {
        id: walkthroughButton
        required property var modelData
        small: true
        label: "/study-walkthrough " + (walkthroughButton.modelData.length > 48 ? walkthroughButton.modelData.slice(0, 47) + "…" : walkthroughButton.modelData)
        onActivated: root.session.app.launch(Launch.skillArgv(Paths.studyDir, "Omvida · Walkthrough", "/study-walkthrough", walkthroughButton.modelData, ""), "Opened Claude Code")
      }
    }
  }

  Row {
    spacing: Theme.spaceMd
    ActionButton {
      objectName: "studyAgainButton"
      filled: true
      label: "Start another session"
      hint: "Enter"
      onActivated: root.session.start()
    }
    ActionButton { label: "Browse the wiki"; onActivated: root.session.app.setScreen("wiki") }
    ActionButton { label: "Home"; onActivated: root.session.app.setScreen("home") }
  }
}
