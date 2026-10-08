import QtQuick
import QtQuick.Controls

// The app's control: controlHeight tall, a 1px border, square, quiet
// (Omvision's layout rule 9). `filled` is for the one primary action on a
// screen. Keys are not printed on buttons: they live in the window's status
// line, so a button says only what it does.
//
// A quiet text button, with no border, is PlainButton. `prominent` is the
// Glance footer's size, for the filled action and the square icon buttons
// beside it. A button with an icon and no label is square, and says what it
// does in `tip`, a tooltip. `fill` colours a filled button: the accent, or
// Theme.redText for an action that destroys something (ConfirmDialog).
Rectangle {
  id: root

  property string label: ""
  property string icon: ""
  property string tip: ""
  property bool filled: false
  property color fill: Theme.accentColor
  property bool small: false
  property bool prominent: false
  property color tint: Theme.ink
  signal activated()

  readonly property bool hovered: area.containsMouse
  readonly property bool iconOnly: label === "" && icon !== ""
  readonly property int inset: small ? Theme.spaceSm : (prominent ? Theme.spaceXl : Theme.spaceMd)
  activeFocusOnTab: false

  implicitHeight: small ? Theme.smallControlHeight : (prominent ? Theme.primaryControlHeight : Theme.controlHeight)
  implicitWidth: iconOnly ? implicitHeight : row.implicitWidth + inset * 2
  color: filled ? (hovered ? Qt.darker(fill, 1.1) : fill)
                : (hovered && enabled ? Theme.hoverFill : "transparent")
  border.color: filled ? fill : Theme.border
  border.width: Theme.borderWidth
  radius: Theme.radius
  opacity: enabled ? 1 : 0.45

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Theme.spaceSm

    Glyph {
      visible: root.icon !== ""
      icon: root.icon
      anchors.verticalCenter: parent.verticalCenter
      font.pixelSize: root.small ? Theme.bodySmallSize : Theme.bodySize
      color: root.filled ? Theme.paper : root.tint
    }
    UiText {
      visible: root.label !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      font.pixelSize: root.small ? Theme.bodySmallSize : Theme.bodySize
      font.weight: root.filled && root.prominent ? Font.Medium : Font.Normal
      color: root.filled ? Theme.paper : root.tint
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }

  ToolTip.visible: root.tip !== "" && area.containsMouse
  ToolTip.delay: Theme.tooltipDelay
  ToolTip.text: root.tip
}
