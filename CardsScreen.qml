pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Cards.js" as Cards
import "Format.js" as Format

// The whole deck, the viewer's /flashcards, as one screen: a flip-through
// stage at the top, retention over the last 30 days (flashcard-mcp's
// calibration verdict, shown verbatim) and the filters beside it, and a grid
// of the cards still to come below.
//
// The stage and the grid are one walk through the filtered cards. The
// stage shows the current card; the grid shows only the cards after it, so
// paging forward takes the next tile off the grid and onto the stage, and
// paging back puts it back. Clicking a tile jumps there: that card becomes
// current and every card before it counts as passed, exactly as if it had
// been paged to. The other reading, "the clicked card goes on the stage and
// the grid stays as it was", was rejected: the grid would then no longer be
// what comes next, and → would lead somewhere the grid doesn't show.
//
// A change of filter starts the walk over at the new list's first card; a
// refresh of the deck keeps the current card (FlipThrough's stage mode).
Item {
  id: root

  property var app: null
  // What narrows the grid: the text, and one state, deck and tag at most
  // ("" for any). Changed only through setFilter(), as a new object, so
  // every binding on it updates.
  property var filters: ({ query: "", state: "", deck: "", tag: "" })
  readonly property var calibration: app && app.store.overview ? app.store.overview.calibration : null

  readonly property var all: app ? app.store.allCards : []
  readonly property var filtered: Cards.filterCards(all, filters)
  readonly property bool filtering: filters.query !== "" || selectedFilters.length > 0
  readonly property var stateList: Cards.stateCounts(all)
  readonly property int deckSize: Math.max(1, all.length)
  readonly property var tags: Cards.tagCounts(all)
  // The filter section: open, or folded down to what is selected; and the
  // tags, the most common few or every one.
  property bool filtersOpen: true
  property bool tagsOpen: false
  property real asideHeight: 0
  readonly property var unpickedTags: tags.filter(function(t) { return t.tag !== filters.tag })
  readonly property var tagsShown: tagsOpen ? unpickedTags : unpickedTags.slice(0, Theme.cardsTagsShown)
  readonly property int tagsHidden: unpickedTags.length - tagsShown.length
  // What narrows the grid, in the order the section lists it.
  readonly property var selectedFilters: Cards.selectedFilters(filters)
  readonly property var decks: Cards.deckNames(all)

  // Where the walk is: the stage's card is filtered[current], the grid
  // shows filtered[current + 1 ...].
  readonly property int current: flip.index
  readonly property int upNextCount: Math.max(0, filtered.length - current - 1)

  // ---- the window's status line (StatusLine.qml reads these) -----------------
  readonly property var statusSegments: {
    var segs = [{ text: filtered.length ? (current + 1) + "/" + filtered.length : "0/0" }]
    var summary = Cards.filterSummary(filters)
    if (summary !== "") segs.push({ text: summary, color: Theme.accentColor })
    return segs
  }
  // The stage's keys (FlipThrough's): Space or Enter flips, ← or h and → or
  // l page; and Del, this screen's. They live here, not on the stage, so the
  // screen stays quiet.
  readonly property var statusHints: [
    { keys: "space", label: "flip", run: function() { root.flipStage() } },
    { keys: "←", label: "back", run: function() { root.page(-1) } },
    { keys: "→", label: "next", run: function() { root.page(1) } },
    { keys: "del", label: "delete", run: function() { root.askDelete() } }
  ]
  readonly property var statusAlerts: filtered.length === 0 && all.length > 0
    ? [{ text: "no card matches", color: Theme.orangeText, tip: "Clear the filters", run: function() { root.clearFilters() } }]
    : []

  function flipStage() { flip.flipped = !flip.flipped }
  function page(d) { flip.move(d) }

  // ---- deleting the stage's card ----------------------------------------------
  // Del (or its hint) asks first, in the window's ConfirmDialog, which quotes
  // the card's front; Enter or the red Delete deletes it. The deck server
  // deletes the card and its history (flashcard-mcp's deleteCard, the call
  // the leech panel makes), and the walk goes on at the next card. The card
  // is the one on the stage when Del was pressed, held here, so nothing that
  // happens while the dialog is open can change which card goes.
  function askDelete() {
    var card = flip.card
    if (!card) return
    app.confirm("Delete this card?", tileTexts[card.id] || "",
                "Its review history goes with it. This cannot be undone.",
                "Delete", function() { root.deleteCard(card) })
  }

  function deleteCard(card) {
    app.store.deck.call("deleteCard", { cardId: card.id }, function(err) {
      if (err) { app.toast("deck: " + err); return }
      if (flip.card && flip.card.id === card.id) flip.leaveCurrent()
      app.store.refreshDeck()
    })
  }

  // A "change" to the same value is none: the field's pause timer sets the
  // text it already has after clearFilters(), and a new object would start
  // the walk over.
  function setFilter(kind, value) {
    if (filters[kind] === value) return
    var f = Object.assign({}, filters)
    f[kind] = value
    filters = f
  }

  function clearFilters() {
    search.text = ""
    filters = { query: "", state: "", deck: "", tag: "" }
  }

  // Each card's front as plain text, worked out once per load of the deck
  // rather than in every tile each time the grid is rebuilt.
  readonly property var tileTexts: {
    var m = {}
    all.forEach(function(c) { m[c.id] = Format.stripHtml(c.front) })
    return m
  }

  // A tile's caption: the deck only when there are several (one deck's
  // name on every tile says nothing), then the card's first tags and lapses.
  function tileCaption(card) {
    var parts = []
    if (decks.length > 1) parts.push(card.deck)
    var tags = (card.tags || []).slice(0, 2).map(function(t) { return "#" + t }).join(" ")
    if (tags !== "") parts.push(tags)
    if (card.lapses > 0) parts.push(Format.plural(card.lapses, "lapse"))
    return parts.join(" · ")
  }

  // A tile was clicked: its card goes on the stage, front up, and the page
  // scrolls back up to the stage if it was scrolled past it.
  function showCard(i) {
    flip.show(i)
    flip.forceActiveFocus()
    var y = Math.max(0, stageColumn.mapToItem(flick.contentItem, 0, 0).y - Theme.spaceXl)
    if (y < flick.contentY) flick.contentY = y
  }

  // The stage takes the keyboard when the screen is shown (the window's
  // focusScreen()), so Space and the arrows work without a click first;
  // keys it doesn't use (Ctrl+K, /, Alt+←) travel up to the window.
  function takeFocus() {
    if (!root.visible || root.filtered.length === 0) return false
    flip.forceActiveFocus()
    return true
  }

  onVisibleChanged: if (visible && app) app.store.refreshDeck()
  onFiltersChanged: flip.forget()

  // Del reaches here from the stage, which passes on the keys it doesn't
  // use; from the filter field it deletes text, as it should.
  Keys.onPressed: function(event) {
    if (event.key !== Qt.Key_Delete || event.modifiers !== Qt.NoModifier || !flip.activeFocus) return
    root.askDelete()
    event.accepted = true
  }

  GlideFlickable {
    id: flick
    anchors.fill: parent
    contentHeight: col.implicitHeight + Theme.space3xl * 2
    ScrollBar.vertical: ScrollBar {}

    Column {
      id: col
      x: Theme.pageX(root.width, Theme.cardsMeasure)
      y: Theme.space3xl
      width: Theme.pageWidth(root.width, Theme.cardsMeasure)
      spacing: Theme.spaceXl

      Column {
        spacing: Theme.spaceXs
        UiText { text: "Cards"; font.pixelSize: Theme.displaySize; font.bold: true }
        UiText {
          text: Format.plural(root.all.length, "card") + " · " + Format.plural(root.decks.length, "deck")
          font.pixelSize: Theme.bodySmallSize
          color: Theme.dim
        }
      }

      // ---- the stage, and retention and the filters beside it ------------------
      // Side by side while the stage keeps its minimum width, with a hairline
      // between them; below that the aside goes above the stage, so the stage
      // stays next to the grid it walks through. Placed by x and y, never by
      // switching anchors (layout rule 6).
      Item {
        id: top
        width: parent.width
        readonly property bool sideBySide: width >= Theme.cardStageMinWidth + Theme.space3xl + Theme.cardsAsideWidth
        readonly property real stageWidth: sideBySide ? width - Theme.cardsAsideWidth - Theme.space3xl : width
        height: sideBySide ? stageColumn.implicitHeight
                           : aside.implicitHeight + Theme.space2xl + stageColumn.implicitHeight

        Column {
          id: stageColumn
          y: top.sideBySide ? 0 : aside.implicitHeight + Theme.space2xl
          width: top.stageWidth
          spacing: Theme.spaceSm

          FlipThrough {
            id: flip
            objectName: "cardsStage"
            visible: root.filtered.length > 0
            width: parent.width
            cards: root.filtered
            stage: true
            // As tall as the column beside it, so neither leaves a gap or
            // cuts the other off.
            stageHeight: top.sideBySide ? root.asideHeight : 0
          }

          // Clearing is the filter header's "clear" (and the status line's
          // alert), so this only says why the stage is empty.
          UiText {
            visible: root.filtered.length === 0 && root.all.length > 0
            text: "No card matches these filters."
            color: Theme.dim
          }
        }

        Rectangle {
          visible: top.sideBySide
          x: top.stageWidth + Theme.space3xl / 2
          width: Theme.hairlineWidth
          height: top.height
          color: Theme.hairline
        }

        // Retention and the filters, exactly as tall as the stage beside it:
        // longer content (every tag shown) scrolls inside the column rather
        // than growing it, so the stage never stretches and no gap opens
        // under either side.
        GlideFlickable {
          id: asideView
          objectName: "cardsAside"
          x: top.sideBySide ? top.stageWidth + Theme.space3xl : 0
          width: top.sideBySide ? Theme.cardsAsideWidth : top.width
          height: top.sideBySide ? stageColumn.implicitHeight : aside.implicitHeight
          contentHeight: aside.implicitHeight
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: asideView.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        Column {
          id: aside
          width: asideView.width
          spacing: Theme.spaceXl
          // The stage follows the column's height, but not while every tag
          // is listed: that list scrolls inside the column instead, so the
          // card doesn't stretch to the length of a tag list.
          Binding {
            target: root
            property: "asideHeight"
            value: aside.implicitHeight
            when: !root.tagsOpen
            restoreMode: Binding.RestoreNone
          }

          // ---- retention ----------------------------------------------------------
          Column {
            objectName: "retentionPanel"
            width: parent.width
            spacing: Theme.spaceSm
            SectionLabel { text: "Retention · " + (root.calibration ? root.calibration.window_days : 30) + " days" }
            Row {
              spacing: Theme.spaceMd
              UiText {
                id: retentionFigure
                text: root.calibration && root.calibration.true_retention !== null ? Format.pct(root.calibration.true_retention) : "–"
                font.pixelSize: Theme.headingSize
                font.bold: true
                color: root.calibration ? Theme.verdictColor(root.calibration.verdict) : Theme.faint
              }
              UiText {
                anchors.baseline: retentionFigure.baseline
                text: root.calibration ? root.calibration.verdict + (root.calibration.marginal ? " (marginal)" : "") + " · " + Format.plural(root.calibration.reviews, "review") : "loading…"
                font.pixelSize: Theme.bodySmallSize
                color: root.calibration ? Theme.verdictColor(root.calibration.verdict) : Theme.faint
              }
            }
            Flow {
              visible: root.calibration !== null
              width: parent.width
              spacing: Theme.spaceLg
              Repeater {
                model: root.calibration ? [1, 2, 3, 4] : []
                delegate: UiText {
                  id: mixItem
                  required property int modelData
                  readonly property string name: Format.ratingName(mixItem.modelData).toLowerCase()
                  text: root.calibration.rating_mix[mixItem.name] + " " + mixItem.name
                  font.pixelSize: Theme.bodySmallSize
                  color: Theme.ratingColor(mixItem.modelData)
                }
              }
            }
          }

          // ---- filters -------------------------------------------------------------
          // The header folds the whole section away, leaving only what is
          // selected. The selected filters always sit on top, each with ✕,
          // so what narrows the grid is never lost among the choices; under
          // them the field and what is left to choose: states, decks, and
          // the most common tags, the rest one click away ("N more tags").
          Column {
            width: parent.width
            spacing: Theme.spaceSm

            Item {
              width: parent.width
              height: Theme.smallControlHeight
              PlainButton {
                objectName: "filtersToggle"
                x: -inset
                anchors.verticalCenter: parent.verticalCenter
                label: (root.filtersOpen ? "▾ " : "▸ ") + "FILTER"
                onActivated: root.filtersOpen = !root.filtersOpen
              }
              Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceMd
                PlainButton { objectName: "clearFilters"; visible: root.filtering; label: "clear"; onActivated: root.clearFilters() }
                UiText {
                  objectName: "filteredCount"
                  text: Format.plural(root.filtered.length, "card")
                  font.pixelSize: Theme.captionSize; color: Theme.dim
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            // What is selected, on top: a click drops it. The chips' own
            // padding is pulled out past the column's edges, so their words
            // line up with the field's.
            Flow {
              objectName: "selectedFilters"
              visible: root.selectedFilters.length > 0
              x: -Theme.chipInset
              width: parent.width + Theme.chipInset * 2
              Repeater {
                model: root.selectedFilters
                delegate: Chip {
                  id: picked
                  required property var modelData
                  objectName: "selected:" + picked.modelData.kind + ":" + picked.modelData.value
                  label: picked.modelData.label + " ✕"
                  dot: picked.modelData.kind === "state" ? Theme.stateColor(picked.modelData.value) : "transparent"
                  selected: true
                  onActivated: root.setFilter(picked.modelData.kind, "")
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
              Timer { id: queryPause; interval: Theme.searchDebounce; onTriggered: root.setFilter("query", search.text) }
              Keys.onEscapePressed: { text = ""; root.app.focusScreen() }
            }

            Column {
              visible: root.filtersOpen
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
                    width: aside.width * stateSegment.modelData.count / root.deckSize
                    height: Theme.statBarHeight
                    color: Theme.stateColor(stateSegment.modelData.state)
                    opacity: root.filters.state === "" || root.filters.state === stateSegment.modelData.state ? 1 : 0.3
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setFilter("state", root.filters.state === stateSegment.modelData.state ? "" : stateSegment.modelData.state) }
                  }
                }
              }
              Flow {
                x: -Theme.chipInset
                width: parent.width + Theme.chipInset * 2
                Repeater {
                  model: root.stateList.filter(function(s) { return s.state !== root.filters.state })
                  delegate: Chip {
                    id: stateLink
                    required property var modelData
                    objectName: "stateChip:" + stateLink.modelData.state
                    label: stateLink.modelData.state
                    count: stateLink.modelData.count
                    dot: Theme.stateColor(stateLink.modelData.state)
                    onActivated: root.setFilter("state", stateLink.modelData.state)
                  }
                }
              }
              Flow {
                x: -Theme.chipInset
                width: parent.width + Theme.chipInset * 2
                visible: root.decks.length > 1
                Repeater {
                  model: root.decks.filter(function(d) { return d !== root.filters.deck })
                  delegate: Chip {
                    id: deckLink
                    required property var modelData
                    label: deckLink.modelData
                    onActivated: root.setFilter("deck", deckLink.modelData)
                  }
                }
              }
              Flow {
                x: -Theme.chipInset
                width: parent.width + Theme.chipInset * 2
                Repeater {
                  model: root.tagsShown
                  delegate: Chip {
                    id: tagLink
                    required property var modelData
                    objectName: "tagChip:" + tagLink.modelData.tag
                    label: "#" + tagLink.modelData.tag
                    count: tagLink.modelData.count
                    onActivated: root.setFilter("tag", tagLink.modelData.tag)
                  }
                }
              }
              PlainButton {
                objectName: "moreTags"
                x: -inset
                visible: root.tagsHidden > 0 || root.tagsOpen
                label: root.tagsOpen ? "fewer tags ▴" : root.tagsHidden + " more tags ▾"
                onActivated: root.tagsOpen = !root.tagsOpen
              }
            }
          }
        }
        }
      }

      // ---- the grid: what comes after the stage's card ----------------------------
      Column {
        width: parent.width
        spacing: Theme.spaceMd
        visible: root.filtered.length > 0

        Item {
          width: parent.width
          height: Theme.smallControlHeight
          SectionLabel {
            objectName: "upNext"
            anchors.verticalCenter: parent.verticalCenter
            text: root.upNextCount > 0
              ? "Next up · " + root.upNextCount + (root.current > 0 ? " · " + root.current + " passed" : "")
              : "That was the last card"
          }
          PlainButton {
            objectName: "cardsRestart"
            visible: root.current > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: "from the start"
            onActivated: root.showCard(0)
          }
        }

        // Every tile as tall as a full one (its caption and cardTileLines
        // lines of front), measured off this unseen copy as Home's topic
        // tiles are, so it follows the theme's type without a typed height.
        // Positioners skip an invisible item, so it takes no room.
        Column {
          id: fullTile
          visible: false
          spacing: Theme.spaceXs
          UiText { text: "X"; font.pixelSize: Theme.captionSize }
          UiText {
            textFormat: Text.PlainText
            text: new Array(Theme.cardTileLines).fill("X").join("\n")
            font.pixelSize: Theme.bodySmallSize
            lineHeight: Theme.proseLineHeight
          }
        }

        Grid {
          id: grid
          width: parent.width
          columnSpacing: Theme.spaceXl
          rowSpacing: Theme.spaceSm
          columns: Math.max(1, Math.min(Theme.cardTileMaxColumns, Math.floor((width + columnSpacing) / (Theme.cardTileMinWidth + columnSpacing))))
          readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

          // One delegate per filtered card, built once per list; a passed
          // card's tile is hidden, not removed, and the Grid closes the gap.
          // A model sliced at the current card was the obvious way, and
          // rejected: a JS array model is rebuilt whole on every change, so
          // each → would have rebuilt some 350 tiles. Tiles are plain text
          // (Format.stripHtml), not rich text, which is what makes building
          // the whole deck at once cheap enough.
          Repeater {
            model: root.visible ? root.filtered : []
            delegate: Item {
              id: tile
              required property var modelData
              required property int index
              objectName: "cardTile:" + tile.modelData.id
              visible: tile.index > root.current
              width: grid.cellWidth
              height: fullTile.implicitHeight + Theme.spaceMd * 2

              // The hover fill bleeds into the column gap; the text keeps to
              // the column's edge (layout rule 3).
              Rectangle {
                x: -Theme.spaceSm
                width: parent.width + Theme.spaceSm * 2
                height: parent.height
                color: tileArea.containsMouse ? Theme.hoverFill : "transparent"
              }
              Rectangle { width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }

              Column {
                y: Theme.spaceMd
                width: parent.width
                spacing: Theme.spaceXs
                Item {
                  width: parent.width
                  height: tileCaption.implicitHeight
                  Rectangle {
                    id: tileDot
                    width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.stateColor(Cards.stateOf(tile.modelData))
                  }
                  UiText {
                    id: tileCaption
                    x: tileDot.width + Theme.spaceSm
                    width: parent.width - x - tileNumber.implicitWidth - Theme.spaceSm
                    elide: Text.ElideRight
                    text: root.tileCaption(tile.modelData)
                    font.pixelSize: Theme.captionSize
                    color: Theme.faint
                  }
                  UiText {
                    id: tileNumber
                    anchors.right: parent.right
                    text: tile.index + 1
                    font.pixelSize: Theme.captionSize
                    color: Theme.faint
                  }
                }
                UiText {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: root.tileTexts[tile.modelData.id] || ""
                  font.pixelSize: Theme.bodySmallSize
                  lineHeight: Theme.proseLineHeight
                  wrapMode: Text.Wrap
                  maximumLineCount: Theme.cardTileLines
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: tileArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showCard(tile.index)
              }
            }
          }
        }
      }
    }
  }
}
