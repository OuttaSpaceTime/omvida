import QtQuick

// A one-line note at the bottom of the window that goes away on its own:
// "Opened Claude Code", "Anki sync: pulled 6 reviews".
Rectangle {
  id: root

  property string text: ""
  function show(t) { root.text = t; hideTimer.restart() }

  visible: opacity > 0
  opacity: hideTimer.running ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
  z: 20
  width: label.implicitWidth + Theme.spaceXl * 2
  height: Theme.controlHeight + Theme.spaceSm
  color: Theme.ink

  UiText {
    id: label
    anchors.centerIn: parent
    text: root.text
    font.pixelSize: Theme.bodySmallSize
    color: Theme.paper
  }

  Timer { id: hideTimer; interval: Theme.toastDuration }
}
