import QtQuick

// Text in the app's face: body size and ink unless told otherwise. Every
// label and line of prose uses it, so the font is set in one place.
Text {
  font.family: Theme.fontFamily
  font.pixelSize: Theme.bodySize
  color: Theme.ink
}
