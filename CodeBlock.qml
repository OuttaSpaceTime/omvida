import QtQuick
import Quickshell

// A fenced code block: the highlighted HTML from the wiki service in <pre>,
// on a fill, with its language and a copy button in the corner.
Rectangle {
  id: root

  property string html: ""
  property string code: ""
  property string lang: ""
  property bool copied: false

  height: body.implicitHeight + Theme.spaceMd * 2
  color: Theme.codeFill
  border.color: Theme.hairline
  border.width: Theme.borderWidth

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
