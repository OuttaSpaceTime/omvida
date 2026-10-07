import QtQuick

// A card's front or back. Card text is the simple HTML authored for Anki
// (<br>, <code>, <pre>, <b>, lists), which Qt's rich text draws directly; the
// theme's stylesheet colours code and links.
UiText {
  property string html: ""
  property int size: Theme.bodySize
  textFormat: Text.RichText
  text: Theme.richTextStyle + html
  wrapMode: Text.Wrap
  font.pixelSize: size
  lineHeight: Theme.proseLineHeight
  onLinkActivated: function(link) { Qt.openUrlExternally(link) }
}
