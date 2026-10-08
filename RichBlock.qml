import QtQuick

// One block of page HTML (a paragraph, list, table or quote), selectable, its
// links routed through the app (wiki:, anchor:, http). Read-only
// TextEdit rather than Text, so a passage can be selected and copied.
TextEdit {
  id: root

  property var app: null
  property string html: ""
  property int size: Theme.bodySize

  readOnly: true
  selectByMouse: true
  textFormat: TextEdit.RichText
  text: Theme.richTextStyle + html
  wrapMode: TextEdit.Wrap
  font.family: Theme.fontFamily
  font.pixelSize: size
  color: Theme.ink
  selectionColor: Theme.selectedFill
  selectedTextColor: Theme.ink
  activeFocusOnPress: false
  onLinkActivated: function(link) { if (root.app) root.app.followLink(link) }

  HoverHandler {
    cursorShape: root.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
  }
}
