import QtQuick

// A one-line mention of something that opens: a coloured glyph (`icon`),
// then the text, elided to the row. Its hover fill bleeds into the margin,
// as a ListRow's does. The Cards stage's note uses it; a PlainButton sizes
// to its words and would run past the column, and a ListRow has no glyph.
Item {
  id: root

  property string icon: ""
  property color iconColor: Theme.accentColor
  property string text: ""
  property color color: Theme.secondaryInk
  signal activated()

  height: Theme.smallControlHeight

  Rectangle {
    x: -Theme.hoverBleed
    width: parent.width + Theme.hoverBleed * 2
    height: parent.height
    color: area.containsMouse ? Theme.hoverFill : "transparent"
  }
  Glyph {
    id: glyph
    icon: root.icon
    anchors.verticalCenter: parent.verticalCenter
    font.pixelSize: Theme.bodySmallSize
    color: root.iconColor
  }
  UiText {
    x: glyph.implicitWidth + Theme.spaceSm
    width: parent.width - x
    anchors.verticalCenter: parent.verticalCenter
    text: root.text
    textFormat: Text.PlainText
    elide: Text.ElideRight
    font.pixelSize: Theme.bodySmallSize
    color: root.color
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
