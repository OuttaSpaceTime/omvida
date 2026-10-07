pragma ComponentBehavior: Bound
import QtQuick

// The whole wiki as a graph, or the neighbourhood of the last page read.
Item {
  id: root

  property var app: null
  property bool local: false
  readonly property string focusPath: app ? app.wikiPath : ""

  Row {
    id: bar
    x: Theme.spaceXl
    y: Theme.spaceLg
    spacing: Theme.spaceSm
    Chip { objectName: "graphAll"; label: "All pages"; selected: !root.local; onActivated: root.local = false }
    Chip {
      objectName: "graphLocal"
      label: root.focusPath !== "" && root.app.store.pagesByPath[root.focusPath] ? "Around " + root.app.store.pagesByPath[root.focusPath].title : "Around the open page"
      enabled: root.focusPath !== ""
      selected: root.local
      onActivated: root.local = true
    }
    UiText {
      text: "click opens · drag moves · wheel zooms · rings are topic maps"
      font.pixelSize: Theme.captionSize
      color: Theme.faint
      anchors.verticalCenter: parent.verticalCenter
      leftPadding: Theme.spaceLg
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
