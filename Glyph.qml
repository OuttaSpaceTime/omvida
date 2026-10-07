import QtQuick
import "Icons.js" as Icons

// One icon from Icons.js, sized like text.
UiText {
  property string icon: ""
  text: Icons.g(icon)
  font.pixelSize: Theme.subtitleSize
  color: Theme.dim
  verticalAlignment: Text.AlignVCenter
  horizontalAlignment: Text.AlignHCenter
}
