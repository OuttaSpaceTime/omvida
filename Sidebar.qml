pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// The icon rail, as Omvision's: the mark, then one icon per screen, labels in
// tooltips. Study carries the number of reviews due, the one figure worth
// seeing from every screen.
Rectangle {
  id: root

  property string currentScreen: "home"
  property int dueCount: 0
  signal navigate(string screen)

  readonly property var navItems: [
    { id: "home", label: "Home  Ctrl+1", icon: "home" },
    { id: "study", label: "Study  Ctrl+2", icon: "study" },
    { id: "wiki", label: "Wiki  Ctrl+3", icon: "wiki" },
    { id: "cards", label: "Cards  Ctrl+4", icon: "cards" },
    { id: "graph", label: "Graph  Ctrl+5", icon: "graph" }
  ]

  width: Theme.railWidth
  color: Theme.paper

  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Theme.hairlineWidth
    color: Theme.hairline
  }

  // Black on transparent (assets/omvida.svg), tinted to the accent, the way
  // Omvision tints its mark.
  Item {
    id: mark
    width: Theme.railMarkSize
    height: Theme.railMarkSize
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Theme.spaceMd + Theme.spaceXs

    Image {
      id: markSvg
      anchors.fill: parent
      source: Qt.resolvedUrl("assets/omvida.svg")
      sourceSize.width: mark.width
      sourceSize.height: mark.height
      smooth: true
      visible: false
    }
    MultiEffect {
      anchors.fill: parent
      source: markSvg
      colorization: 1.0
      colorizationColor: Theme.accentColor
      brightness: 1.0
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.navigate("home")
    }
  }

  Column {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: mark.bottom
    anchors.topMargin: Theme.spaceXl
    spacing: Theme.spaceXxs

    Repeater {
      model: root.navItems
      delegate: Item {
        id: navRow
        required property var modelData
        objectName: "nav:" + navRow.modelData.id
        width: parent.width
        height: Theme.railRowHeight
        readonly property bool selected: root.currentScreen === navRow.modelData.id

        Rectangle {
          visible: navRow.selected
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Theme.railBarWidth
          color: Theme.accentColor
        }
        Rectangle {
          visible: navArea.containsMouse
          anchors.fill: parent
          color: Theme.hoverFill
        }
        Glyph {
          anchors.centerIn: parent
          icon: navRow.modelData.icon
          font.pixelSize: Theme.railIconSize
          color: navRow.selected ? Theme.accentColor : Theme.dim
        }
        // The due badge: reviews only, never the new-card pool (pressure's rule).
        Rectangle {
          visible: navRow.modelData.id === "study" && root.dueCount > 0
          anchors.right: parent.right
          anchors.rightMargin: Theme.spaceSm
          anchors.top: parent.top
          anchors.topMargin: Theme.spaceXs
          height: badgeText.implicitHeight
          width: Math.max(height, badgeText.implicitWidth + Theme.spaceSm)
          radius: height / 2
          color: Theme.accentColor
          UiText {
            id: badgeText
            anchors.centerIn: parent
            text: root.dueCount > 99 ? "99+" : root.dueCount
            font.pixelSize: Theme.captionSize
            color: Theme.paper
          }
        }
        MouseArea {
          id: navArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.navigate(navRow.modelData.id)
        }
        ToolTip.visible: navArea.containsMouse
        ToolTip.delay: Theme.tooltipDelay
        ToolTip.text: navRow.modelData.label
      }
    }
  }
}
