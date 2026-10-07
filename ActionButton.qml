import QtQuick

// The app's control: controlHeight tall, a 1px border, square, quiet
// (Omvision's layout rule 9). `filled` is for the one primary action on a
// screen. `hint` shows the key that does the same thing, dimmed after the
// label, so the shortcuts are learnt from the buttons.
Rectangle {
  id: root

  property string label: ""
  property string icon: ""
  property string hint: ""
  property bool filled: false
  property bool small: false
  property color tint: Theme.ink
  signal activated()

  readonly property bool hovered: area.containsMouse
  activeFocusOnTab: false

  implicitHeight: small ? Theme.smallControlHeight : Theme.controlHeight
  implicitWidth: row.implicitWidth + (small ? Theme.spaceLg : Theme.spaceXl)
  color: filled ? (hovered ? Qt.darker(Theme.accentColor, 1.1) : Theme.accentColor)
                : (hovered && enabled ? Theme.hoverFill : "transparent")
  border.color: filled ? Theme.accentColor : Theme.border
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
}
