pragma ComponentBehavior: Bound
import QtQuick

// The keys that work right now, as a modal list: Study's one status-line
// hint ("alt+? keys") opens it, so the line stays quiet while a card is up.
// Each row is the key in bold and what it does, and a click on it does the
// same, so a mouse loses nothing. It holds the keyboard while open: Esc (or
// Alt+? again) closes it and never reaches the screen under it.
Modal {
  id: root

  property var keys: []   // [{ keys, label, run? }], as the status line takes them

  title: "Keys"
  cardWidth: Theme.sidePanelWidth * 2

  function open() {
    root.opened = true
    holder.forceActiveFocus()
  }

  Item {
    id: holder
    width: parent.width
    height: 0
    Keys.onEscapePressed: root.close()
    Keys.onPressed: function(event) {
      if ((event.modifiers & Qt.AltModifier) && (event.key === Qt.Key_Question || event.key === Qt.Key_Slash)) {
        root.close()
        event.accepted = true
      }
    }
  }

  Repeater {
    model: root.keys
    delegate: PlainButton {
      id: row
      required property var modelData
      objectName: "keyHelp:" + row.modelData.label
      x: -row.inset
      keys: row.modelData.keys
      label: row.modelData.label
      interactive: typeof row.modelData.run === "function"
      onActivated: {
        root.close()
        row.modelData.run()
      }
    }
  }
}
