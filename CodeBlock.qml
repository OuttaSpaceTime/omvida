import QtQuick
import Quickshell

// A fenced code block: the highlighted HTML from the wiki service in <pre>,
// on a fill, with its language and a copy button in the corner. The fill
// alone sets it off from the prose; the 1px border it also had, and the boxed
// copy button, were the chrome the chosen style takes away.
Rectangle {
  id: root

  property string html: ""
  property string code: ""
  property string lang: ""
  property bool copied: false

  height: body.implicitHeight + Theme.spaceMd * 2
  color: Theme.codeFill

  Flickable {
    anchors.fill: parent
    anchors.margins: Theme.spaceMd
    contentWidth: body.implicitWidth
    contentHeight: body.implicitHeight
    clip: true
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentWidth > width

    TextEdit {
      id: body
      readOnly: true
      selectByMouse: true
      activeFocusOnPress: false
      textFormat: TextEdit.RichText
      text: Theme.richTextStyle + "<pre>" + root.html + "</pre>"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.bodySmallSize
      color: Theme.ink
      selectionColor: Theme.selectedFill
    }
  }

  Row {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Theme.spaceXs
    spacing: Theme.spaceSm
    opacity: hover.hovered ? 1 : 0.6
    UiText {
      visible: root.lang !== ""
      text: root.lang
      font.pixelSize: Theme.captionSize
      color: Theme.faint
      anchors.verticalCenter: parent.verticalCenter
    }
    ActionButton {
      small: true
      quiet: true
      tip: "Copy"
      icon: root.copied ? "check" : "copy"
      onActivated: {
        Quickshell.clipboardText = root.code
        root.copied = true
        copiedTimer.restart()
      }
    }
  }
  HoverHandler { id: hover }
  Timer { id: copiedTimer; interval: 1300; onTriggered: root.copied = false }
}
