import QtQuick
import QtQuick.Controls

// The app's control: controlHeight tall, a 1px border, square, quiet
// (Omvision's layout rule 9). `filled` is for the one primary action on a
// screen. `hint` shows the key that does the same thing, dimmed after the
// label; the screens outside Study now leave it empty and put their keys in
// the window's status line instead, so a button says only what it does.
//
// `quiet` drops the border: a text button for secondary actions that sit in a
// line of prose-like controls (a page's "2 cards · Go deeper"), where a row of
// boxes read as a toolbar louder than the page under it. `prominent` is the
// Glance footer's size, for the filled action and the square icon buttons
// beside it. A button with an icon and no label is square, and says what it
// does in `tip`, a tooltip.
Rectangle {
  id: root

  property string label: ""
  property string icon: ""
  property string hint: ""
  property string tip: ""
  property bool filled: false
  property bool small: false
  property bool quiet: false
  property bool prominent: false
  property color tint: quiet ? Theme.secondaryInk : Theme.ink
  signal activated()

  readonly property bool hovered: area.containsMouse
  readonly property bool iconOnly: label === "" && icon !== ""
  // The text's inset from the button's edge, so a caller can pull a quiet
  // button left until its label sits on the page's text edge (rule 2).
  readonly property int inset: small ? Theme.spaceSm : (prominent ? Theme.spaceXl : Theme.spaceMd)
  activeFocusOnTab: false

  implicitHeight: small ? Theme.smallControlHeight : (prominent ? Theme.primaryControlHeight : Theme.controlHeight)
  implicitWidth: iconOnly ? implicitHeight : row.implicitWidth + inset * 2
  color: filled ? (hovered ? Qt.darker(Theme.accentColor, 1.1) : Theme.accentColor)
                : (hovered && enabled ? Theme.hoverFill : "transparent")
  border.color: filled ? Theme.accentColor : (quiet ? "transparent" : Theme.border)
  border.width: quiet && !filled ? 0 : Theme.borderWidth
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
    UiText {
      visible: root.hint !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.hint
      font.pixelSize: Theme.captionSize
      color: root.filled ? Theme.alpha(Theme.paper, 0.75) : Theme.faint
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
