pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Cards.js" as Cards
import "Format.js" as Format
import "NoteEdit.js" as NoteEdit

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
//
// The filter column is as tall as its content and never scrolls: it shows
// the most common few tags, and "N more tags" opens the rest in a sheet from
// the right (TagPanel.qml) with a field to find one. It used to unfold every
// tag in place and scroll inside the column; the user found a scrolling list
// beside the stage hard to use, and the column's clip cut the outline of a
// picked chip.
Item {
  id: root

  required property App app
  // What narrows the grid: the text, one state and deck at most ("" for
  // any), and any number of tags, all of which a card must carry
  // (Cards.filterCards). Changed only through setFilter(), addTag() and
  // dropTag(), as a new object, so every binding on it updates.
  // `noted` keeps only the cards with a note (Ctrl+N in Study), and then
  // "fix it" hands those to Claude Code.
  property var filters: ({ query: "", state: "", deck: "", tags: [], noted: false })
  readonly property var calibration: app.store.overview ? app.store.overview.calibration : null

  readonly property var all: app.store.allCards
  readonly property var notes: app.store.notes
  readonly property var filtered: Cards.filterCards(all, filters, notes)
  // The states, counted over what every filter but the state leaves, so
  // the bar shows how the picked tags' cards split, and switching from one
  // state to another stays one click (counting over `filtered` would leave
  // only the picked state).
  readonly property var stateBase: filters.state === "" ? filtered : Cards.filterCards(all, Object.assign({}, filters, { state: "" }), notes)
  readonly property var stateList: Cards.stateCounts(stateBase)
  readonly property int stateTotal: Math.max(1, stateBase.length)
  // The tags still worth picking: those of the cards the filters left, less
  // the picked ones, each counted as the cards a pick would leave. Counting
  // over the whole deck instead offered tags that would empty the grid.
  readonly property var tags: Cards.tagCounts(filtered, filters.tags)
  // The filter section (CardFilters.qml): open, or folded down to what is
  // selected. Its tags are the most common tagLimit (a property so a test
  // with a small deck can lower it); the rest are in the tag panel.
  property alias filtersOpen: filterSection.open
  property int tagLimit: Theme.cardsTagsShown
  readonly property var tagsShown: tags.slice(0, tagLimit)
  readonly property int tagsHidden: tags.length - tagsShown.length
  readonly property bool tagPanelOpen: tagPanel.opened
  readonly property var decks: Cards.deckNames(all)
  // How many of the cards the filters leave have a note: the "noted" chip.
  readonly property int notedHere: Cards.notedCount(filtered, notes)
  // The stage's card's note, if it has one.
  readonly property var stageNote: flip.card ? notes[flip.card.id] || null : null

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
  // While the tag panel is up its keys replace them: the stage has no
  // keyboard then.
  readonly property var statusHints: tagPanel.opened ? tagPanel.statusHints : [
    { keys: "space", label: "flip", run: function() { root.flipStage() } },
    { keys: "←", label: "back", run: function() { root.page(-1) } },
    { keys: "→", label: "next", run: function() { root.page(1) } },
    { keys: "n", label: "note", run: function() { root.noteStage() } },
    { keys: "del", label: "delete", run: function() { root.askDelete() } }
  ]
  readonly property var statusAlerts: filtered.length === 0 && all.length > 0
    ? [{ text: "no card matches", color: Theme.orangeText, tip: "Clear the filters", run: function() { root.clearFilters() } }]
    : []

  function flipStage() { flip.flipped = !flip.flipped }
  // The stage's card's note, new or as it is (NoteDialog.qml).
  function noteStage() { if (flip.card) app.openNote(flip.card, "") }
  // The noted cards the filters leave, to Claude Code in one session. Its
  // button shows only with the noted filter on, so `filtered` is all noted.
  function fixNoted() {
    app.fixNotes(filtered.map(function(c) { return c.id }))
  }
  function page(d) { flip.move(d) }

  // ---- deleting the stage's card ----------------------------------------------
  // Del (or its hint) asks first, in the window's ConfirmDialog, which quotes
  // the card's front; Enter or the red Delete deletes it. The deck server
  // deletes the card and its history (Store.deleteCard, as Study and the
  // leech panel do), and the walk goes on at the next card. The card is the
  // one on the stage when Del was pressed, held here, so nothing that
  // happens while the dialog is open can change which card goes.
  function askDelete() {
    var card = flip.card
    if (!card) return
    app.confirmDeleteCard(card, function() { root.deleteCard(card) })
  }

  function deleteCard(card) {
    app.store.deleteCard(card.id, function(err) {
      if (err) { app.toast("deck: " + err); return }
      if (flip.card && flip.card.id === card.id) flip.leaveCurrent()
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

  function addTag(tag) {
    if (filters.tags.indexOf(tag) === -1) setFilter("tags", filters.tags.concat([tag]))
  }

  function dropTag(tag) {
    setFilter("tags", filters.tags.filter(function(t) { return t !== tag }))
  }

  // A selected chip's ✕: a tag leaves the list, a state or deck goes back
  // to "any".
  function dropFilter(kind, value) {
    if (kind === "tag") dropTag(value)
    else if (kind === "noted") setFilter("noted", false)
    else setFilter(kind, "")
  }

  function clearFilters() {
    filterSection.clearText()
    filters = { query: "", state: "", deck: "", tags: [], noted: false }
  }

  function openTags() { tagPanel.open() }
  function closeTags() { tagPanel.close() }

  // Each card's front as plain text, worked out once per load of the deck
  // rather than in every tile each time the grid is rebuilt.
  readonly property var tileTexts: {
    var m = {}
    all.forEach(function(c) { m[c.id] = Format.stripHtml(c.front) })
    return m
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
    if (root.visible && tagPanel.opened) { tagPanel.focusField(); return true }
    if (!root.visible || root.filtered.length === 0) return false
    flip.forceActiveFocus()
    return true
  }

  // Leaving the screen (Alt+←, the rail) leaves the tag panel shut, so a
  // return finds the stage, not a sheet left over from before.
  onVisibleChanged: {
    if (!visible) tagPanel.opened = false
    else app.store.checkDeck()
  }
  onFiltersChanged: flip.forget()

  // Del reaches here from the stage, which passes on the keys it doesn't
  // use; from the filter field it deletes text, as it should.
  // N notes the stage's card, as Ctrl+N does a card in Study (here Ctrl+N
  // stays the window's Add).
  Keys.onPressed: function(event) {
    if (event.modifiers !== Qt.NoModifier || !flip.activeFocus) return
    if (event.key === Qt.Key_Delete) root.askDelete()
    else if (event.key === Qt.Key_N) root.noteStage()
    else return
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
        id: topRow
        width: parent.width
        readonly property bool sideBySide: width >= Theme.cardStageMinWidth + Theme.space3xl + Theme.cardsAsideWidth
        readonly property real stageWidth: sideBySide ? width - Theme.cardsAsideWidth - Theme.space3xl : width
        height: sideBySide ? stageColumn.implicitHeight
                           : aside.implicitHeight + Theme.space2xl + stageColumn.implicitHeight

        Column {
          id: stageColumn
          y: topRow.sideBySide ? 0 : aside.implicitHeight + Theme.space2xl
          width: topRow.stageWidth
          spacing: Theme.spaceSm

          FlipThrough {
            id: flip
            objectName: "cardsStage"
            visible: root.filtered.length > 0
            width: parent.width
            cards: root.filtered
            stage: true
            // As tall as the column beside it, or its own least height
            // (FlipThrough's) if the column is shorter, so the column never
            // runs past the card.
            stageHeight: topRow.sideBySide ? aside.implicitHeight : 0
          }

          // The stage card's note, its first line; a click opens it.
          MarkedRow {
            objectName: "stageNote"
            visible: root.stageNote !== null && root.filtered.length > 0
            width: parent.width
            icon: "pencil"
            text: root.stageNote ? "note: " + NoteEdit.firstLine(root.stageNote.body) : ""
            color: Theme.accentColor
            onActivated: root.noteStage()
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
          visible: topRow.sideBySide
          x: topRow.stageWidth + Theme.space3xl / 2
          width: Theme.hairlineWidth
          height: topRow.height
          color: Theme.hairline
        }

        // Retention and the filters. The stage takes this column's height,
        // which stays short because it lists only a few tags (the rest are
        // in the tag panel), so neither scrolls. Nothing clips it: a chip's
        // outline, drawn past its words (layout rule 2), stays whole.
        Column {
          id: aside
          objectName: "cardsAside"
          x: topRow.sideBySide ? topRow.stageWidth + Theme.space3xl : 0
          width: topRow.sideBySide ? Theme.cardsAsideWidth : topRow.width
          spacing: Theme.spaceXl

          RetentionPanel {
            width: parent.width
            calibration: root.calibration
          }

          CardFilters {
            id: filterSection
            width: parent.width
            filters: root.filters
            filteredCount: root.filtered.length
            notedHere: root.notedHere
            stateList: root.stateList
            stateTotal: root.stateTotal
            decks: root.decks
            tagsShown: root.tagsShown
            tagsHidden: root.tagsHidden
            onFilterSet: function(kind, value) { root.setFilter(kind, value) }
            onFilterDropped: function(kind, value) { root.dropFilter(kind, value) }
            onTagAdded: function(tag) { root.addTag(tag) }
            onClearRequested: root.clearFilters()
            onFixRequested: root.fixNoted()
            onMoreTagsRequested: root.openTags()
            onEscaped: root.app.focusScreen()
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

        CardGrid {
          id: grid
          width: parent.width

          // One delegate per filtered card, built once per list; a passed
          // card's tile is hidden, not removed, and the Grid closes the gap.
          // A model sliced at the current card was the obvious way, and
          // rejected: a JS array model is rebuilt whole on every change, so
          // each → would have rebuilt some 350 tiles. Tiles are plain text
          // (Format.stripHtml), not rich text, which is what makes building
          // the whole deck at once cheap enough.
          Repeater {
            model: root.visible ? root.filtered : []
            delegate: CardTile {
              id: tile
              required property var modelData
              required property int index
              objectName: "cardTile:" + tile.modelData.id
              visible: tile.index > root.current
              width: grid.cellWidth
              height: grid.tileHeight
              card: tile.modelData
              caption: Cards.tileCaption(tile.modelData, root.decks.length > 1, !!root.notes[tile.modelData.id])
              number: tile.index + 1
              text: root.tileTexts[tile.modelData.id] || ""
              onClicked: root.showCard(tile.index)
            }
          }
        }
      }
    }
  }

  TagPanel {
    id: tagPanel
    anchors.fill: parent
    counts: root.tags
    selected: root.filters.tags
    cardCount: root.filtered.length
    onPicked: function(tag) { root.addTag(tag) }
    onDropped: function(tag) { root.dropTag(tag) }
    onClosed: root.app.focusScreen()
  }
}
