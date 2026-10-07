pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Cards.js" as Cards
import "Format.js" as Format

// The whole deck, the viewer's /flashcards: retention over the last 30 days
// with the calibration verdict (flashcard-mcp's, shown verbatim), a state bar
// that filters, deck, tag and text filters, then the cards as a list or one
// at a time.
Item {
  id: root

  property var app: null
  property string query: ""
  property string stateFilter: ""
  property string deckFilter: ""
  property string tagFilter: ""
  property string mode: "list"
  readonly property var calibration: app && app.store.overview ? app.store.overview.calibration : null

  readonly property var all: app ? app.store.allCards : []
  readonly property var filtered: Cards.filterCards(all, { query: query, state: stateFilter, tag: tagFilter, deck: deckFilter })
  readonly property var stateList: Cards.stateCounts(all)
  readonly property int deckSize: Math.max(1, all.length)
  readonly property var tags: Cards.tagCounts(all).slice(0, 14)
  readonly property var decks: Cards.deckNames(all)

  onVisibleChanged: if (visible && app) app.store.refreshDeck()

  GlideFlickable {
    id: flick
    anchors.fill: parent
    contentHeight: col.implicitHeight + Theme.space3xl * 2
    ScrollBar.vertical: ScrollBar {}

    Column {
      id: col
      x: Theme.pageX(root.width)
      y: Theme.space3xl
      width: Theme.pageWidth(root.width)
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

      // ---- retention -----------------------------------------------------------
      Rectangle {
        objectName: "retentionPanel"
        width: parent.width
        height: retCol.implicitHeight + Theme.spaceLg * 2
        color: Theme.fill
        border.color: Theme.hairline
        border.width: Theme.borderWidth
        Column {
          id: retCol
          x: Theme.spaceLg; y: Theme.spaceLg
          width: parent.width - Theme.spaceLg * 2
          spacing: Theme.spaceSm
          Row {
            spacing: Theme.spaceMd
            UiText {
              text: root.calibration && root.calibration.true_retention !== null ? Format.pct(root.calibration.true_retention) : "–"
              font.pixelSize: Theme.displaySize
              font.bold: true
              color: root.calibration ? Theme.verdictColor(root.calibration.verdict) : Theme.faint
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              UiText {
                text: "true retention, last " + (root.calibration ? root.calibration.window_days : 30) + " days"
                font.pixelSize: Theme.bodySmallSize; color: Theme.dim
              }
              UiText {
                text: root.calibration ? root.calibration.verdict + (root.calibration.marginal ? " (marginal)" : "") + " · " + Format.plural(root.calibration.reviews, "review") : "loading…"
                font.pixelSize: Theme.bodySmallSize
                color: root.calibration ? Theme.verdictColor(root.calibration.verdict) : Theme.faint
              }
            }
          }
          UiText {
            visible: root.calibration !== null && root.calibration.reasons.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            text: root.calibration ? root.calibration.reasons.join(" ") : ""
            font.pixelSize: Theme.captionSize; color: Theme.faint
          }
          Row {
            visible: root.calibration !== null
            spacing: Theme.spaceLg
            Repeater {
              model: root.calibration ? [
                { n: 1, label: "again", v: root.calibration.rating_mix.again },
                { n: 2, label: "hard", v: root.calibration.rating_mix.hard },
                { n: 3, label: "good", v: root.calibration.rating_mix.good },
                { n: 4, label: "easy", v: root.calibration.rating_mix.easy }
              ] : []
              delegate: UiText {
                id: mixItem
                required property var modelData
                text: mixItem.modelData.v + " " + mixItem.modelData.label
                font.pixelSize: Theme.captionSize
                color: Theme.ratingColor(mixItem.modelData.n)
              }
            }
          }
        }
      }

      // ---- the state bar: click a state to filter ----------------------------------------
      Column {
        width: parent.width
        spacing: Theme.spaceSm
        Row {
          width: parent.width
          Repeater {
            model: root.stateList
            delegate: Rectangle {
              id: stateSegment
              required property var modelData
              objectName: "stateBar:" + stateSegment.modelData.state
              width: col.width * stateSegment.modelData.count / root.deckSize
              height: Theme.statBarHeight * 2
              color: Theme.stateColor(stateSegment.modelData.state)
              opacity: root.stateFilter === "" || root.stateFilter === stateSegment.modelData.state ? 1 : 0.3
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.stateFilter = root.stateFilter === stateSegment.modelData.state ? "" : stateSegment.modelData.state }
            }
          }
        }
        Flow {
          width: parent.width
          spacing: Theme.spaceSm
          Repeater {
            model: root.stateList
            delegate: Chip {
              id: stateChipItem
              required property var modelData
              objectName: "stateChip:" + stateChipItem.modelData.state
              label: stateChipItem.modelData.state
              count: stateChipItem.modelData.count
              dot: Theme.stateColor(stateChipItem.modelData.state)
              selected: root.stateFilter === stateChipItem.modelData.state
              onActivated: root.stateFilter = selected ? "" : stateChipItem.modelData.state
            }
          }
        }
      }

      // ---- filters --------------------------------------------------------------------------
      Column {
        width: parent.width
        spacing: Theme.spaceSm
        TextField {
          id: search
          objectName: "cardFilter"
          width: parent.width
          placeholderText: "Filter by text"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.bodySize
          color: Theme.ink
          placeholderTextColor: Theme.faint
          background: Rectangle { color: Theme.fill; border.color: search.activeFocus ? Theme.accentColor : Theme.hairline; border.width: Theme.borderWidth }
          onTextChanged: root.query = text
          Keys.onEscapePressed: { text = ""; root.app.contentRootFocus() }
        }
        Flow {
          width: parent.width
          spacing: Theme.spaceSm
          visible: root.decks.length > 1
          Repeater {
            model: root.decks
            delegate: Chip {
              id: deckChip
              required property var modelData
              label: deckChip.modelData
              selected: root.deckFilter === deckChip.modelData
              onActivated: root.deckFilter = selected ? "" : deckChip.modelData
            }
          }
        }
        Flow {
          width: parent.width
          spacing: Theme.spaceSm
          Repeater {
            model: root.tags
            delegate: Chip {
              id: tagChipItem
              required property var modelData
              objectName: "tagChip:" + tagChipItem.modelData.tag
              label: "#" + tagChipItem.modelData.tag
              count: tagChipItem.modelData.count
              selected: root.tagFilter === tagChipItem.modelData.tag
              onActivated: root.tagFilter = selected ? "" : tagChipItem.modelData.tag
            }
          }
        }
      }

      Row {
        spacing: Theme.spaceSm
        UiText {
          objectName: "filteredCount"
          text: Format.plural(root.filtered.length, "card")
          font.pixelSize: Theme.bodySmallSize; color: Theme.dim
          anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: Theme.spaceLg; height: Theme.hairlineWidth }
        Chip { label: "List"; selected: root.mode === "list"; onActivated: root.mode = "list" }
        Chip { objectName: "cardsFlipMode"; label: "Flip through"; selected: root.mode === "flip"; onActivated: { root.mode = "flip"; flip.forceActiveFocus() } }
        ActionButton {
          visible: root.query !== "" || root.stateFilter !== "" || root.tagFilter !== "" || root.deckFilter !== ""
          small: true
          label: "Clear filters"
          onActivated: { search.text = ""; root.stateFilter = ""; root.tagFilter = ""; root.deckFilter = "" }
        }
      }

      FlipThrough {
        id: flip
        visible: root.mode === "flip"
        width: parent.width
        height: Theme.cardFaceMinHeight * 2
        cards: root.mode === "flip" ? root.filtered : []
      }

      Column {
        visible: root.mode === "list"
        width: parent.width
        spacing: Theme.spaceSm
        Repeater {
          // Long lists are paged: a Column of 350 rich-text tiles is slow to build.
          model: root.visible && root.mode === "list" ? root.filtered.slice(0, shown.count) : []
          delegate: CardTile {
            id: cardItem
            required property var modelData
            width: col.width
            card: cardItem.modelData
          }
        }
        ActionButton {
          id: shown
          property int count: 60
          visible: root.filtered.length > count
          small: true
          label: "Show more (" + (root.filtered.length - count) + " left)"
          onActivated: count += 60
        }
      }
    }
  }
}
