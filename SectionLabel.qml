import QtQuick

// A block's small caps label ("LAST STUDIED"), the viewer's SectionLabel.
UiText {
  font.pixelSize: Theme.captionSize
  font.capitalization: Font.AllUppercase
  font.letterSpacing: Theme.labelTracking
  color: Theme.faint
}
