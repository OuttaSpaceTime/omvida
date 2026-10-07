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
  readonly property bool showGraph: width >= Theme.sidePanelWidth * 2 + Theme.pageMeasure * 0.85

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
    width: Theme.sidePanelWidth
    visible: root.width >= Theme.sidePanelWidth + Theme.pageMeasure * 0.6
    onSectionPicked: function(anchor) { root.scrollTo(anchor) }
  }

  Item {
    id: centre
    anchors.left: side.visible ? side.right : parent.left
    anchors.right: graphRail.visible ? graphRail.left : parent.right
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
            UiText {
              text: root.meta ? "updated " + root.meta.updated + (root.meta.aliases.length ? " · also " + root.meta.aliases.join(", ") : "") : ""
              font.pixelSize: Theme.captionSize
              color: Theme.faint
            }
          }
          Flow {
            width: parent.width
            spacing: Theme.spaceSm
            topPadding: Theme.spaceSm
            ActionButton {
              objectName: "pageCardsButton"
              small: true
              icon: "cards"
              label: root.pageCards.length > 0
                ? Format.plural(root.pageCards.length, "card") + ((root.meta && root.meta.flashcardIds.length === 0) ? " by tag" : "")
                : "No cards"
              enabled: root.pageCards.length > 0
              onActivated: root.openPageCards()
            }
            ActionButton {
              objectName: "pageAddCards"
              small: true
              icon: "plus"
              label: "Cards on this page"
              onActivated: root.app.openAdd("flashcard", root.meta.title, "wiki page [[" + root.meta.path + "]]")
            }
            ActionButton {
              objectName: "pageDeeper"
              small: true
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
              SectionLabel { text: linkColumn.modelData.label }
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
    visible: root.showGraph && root.path !== ""
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Theme.sidePanelWidth
    color: Theme.paper
    Rectangle { width: Theme.hairlineWidth; height: parent.height; color: Theme.hairline }
    SectionLabel { x: Theme.spaceLg; y: Theme.spaceLg; text: "Neighbourhood" }
    GraphView {
      anchors.fill: parent
      anchors.topMargin: Theme.space2xl + Theme.spaceSm
      app: root.app
      focusPath: root.path
      local: true
      compact: true
    }
  }
}
