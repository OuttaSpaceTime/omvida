pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Format.js" as Format
import "WikiTree.js" as WikiTree

// Home: what to do now (the study panel and what is pending), then the
// Next.js viewer's dashboard: last studied pages, the deck, recently updated
// pages and the topics.
Item {
  id: root

  property var app: null
  readonly property var index: app ? app.store.wikiIndex : null
  readonly property var overview: app ? app.store.overview : null


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

      Column {
        spacing: Theme.spaceXs
        UiText {
          text: "Study"
          font.pixelSize: Theme.displaySize
          font.bold: true
        }
        UiText {
          text: root.index ? Format.plural(root.index.pages.length, "page") + " · "
                             + Format.plural(root.index.tree.folders.length, "topic") + " · "
                             + Format.plural(root.index.graph.links.length, "link")
                             + (root.overview ? " · " + Format.plural(root.overview.totalCards, "card") : "")
                           : "Loading…"
          font.pixelSize: Theme.bodySmallSize
          color: Theme.dim
        }
      }

      // ---- now -------------------------------------------------------------
      Rectangle {
        width: parent.width
        height: nowCol.implicitHeight + Theme.spaceXl * 2
        color: Theme.fill
        border.color: Theme.hairline
        border.width: Theme.borderWidth

        Column {
          id: nowCol
          x: Theme.spaceXl
          y: Theme.spaceXl
          width: parent.width - Theme.spaceXl * 2
          spacing: Theme.spaceLg

          ProgressPanel {
            width: parent.width
            overview: root.overview
          }
          Row {
            spacing: Theme.spaceMd
            ActionButton {
              objectName: "homeStudyButton"
              filled: true
              icon: "study"
              label: root.overview && root.overview.pressure.flashcardsDue > 0 ? "Study now" : "Study"
              hint: "Ctrl+2"
              onActivated: root.app.startStudy()
            }
            ActionButton {
              icon: "cards"
              label: "Browse the deck"
              onActivated: root.app.setScreen("cards")
            }
          }
        }
      }

      // ---- pending ----------------------------------------------------------
      Column {
        visible: root.overview && root.overview.pending.length > 0
        width: parent.width
        spacing: Theme.spaceSm
        SectionLabel { text: "Pending reviews" }
        Repeater {
          model: root.overview ? root.overview.pending : []
          delegate: ListRow {
            id: pendingRow
            required property var modelData
            width: col.width
            title: pendingRow.modelData.text
            note: pendingRow.modelData.deck + (pendingRow.modelData.lapses > 0 ? " · " + Format.plural(pendingRow.modelData.lapses, "lapse") : "")
            onActivated: root.app.startStudy()
          }
        }
      }

      // ---- last studied -----------------------------------------------------
      Column {
        width: parent.width
        spacing: Theme.spaceSm
        SectionLabel { text: "Last studied" }
        UiText {
          visible: root.app && root.app.store.recentPages.length === 0
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
        spacing: Theme.spaceSm
        SectionLabel { text: "Recently updated" }
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
        SectionLabel { text: "Topics" }
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
        Grid {
          id: grid
          width: parent.width
          columns: Math.max(1, Math.floor((width + Theme.spaceMd) / (Theme.cardGridCellWidth * 0.75)))
          spacing: Theme.spaceMd
          readonly property real cellWidth: (width - spacing * (columns - 1)) / columns
          Repeater {
            model: root.index ? root.index.tree.folders : []
            delegate: Rectangle {
              id: topicTile
              required property var modelData
              objectName: "topic:" + topicTile.modelData.path
              width: grid.cellWidth
              height: fullTile.implicitHeight + Theme.spaceMd * 2
              color: tArea.containsMouse ? Theme.hoverFill : Theme.fill
              border.color: Theme.hairline
              border.width: Theme.borderWidth
              Column {
                id: tcol
                x: Theme.spaceMd
                y: Theme.spaceMd
                width: parent.width - Theme.spaceMd * 2
                spacing: Theme.spaceXs
                Row {
                  width: parent.width
                  spacing: Theme.spaceSm
                  Rectangle { width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2; color: Theme.topicColor(topicTile.modelData.path); anchors.verticalCenter: parent.verticalCenter }
                  UiText { text: topicTile.modelData.name }
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
