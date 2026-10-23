pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Cards.js" as Cards
import "Format.js" as Format

// The Cards screen's filters, beside the stage under retention. The header
// folds the whole section away, leaving only what is selected. The selected
// filters always sit on top, each with ✕, so what narrows the grid is never
// lost among the choices; under them the field and what is left to choose:
// states, decks, and the most common tags still worth picking, the rest in
// the tag panel ("N more tags").
//
// A view only: CardsScreen owns the filters (what they are, how they
// combine: Cards.js) and hands in what to show; a click comes out as a
// signal, which the screen turns into a new filter. The text field is the
// one thing kept here, and goes to the screen after a pause in the typing.
Column {
  id: root
  spacing: Theme.spaceSm

  // { query, state, deck, tags, noted }: CardsScreen.filters.
  property var filters: ({ query: "", state: "", deck: "", tags: [], noted: false })
  // Open, or folded down to what is selected.
  property bool open: true
  property int filteredCount: 0
  property int notedHere: 0
  property var stateList: []        // Cards.stateCounts
  property int stateTotal: 1
  property var decks: []
  property var tagsShown: []        // the most common few, Cards.tagCounts
  property int tagsHidden: 0

  // What narrows the grid, in the order the section lists it.
  readonly property var selectedFilters: Cards.selectedFilters(filters)
  readonly property bool filtering: filters.query !== "" || selectedFilters.length > 0

  signal filterSet(string kind, var value)
  signal filterDropped(string kind, string value)
  signal tagAdded(string tag)
  signal clearRequested()
  signal fixRequested()
  signal moreTagsRequested()
  // Esc in the text field: the screen takes the keyboard back.
  signal escaped()

  // The screen's "clear" empties the field too.
  function clearText() { search.text = "" }

  Item {
    width: parent.width
    height: Theme.smallControlHeight
    PlainButton {
      objectName: "filtersToggle"
      anchors.verticalCenter: parent.verticalCenter
      label: (root.open ? "▾ " : "▸ ") + "FILTER"
      onActivated: root.open = !root.open
    }
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.spaceXl
      PlainButton {
        objectName: "fixNoted"
        visible: root.filters.noted && root.notedHere > 0
        label: "fix it · " + root.notedHere
        tint: Theme.accentColor
        onActivated: root.fixRequested()
      }
      PlainButton { objectName: "clearFilters"; visible: root.filtering; label: "clear"; onActivated: root.clearRequested() }
      UiText {
        objectName: "filteredCount"
        text: Format.plural(root.filteredCount, "card")
        font.pixelSize: Theme.captionSize; color: Theme.dim
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // What is selected, on top: a click drops it.
  Flow {
    objectName: "selectedFilters"
    visible: root.selectedFilters.length > 0
    // A chip's outline reaches past its words into the gap its
    // width keeps, so two picked chips side by side would share
    // an edge without this.
    spacing: Theme.spaceXs
    width: parent.width
    Repeater {
      model: root.selectedFilters
      delegate: Chip {
        id: picked
        required property var modelData
        objectName: "selected:" + picked.modelData.kind + ":" + picked.modelData.value
        label: picked.modelData.label + " ✕"
        dot: picked.modelData.kind === "state" ? Theme.stateColor(picked.modelData.value)
           : picked.modelData.kind === "noted" ? Theme.accentColor : "transparent"
        selected: true
        onActivated: root.filterDropped(picked.modelData.kind, picked.modelData.value)
      }
    }
  }

  // An underline, not a box: the field is one more quiet line.
  // No side padding, so its text starts on the column's edge.
  // It stays when the section is folded: typing is the quickest
  // filter there is.
  TextField {
    id: search
    objectName: "cardFilter"
    width: parent.width
    leftPadding: 0
    rightPadding: 0
    placeholderText: "filter by text"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.bodySmallSize
    color: Theme.ink
    placeholderTextColor: Theme.faint
    background: Item {
      Rectangle {
        y: parent.height - height
        width: parent.width
        height: Theme.hairlineWidth
        color: search.activeFocus ? Theme.accentColor : Theme.border
      }
    }
    // The grid follows a pause in the typing, not each key: every
    // change of filter rebuilds its tiles.
    onTextChanged: queryPause.restart()
    Timer { id: queryPause; interval: Config.searchDebounce; onTriggered: root.filterSet("query", search.text) }
    Keys.onEscapePressed: { text = ""; root.escaped() }
  }

  Column {
    visible: root.open
    width: parent.width
    spacing: Theme.spaceSm

    // The state bar: click a state to filter.
    Row {
      width: parent.width
      topPadding: Theme.spaceSm
      Repeater {
        model: root.stateList
        delegate: Rectangle {
          id: stateSegment
          required property var modelData
          objectName: "stateBar:" + stateSegment.modelData.state
          width: root.width * stateSegment.modelData.count / root.stateTotal
          height: Theme.statBarHeight
          color: Theme.stateColor(stateSegment.modelData.state)
          opacity: root.filters.state === "" || root.filters.state === stateSegment.modelData.state ? 1 : 0.3
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.filterSet("state", root.filters.state === stateSegment.modelData.state ? "" : stateSegment.modelData.state) }
        }
      }
    }
    Flow {
      width: parent.width
      Repeater {
        model: root.stateList.filter(function(s) { return s.state !== root.filters.state })
        delegate: Chip {
          id: stateLink
          required property var modelData
          objectName: "stateChip:" + stateLink.modelData.state
          label: stateLink.modelData.state
          count: stateLink.modelData.count
          dot: Theme.stateColor(stateLink.modelData.state)
          onActivated: root.filterSet("state", stateLink.modelData.state)
        }
      }
    }
    Flow {
      width: parent.width
      visible: !root.filters.noted && root.notedHere > 0
      Chip {
        objectName: "notedChip"
        label: "noted"
        count: root.notedHere
        dot: Theme.accentColor
        onActivated: root.filterSet("noted", true)
      }
    }
    Flow {
      width: parent.width
      visible: root.decks.length > 1
      Repeater {
        model: root.decks.filter(function(d) { return d !== root.filters.deck })
        delegate: Chip {
          id: deckLink
          required property var modelData
          label: deckLink.modelData
          onActivated: root.filterSet("deck", deckLink.modelData)
        }
      }
    }
    Flow {
      width: parent.width
      Repeater {
        model: root.tagsShown
        delegate: Chip {
          id: tagLink
          required property var modelData
          objectName: "tagChip:" + tagLink.modelData.tag
          label: "#" + tagLink.modelData.tag
          count: tagLink.modelData.count
          onActivated: root.tagAdded(tagLink.modelData.tag)
        }
      }
    }
    PlainButton {
      objectName: "moreTags"
      visible: root.tagsHidden > 0
      label: root.tagsHidden + " more tags ›"
      onActivated: root.moreTagsRequested()
    }
  }
}
