pragma ComponentBehavior: Bound
import QtQuick

import "Format.js" as Format
import "StatusBits.js" as StatusBits
import "bar/Model.js" as Overview

// The whole wiki as a graph, or the neighbourhood of the last page read.
Item {
  id: root
  objectName: "graphScreen"

  property var app: null
  property bool local: false
  readonly property string focusPath: app ? app.wikiPath : ""

  // ---- the window's status line ---------------------------------------------
  // The counts of what is drawn, and how to handle it. The mouse help used to
  // be a line of faint text beside the chips; it is the status line's kind of
  // thing (how to use what is on screen), and the top of the canvas is left to
  // the chips and the legend.
  readonly property string statusMode: "GRAPH"
  readonly property var statusSegments: {
    var g = view.shown
    var out = []
    if (g) out.push({ text: Format.plural(g.nodes.length, "page") + " · " + Format.plural(g.links.length, "link") })
    out.push({ text: "click opens · drag moves · wheel zooms · rings are topic maps", color: Theme.faint })
    return out
  }
  readonly property var statusHints: StatusBits.common(root.app, [])
  readonly property var statusAlerts: StatusBits.pressure(root.app, root.app ? Overview.clearance(root.app.store.overview) : "", Theme.verdictColor)

  // Pulled left by a chip's inset, so the first chip's words start on the
  // screen's edge rather than its (now invisible) box.
  Row {
    id: bar
    x: Theme.spaceXl - Theme.spaceSm
    y: Theme.spaceLg
    spacing: Theme.spaceXs
    Chip { objectName: "graphAll"; label: "All pages"; selected: !root.local; onActivated: root.local = false }
    Chip {
      objectName: "graphLocal"
      label: root.focusPath !== "" && root.app.store.pagesByPath[root.focusPath] ? "Around " + root.app.store.pagesByPath[root.focusPath].title : "Around the open page"
      enabled: root.focusPath !== ""
      selected: root.local
      onActivated: root.local = true
    }
  }

  // Topic legend.
  Column {
    anchors.right: parent.right
    anchors.rightMargin: Theme.spaceXl
    y: Theme.spaceLg
    spacing: Theme.spaceXs
    z: 1
    Repeater {
      model: root.app && root.app.store.wikiIndex ? root.app.store.wikiIndex.tree.folders : []
      delegate: Row {
        id: legendRow
        required property var modelData
        spacing: Theme.spaceSm
        Rectangle { width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2; color: Theme.topicColor(legendRow.modelData.path); anchors.verticalCenter: parent.verticalCenter }
        UiText { text: legendRow.modelData.name; font.pixelSize: Theme.captionSize; color: Theme.dim }
      }
    }
  }

  GraphView {
    id: view
    objectName: "graphView"
    anchors.top: bar.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    app: root.app
    focusPath: root.focusPath
    local: root.local && root.focusPath !== ""
  }
}
