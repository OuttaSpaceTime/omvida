import QtQuick

// A one-line mention of a card that may open: a coloured lead, either a
// glyph (`icon`) or a short word in a column `leadWidth` wide (`lead`), so
// the texts of a list start on one edge, then the text, elided to the row.
// Its hover fill bleeds into the margin, as a ListRow's does. The Cards
// stage's note and Home's past sessions use it; a PlainButton sizes to its
// words and would run past the column, and a ListRow has no lead.
// `clickable` false makes it plain (a lapse has nothing to open).
Item {
  id: root

  property string icon: ""
  property string lead: ""
  property real leadWidth: 0
  property color leadColor: Theme.accentColor
  property string text: ""
  property color color: Theme.secondaryInk
  property bool clickable: true
  signal activated()

  height: Theme.smallControlHeight

  Rectangle {
    x: -Theme.hoverBleed
    width: parent.width + Theme.hoverBleed * 2
    height: parent.height
    color: area.containsMouse && root.clickable ? Theme.hoverFill : "transparent"
  }
  Glyph {
    id: glyph
    visible: root.icon !== ""
    icon: root.icon
    anchors.verticalCenter: parent.verticalCenter
    font.pixelSize: Theme.bodySmallSize
    color: root.leadColor
  }
  UiText {
    visible: root.lead !== ""
    width: root.leadWidth
    anchors.verticalCenter: parent.verticalCenter
    text: root.lead
    font.pixelSize: Theme.captionSize
    color: root.leadColor
  }
  UiText {
    x: root.icon !== "" ? glyph.implicitWidth + Theme.spaceSm : root.leadWidth
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
    enabled: root.clickable
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
