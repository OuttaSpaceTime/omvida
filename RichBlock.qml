import QtQuick

// One block of page HTML (a paragraph, list, table or quote), selectable.
// A clicked link (wiki:, anchor:, http) is TextEdit's own linkActivated, for
// whoever shows the page to follow (Navigator.followLink): a block knows
// nothing of the app. Read-only TextEdit rather than Text, so a passage can
// be selected and copied.
TextEdit {
  id: root

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

  HoverHandler {
    cursorShape: root.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
  }
}
