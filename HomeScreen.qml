pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Format.js" as Format
import "StatusBits.js" as StatusBits
import "WikiTree.js" as WikiTree
import "bar/Model.js" as Overview

// Home: what to do now, then the Next.js viewer's dashboard (last studied
// pages, recently updated pages, the topics).
//
// The top is the bar overlay's "Glance", the style the user chose for it,
// so the overlay and its in-app twin read alike: the figure, the verdict and
// the deck's maturity (ProgressPanel), the next reviews up, and one filled
// action beside a square icon button. Sections are parted by a hairline and a
// small caption instead of boxes; the "now" panel used to be a filled,
// bordered card, which made the rest of the page look like an afterthought.
//
// The screen's title and its counts ("52 pages · 14 topics...") went to the
// window's status line, as did the keys the buttons used to print: the mode
// block already says where you are, and the figure is the screen's subject.
Item {
  id: root
  objectName: "homeScreen"

  property var app: null
  readonly property var index: app ? app.store.wikiIndex : null
  readonly property var overview: app ? app.store.overview : null

  // ---- the window's status line ---------------------------------------------
  readonly property string statusMode: "HOME"
  readonly property var statusSegments: root.index ? [{
    text: Format.plural(root.index.pages.length, "page") + " · "
          + Format.plural(root.index.tree.folders.length, "topic") + " · "
          + Format.plural(root.index.graph.links.length, "link")
          + (root.overview ? " · " + Format.plural(root.overview.totalCards, "card") : "")
  }] : []
  readonly property var statusHints: StatusBits.common(root.app, root.app ? [StatusBits.study(root.app)] : [])
  readonly property var statusAlerts: StatusBits.pressure(root.app, Overview.clearance(root.overview), Theme.verdictColor)

  // Pending reviews past the rows shown, counted off the due figure rather
  // than the list, which the deck server caps.
  readonly property var nextUp: root.overview ? root.overview.pending.slice(0, Theme.nextUpRows) : []
  readonly property int moreDue: root.overview ? Math.max(0, root.overview.pressure.flashcardsDue - root.nextUp.length) : 0

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
      spacing: Theme.sectionGap

      // ---- now: the Glance -------------------------------------------------------
      Column {
        width: parent.width
        spacing: Theme.spaceXl

        ProgressPanel {
          width: parent.width
          overview: root.overview
        }

        Column {
          visible: root.nextUp.length > 0
          width: parent.width
          SectionLabel { divided: true; text: "Next up" }
          Repeater {
            model: root.nextUp
            delegate: ListRow {
              id: pendingRow
              required property var modelData
              width: col.width
              dot: Theme.topicColor(pendingRow.modelData.deck.toLowerCase())
              title: pendingRow.modelData.text
              note: pendingRow.modelData.deck + (pendingRow.modelData.lapses > 0 ? " · " + Format.plural(pendingRow.modelData.lapses, "lapse") : "")
              onActivated: root.app.startStudy()
            }
          }
          UiText {
            visible: root.moreDue > 0
            topPadding: Theme.spaceXs
            text: "+ " + root.moreDue + " more"
            font.pixelSize: Theme.captionSize
            color: Theme.faint
          }
        }

        // One filled action, the way forward, and the deck beside it as a
        // square icon (the overlay's footer).
        Column {
          width: parent.width
          spacing: Theme.spaceLg
          Rectangle { width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }
          Row {
            spacing: Theme.spaceSm
            ActionButton {
              objectName: "homeStudyButton"
              filled: true
              prominent: true
              label: root.overview && root.overview.pressure.flashcardsDue > 0 ? "Study now" : "Study"
              onActivated: root.app.startStudy()
            }
            ActionButton {
              objectName: "homeCardsButton"
              prominent: true
              icon: "cards"
              tip: "Browse the deck"
              onActivated: root.app.setScreen("cards")
            }
            ActionButton {
              objectName: "homeWikiButton"
              prominent: true
              icon: "wiki"
              tip: "Read the wiki"
              onActivated: root.app.setScreen("wiki")
            }
          }
        }
      }

      // ---- last studied -----------------------------------------------------
      Column {
        width: parent.width
        SectionLabel { divided: true; text: "Last studied" }
        UiText {
          visible: root.app && root.app.store.recentPages.length === 0
          topPadding: Theme.spaceXs
          text: "No recent reviews touch a wiki page yet."
          font.pixelSize: Theme.bodySmallSize
          color: Theme.faint
        }
        Repeater {
          model: root.app ? root.app.store.recentPages : []
          delegate: ListRow {
            id: recentRow
            required property var modelData
            objectName: "recent:" + recentRow.modelData.path
            width: col.width
            title: recentRow.modelData.title
            topic: recentRow.modelData.folder
            badge: Format.plural(recentRow.modelData.cards, "card")
            note: Format.ago(recentRow.modelData.lastStudied)
            onActivated: root.app.openPage(recentRow.modelData.path, "")
          }
        }
      }

      // ---- recently updated -------------------------------------------------
      Column {
        width: parent.width
        SectionLabel { divided: true; text: "Recently updated" }
        Repeater {
          model: root.index ? root.index.pages.slice().sort(function(a, b) {
            return b.updated < a.updated ? -1 : b.updated > a.updated ? 1 : 0
          }).slice(0, 8) : []
          delegate: ListRow {
            id: updatedRow
            required property var modelData
            width: col.width
            title: updatedRow.modelData.title
            topic: updatedRow.modelData.folder
            note: updatedRow.modelData.updated
            onActivated: root.app.openPage(updatedRow.modelData.path, "")
          }
        }
      }

      // ---- topics -------------------------------------------------------------
      Column {
        width: parent.width
        spacing: Theme.spaceSm
        SectionLabel { divided: true; text: "Topics" }
        // Every tile as tall as a full one (its name and three pages), so the
        // grid reads as rows of equal cards, not a ragged wall. Measured off
        // this unseen copy of a full tile rather than taken as the tallest
        // tile shown: that would leave every tile short whenever no topic
        // happened to have three pages, and follows the theme's font sizes
        // without a typed height. Positioners skip an invisible item, so it
        // takes no room in the column.
        Column {
          id: fullTile
          visible: false
          spacing: Theme.spaceXs
          UiText { text: "Topic" }
          Repeater {
            model: 3
            delegate: UiText { text: "Page"; font.pixelSize: Theme.captionSize }
          }
        }
        // A tile is a hairline over its words, not a filled box: a wall of
        // fourteen bordered boxes was the loudest thing on the page. The rule
        // in the topic's colour keeps the grid readable as tiles.
        Grid {
          id: grid
          width: parent.width
          columns: Math.max(1, Math.floor((width + Theme.spaceMd) / (Theme.cardGridCellWidth * 0.75)))
          columnSpacing: Theme.spaceXl
          rowSpacing: Theme.spaceSm
          readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns
          Repeater {
            model: root.index ? root.index.tree.folders : []
            delegate: Rectangle {
              id: topicTile
              required property var modelData
              objectName: "topic:" + topicTile.modelData.path
              width: grid.cellWidth
              height: fullTile.implicitHeight + Theme.spaceMd * 2
              color: tArea.containsMouse ? Theme.hoverFill : "transparent"
              // First child: tst_wiki measures the tile's padding off it.
              Column {
                id: tcol
                y: Theme.spaceMd
                width: parent.width
                spacing: Theme.spaceXs
                Row {
                  width: parent.width
                  spacing: Theme.spaceSm
                  UiText { text: topicTile.modelData.name; color: Theme.topicColor(topicTile.modelData.path) }
                  UiText { text: topicTile.modelData.count; font.pixelSize: Theme.captionSize; color: Theme.faint; anchors.verticalCenter: parent.verticalCenter }
                }
                Repeater {
                  model: WikiTree.collectPages(topicTile.modelData).sort(function(a, b) { return a.title < b.title ? -1 : 1 }).slice(0, 3)
                  delegate: UiText {
                    id: topicPage
                    required property var modelData
                    width: tcol.width
                    text: topicPage.modelData.title
                    elide: Text.ElideRight
                    font.pixelSize: Theme.captionSize
                    color: Theme.dim
                  }
                }
              }
              Rectangle {
                width: parent.width
                height: Theme.hairlineWidth
                color: Theme.alpha(Theme.topicColor(topicTile.modelData.path), 0.5)
              }
              MouseArea {
                id: tArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.app.openFolder(topicTile.modelData.path)
              }
            }
          }
        }
      }
    }
  }
}
