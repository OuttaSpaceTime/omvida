pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Cards.js" as Cards
import "Format.js" as Format
import "Launch.js" as Launch

// The wiki reader, the Next.js viewer's article view: the side panel (context
// or tree) on the left, the page in the reading column, its connections under
// it, and the local graph on the right when the window is wide enough. With
// no page open it shows a folder (the viewer's FolderView).
//
// The left panel's right edge drags it wider, as the graph rail's left edge
// does; over either of its modes it lists the pages a finished session
// pointed to (WikiSidePanel, app.studyPages).
//
// Either panel folds to a strip at its edge, `[` and `]` or the chevron in
// its corner, and stays as left while the app runs. The graph starts folded:
// it is for finding your way, not for reading, and a page read beside it got
// a narrower column for a picture that rarely changed. Folded, a panel leaves
// only its chevron: no edge and no fill, so the page reads as the whole
// screen, and the chevron keeps the panel one click from back. The strip
// still holds its width, so the chevron never sits over the page's text.
//
// The header's actions hand the page to Claude Code: cards on this page
// (/study-flashcard) and go deeper (/study-walkthrough --write). Its cards
// button opens the page's own flashcards, overview or flip-through.
Item {
  id: root

  property var app: null
  property var wikiService: null
  property var page: null        // { meta, blocks } from the wiki service
  property string loadedPath: ""
  property string loadError: ""
  property string pendingAnchor: ""   // a heading to scroll to once its page is in

  readonly property string path: app ? app.wikiPath : ""
  readonly property var meta: page ? page.meta : null
  readonly property var pageCards: meta && app ? Cards.cardsForPage(meta, app.store.allCards) : []
  // The graph rail's width: dragged by its left edge, kept while the app
  // runs, never so wide that the page loses its reading column.
  property real graphRailWidth: Theme.sidePanelWidth
  readonly property real graphRailMax: Math.max(Theme.sidePanelWidth, width - leftWidth - Theme.pageMeasure * 0.85)
  readonly property bool showGraph: width >= Theme.sidePanelWidth * 2 + Theme.pageMeasure * 0.85

  // The left panel's width: dragged by its right edge, as the graph rail is
  // by its left, kept while the app runs, never so wide that the page loses
  // its reading column: the page keeps 85% of its measure, as the graph rail
  // leaves it (60%, where the panel drops out, read as a column squeezed).
  property real sidePanelWidth: Theme.sidePanelWidth
  // The graph's own wish (graphRailWidth), not the width it gets: that one
  // depends on this panel's, and the two would bind in a loop.
  readonly property real sidePanelMax: Math.max(Theme.sidePanelWidth, width - Theme.pageMeasure * 0.85
                                                - (!graphFits ? 0 : (graphOpen ? graphRailWidth : Theme.collapsedPanelWidth)))
  readonly property real sideWidth: Math.min(sidePanelWidth, sidePanelMax)

  property bool sideOpen: true
  property bool graphOpen: false
  readonly property bool sideFits: width >= Theme.sidePanelWidth + Theme.pageMeasure * 0.6
  readonly property bool graphFits: showGraph && path !== ""
  // What each edge takes from the page: the panel, its folded strip, or
  // nothing when the window has no room for it.
  readonly property real leftWidth: !sideFits ? 0 : (sideOpen ? sideWidth : Theme.collapsedPanelWidth)
  readonly property real rightWidth: !graphFits ? 0 : (graphOpen ? graphRail.width : Theme.collapsedPanelWidth)

  // ---- the window's status line ---------------------------------------------
  // Where you are: the open page's file path, or the folder's.
  readonly property var statusSegments: {
    var f = root.app ? root.app.wikiFolder : ""
    return [{ text: root.path !== "" ? root.path : (f === "" ? "wiki" : f + "/") }]
  }
  // The panels' keys, while there is room to show them.
  readonly property var statusHints: {
    var h = []
    if (root.sideFits) h.push({ keys: "[", label: "panel", run: function() { root.sideOpen = !root.sideOpen } })
    if (root.graphFits) h.push({ keys: "]", label: "graph", run: function() { root.graphOpen = !root.graphOpen } })
    return h
  }

  // The screen holds the keyboard while shown so `[` and `]` reach it; the
  // keys it doesn't use travel up to the window. Matched on the character,
  // not the key code: on a German layout `[` is AltGr+8.
  function takeFocus() {
    if (!root.visible) return false
    root.forceActiveFocus()
    return true
  }
  // The keys are the hints': a panel with no room has neither.
  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
    var hint = root.statusHints.filter(function(h) { return h.keys === event.text })[0]
    if (!hint) return
    hint.run()
    event.accepted = true
  }

  // A panel folded: a strip at its edge holding only the icon that opens it
  // again. The button's fill reaches `inset` left of the glyph and ends
  // `inset` after it, so offsetting by `inset` centres the glyph. The glyph
  // is faint until hovered: a folded panel should not compete with the page,
  // and faint is the lightest grey that still meets the contrast floor
  // (layout rule 8).
  component FoldStrip: Item {
    id: strip
    property alias name: expand.objectName
    property alias icon: expand.icon
    property alias tip: expand.tip
    signal activated()
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Theme.collapsedPanelWidth
    PlainButton {
      id: expand
      anchors.horizontalCenter: parent.horizontalCenter
      y: Theme.spaceSm
      tint: expand.hovered ? Theme.ink : Theme.faint
      onActivated: strip.activated()
    }
  }

  // A panel's drag edge, on its inner side: `direction` 1 for the left
  // panel's right edge (dragging right widens it), -1 for the graph rail's
  // left. It reports the width the drag asks for; the panel clamps it.
  // Positions are taken in the scene (mapToItem(null)): only their change
  // counts, and an inline component cannot name this file's root.
  component DragEdge: MouseArea {
    id: edge
    property int direction: 1
    property real startX: 0
    property real startWidth: 0
    signal resized(real width)
    width: Theme.spaceSm
    height: parent.height
    cursorShape: Qt.SplitHCursor
    onPressed: function(m) { startX = mapToItem(null, m.x, 0).x; startWidth = parent.width }
    onPositionChanged: function(m) { edge.resized(startWidth + edge.direction * (mapToItem(null, m.x, 0).x - startX)) }
  }

  function openPageCards() { if (root.meta && root.pageCards.length) root.app.openPageCards(root.meta.title, root.pageCards) }

  function reloadPage() { if (root.path !== "") load(root.path, true) }

  function load(p, quiet) {
    if (!wikiService) return
    if (!quiet) { root.page = null; root.loadError = "" }
    wikiService.call("page", { path: p }, function(err, res) {
      if (p !== root.path) return
      if (err) { root.loadError = err; return }
      if (!res) { root.loadError = "No page at " + p; root.page = null; return }
      root.page = res
      root.loadedPath = p
      if (!quiet) { flick.contentY = 0; Qt.callLater(root.scrollToPending) }
    })
  }

  // Scrolls to a heading of the open page, now if the page is in, else once
  // load() has it.
  function scrollTo(anchor) {
    root.pendingAnchor = anchor
    if (anchor !== "" && root.page && root.loadedPath === root.path) Qt.callLater(root.scrollToPending)
  }

  function scrollToPending() {
    if (root.pendingAnchor === "") return
    var y = pageView.anchorY(root.pendingAnchor)
    if (y >= 0) flick.contentY = Math.min(Math.max(0, pageView.y + y - Theme.spaceLg), Math.max(0, flick.contentHeight - flick.height))
    root.pendingAnchor = ""
  }

  onPathChanged: if (path !== "") load(path, false)
  Connections {
    target: root.wikiService
    function onReadyChanged() { if (root.wikiService.ready && root.path !== "" && !root.page) root.load(root.path, false) }
  }

  WikiSidePanel {
    id: side
    app: root.app
    sections: root.page ? root.page.blocks.filter(function(b) { return b.kind === "heading" && b.level === 2 }) : []
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.sideWidth
    // Over the page, so the half of its drag edge that lies past it can be grabbed.
    z: 1
    visible: root.sideFits && root.sideOpen
    onSectionPicked: function(anchor) { root.scrollTo(anchor) }
    onCollapseRequested: root.sideOpen = false

    // The right edge drags the panel wider or narrower.
    DragEdge {
      objectName: "sidePanelHandle"
      x: parent.width - width / 2
      direction: 1
      onResized: function(w) { root.sidePanelWidth = Math.max(Theme.sidePanelMinWidth, Math.min(root.sidePanelMax, w)) }
    }
  }

  FoldStrip {
    visible: root.sideFits && !root.sideOpen
    anchors.left: parent.left
    name: "sidePanelExpand"
    icon: "collapseRight"
    tip: "Show the panel  ["
    onActivated: root.sideOpen = true
  }

  Item {
    id: centre
    anchors.left: parent.left
    anchors.leftMargin: root.leftWidth
    anchors.right: parent.right
    anchors.rightMargin: root.rightWidth
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    GlideFlickable {
      id: flick
      objectName: "wikiFlick"
      anchors.fill: parent
      contentHeight: col.implicitHeight + Theme.space3xl * 2
      ScrollBar.vertical: ScrollBar {}

      Column {
        id: col
        x: Theme.pageX(centre.width)
        y: Theme.space3xl
        width: Theme.pageWidth(centre.width)
        spacing: Theme.spaceLg

        // ---- a folder -----------------------------------------------------------
        FolderView {
          visible: root.path === ""
          width: parent.width
          app: root.app
          folderPath: root.app ? root.app.wikiFolder : ""
        }

        UiText {
          visible: root.path !== "" && root.loadError !== ""
          text: root.loadError
          color: Theme.redText
        }

        // ---- the page header ------------------------------------------------------
        Column {
          visible: root.path !== "" && root.meta !== null
          width: parent.width
          spacing: Theme.spaceSm

          UiText {
            text: root.meta ? ["wiki"].concat(root.meta.folder === "" ? [] : root.meta.folder.split("/")).join(" / ") : ""
            font.pixelSize: Theme.captionSize
            color: Theme.faint
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.app.openFolder(root.meta.folder) }
          }
          UiText {
            objectName: "pageTitle"
            width: parent.width
            wrapMode: Text.Wrap
            text: root.meta ? root.meta.title : ""
            font.pixelSize: Theme.displaySize
            font.bold: true
          }
          Flow {
            width: parent.width
            spacing: Theme.spaceMd
            Repeater {
              model: root.meta ? root.meta.tags : []
              delegate: UiText {
                id: tagItem
                required property var modelData
                text: "#" + tagItem.modelData
                font.pixelSize: Theme.captionSize
                color: Theme.topicColor(tagItem.modelData)
              }
            }
            // Capped at the column and wrapped: a page with many aliases drew
            // this line out past the column into the graph rail (rule 7).
            UiText {
              width: Math.min(implicitWidth, parent.width)
              wrapMode: Text.Wrap
              text: root.meta ? "updated " + root.meta.updated + (root.meta.aliases.length ? " · also " + root.meta.aliases.join(", ") : "") : ""
              font.pixelSize: Theme.captionSize
              color: Theme.faint
            }
          }
          // The page's actions as quiet text buttons: a row of three boxes
          // over the first paragraph read as a toolbar, louder than the page.
          Flow {
            width: parent.width
            spacing: Theme.spaceLg
            topPadding: Theme.spaceXs
            PlainButton {
              objectName: "pageCardsButton"
              tint: enabled ? Theme.accentColor : Theme.secondaryInk
              icon: "cards"
              label: root.pageCards.length > 0
                ? Format.plural(root.pageCards.length, "card") + ((root.meta && root.meta.flashcardIds.length === 0) ? " by tag" : "")
                : "No cards"
              enabled: root.pageCards.length > 0
              onActivated: root.openPageCards()
            }
            PlainButton {
              objectName: "pageAddCards"
              icon: "plus"
              label: "Cards on this page"
              onActivated: root.app.openAdd("flashcard", root.meta.title, "wiki page [[" + root.meta.path + "]]")
            }
            // One per explorable, main one first; "Explore 2" for the rest,
            // since a page rarely has more than one.
            Repeater {
              model: root.meta ? root.meta.explorables : []
              delegate: PlainButton {
                id: exploreButton
                required property string modelData
                required property int index
                objectName: "pageExplore" + exploreButton.index
                icon: "explore"
                label: exploreButton.index === 0 ? "Explore" : "Explore " + (exploreButton.index + 1)
                onActivated: root.app.launch(Launch.exploreArgv(exploreButton.modelData), "Opened the explorable")
              }
            }
            PlainButton {
              objectName: "pageDeeper"
              icon: "brain"
              label: "Go deeper"
              onActivated: root.app.launch(Launch.skillArgv(Paths.studyDir, "Omvida · Walkthrough", "/study-walkthrough",
                                                               root.meta.title, "wiki page [[" + root.meta.path + "]]"),
                                           "Opened Claude Code")
            }
          }
          Rectangle { width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }
        }

        PageView {
          id: pageView
          visible: root.path !== "" && root.page !== null
          width: parent.width
          app: root.app
          blocks: root.page ? root.page.blocks : []
        }

        // ---- connections: where did I come from, where can I go ----------------------
        Row {
          visible: root.meta !== null && root.path !== "" && (root.meta.inbound.length + root.meta.outbound.length) > 0
          width: parent.width
          spacing: Theme.spaceXl
          topPadding: Theme.space2xl
          Repeater {
            model: root.meta ? [
              { label: "← Linked from", paths: root.meta.inbound, empty: "nothing links here yet" },
              { label: "Links to →", paths: root.meta.outbound, empty: "no outgoing links" }
            ] : []
            delegate: Column {
              id: linkColumn
              required property var modelData
              width: (col.width - Theme.spaceXl) / 2
              spacing: Theme.spaceXs
              SectionLabel { divided: true; text: linkColumn.modelData.label }
              UiText {
                visible: linkColumn.modelData.paths.length === 0
                text: linkColumn.modelData.empty
                font.pixelSize: Theme.bodySmallSize
                color: Theme.faint
              }
              Repeater {
                model: linkColumn.modelData.paths
                delegate: ListRow {
                  id: linkRow
                  required property var modelData
                  width: (col.width - Theme.spaceXl) / 2
                  title: root.app.store.pagesByPath[linkRow.modelData] ? root.app.store.pagesByPath[linkRow.modelData].title : linkRow.modelData
                  topic: linkRow.modelData.split("/").slice(0, -1).join("/")
                  onActivated: root.app.openPage(linkRow.modelData, "")
                }
              }
            }
          }
        }
      }
    }
  }

  // The local graph: this page and two hops out (the viewer's graph rail).
  Rectangle {
    id: graphRail
    visible: root.graphFits && root.graphOpen
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.min(root.graphRailWidth, root.graphRailMax)
    color: Theme.paper
    Rectangle { width: Theme.hairlineWidth; height: parent.height; color: Theme.hairline }
    SectionLabel { x: Theme.spaceLg; y: Theme.spaceLg; text: "Neighbourhood" }
    // The whole graph screen, around this page; then folding the rail.
    Row {
      anchors.right: parent.right
      anchors.rightMargin: Theme.spaceLg
      y: Theme.spaceSm
      spacing: Theme.spaceLg
      PlainButton {
        objectName: "graphFullScreen"
        icon: "fullscreen"
        tip: "Open in the graph screen"
        onActivated: root.app.openGraph(true)
      }
      PlainButton {
        objectName: "graphCollapse"
        icon: "collapseRight"
        tip: "Hide the graph  ]"
        onActivated: root.graphOpen = false
      }
    }
    GraphView {
      anchors.fill: parent
      anchors.topMargin: Theme.space2xl + Theme.spaceSm
      app: root.app
      focusPath: root.path
      local: true
      compact: true
    }
    // The left edge drags the rail wider or narrower.
    DragEdge {
      objectName: "graphRailHandle"
      x: -width / 2
      direction: -1
      onResized: function(w) { root.graphRailWidth = Math.max(Theme.sidePanelMinWidth, Math.min(root.graphRailMax, w)) }
    }
  }

  FoldStrip {
    visible: root.graphFits && !root.graphOpen
    anchors.right: parent.right
    name: "graphExpand"
    icon: "collapseLeft"
    tip: "Show the graph  ]"
    onActivated: root.graphOpen = true
  }
}
