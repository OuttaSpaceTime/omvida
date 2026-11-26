pragma ComponentBehavior: Bound
import QtQuick

import "Format.js" as Format

// The whole wiki as a graph, or the neighbourhood of the last page read.
Item {
  id: root
  objectName: "graphScreen"

  required property App app
  // All pages, or around the open page: the navigator's, so "graph around
  // this page" from the wiki lands here so set (Navigator.openGraph).
  readonly property bool local: app.nav.graphLocal
  readonly property string focusPath: app.nav.wikiPath

  // ---- the window's status line ---------------------------------------------
  // The counts of what is drawn, and how to handle it: how to use what is on
  // screen is the status line's job, and the top of the canvas is left to the
  // chips and the legend.
  readonly property var statusSegments: {
    var g = view.shown
    var out = []
    if (g) out.push({ text: Format.plural(g.nodes.length, "page") + " · " + Format.plural(g.links.length, "link") })
    out.push({ text: "hover or a topic names pages · click opens · drag moves · wheel zooms" + (view.local ? " · dashed: shares a tag" : ""), color: Theme.faint })
    return out
  }

  Row {
    id: bar
    x: Theme.spaceXl
    y: Theme.spaceLg
    spacing: Theme.spaceXs
    Chip { objectName: "graphAll"; label: "All pages"; selected: !root.local; onActivated: root.app.nav.graphLocal = false }
    Chip {
      objectName: "graphLocal"
      label: root.focusPath !== "" && root.app.store.pagesByPath[root.focusPath] ? "Around " + root.app.store.pagesByPath[root.focusPath].title : "Around the open page"
      enabled: root.focusPath !== ""
      selected: root.local
      onActivated: root.app.nav.graphLocal = true
    }
  }

  // ---- the topic legend ------------------------------------------------------
  // Always shown, the column of topics printed over the graph's right side on
  // any window short of full width, over dots and titles alike. So it docks
  // beside the graph only while the graph keeps Theme.graphMinWidth without
  // it (the graph is then fitted to what is left, and nothing overlaps);
  // otherwise it folds to the Topics chip, which opens it over the graph on a
  // solid panel. A click on the chip overrides that choice until the window
  // crosses the line again. Each topic is a switch: on, its pages are titled.
  readonly property var folders: app.store.wikiIndex ? app.store.wikiIndex.tree.folders : []
  readonly property bool roomy: width - legend.implicitWidth - Theme.spaceXl * 3 >= Theme.graphMinWidth
  property var legendChoice: null
  // The topics switched on (top folder -> true): GraphView titles their pages.
  property var activeTopics: ({})
  onRoomyChanged: legendChoice = null
  readonly property bool legendOpen: legendChoice !== null ? legendChoice : roomy
  readonly property bool legendDocked: legendOpen && roomy

  Chip {
    id: topicsChip
    objectName: "graphTopics"
    anchors.right: parent.right
    anchors.rightMargin: Theme.spaceXl
    y: Theme.spaceLg
    label: "Topics"
    count: root.folders.length
    selected: root.legendOpen
    onActivated: root.legendChoice = !root.legendOpen
  }

  Rectangle {
    id: legendPanel
    objectName: "graphLegend"
    visible: root.legendOpen
    z: 1
    // Docked it is part of the screen and needs no panel; floating over the
    // graph it is opaque and outlined, so no dot or line shows through it.
    color: root.legendDocked ? "transparent" : Theme.paper
    border.color: root.legendDocked ? "transparent" : Theme.hairline
    border.width: Theme.hairlineWidth
    anchors.right: parent.right
    anchors.rightMargin: Theme.spaceXl - Theme.spaceSm
    y: topicsChip.y + topicsChip.height + Theme.spaceXs
    width: legend.implicitWidth + Theme.spaceSm * 2
    height: legend.implicitHeight + Theme.spaceSm * 2
    // Clicks on the floating panel stop here, not on a dot beneath it.
    MouseArea { anchors.fill: parent }
    Column {
      id: legend
      x: Theme.spaceSm
      y: Theme.spaceSm
      spacing: 0
      Repeater {
        model: root.folders
        delegate: Chip {
          id: topicRow
          required property var modelData
          objectName: "graphTopic:" + topicRow.modelData.path
          label: topicRow.modelData.name
          dot: Theme.topicColor(topicRow.modelData.path)
          selected: root.activeTopics[topicRow.modelData.path] === true
          onActivated: {
            var next = Object.assign({}, root.activeTopics), key = topicRow.modelData.path
            if (next[key]) delete next[key]
            else next[key] = true
            root.activeTopics = next
          }
        }
      }
    }
  }

  GraphView {
    id: view
    objectName: "graphView"
    anchors.top: bar.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    // Docked, the legend's column is the graph's to keep clear of.
    anchors.rightMargin: root.legendDocked ? legendPanel.width + Theme.spaceXl : 0
    anchors.bottom: parent.bottom
    graph: root.app.store.graph
    focusPath: root.focusPath
    onPageChosen: function(path) { root.app.nav.openPage(path) }
    local: root.local && root.focusPath !== ""
    activeTopics: root.activeTopics
  }
}
