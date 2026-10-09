pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Cards.js" as Cards
import "Format.js" as Format

// Every tag still worth picking, in a sheet from the right edge: the deck
// explorer's "N more tags". The filter column beside the stage shows only the
// most common few, so it never scrolls; the rest are here, with a field to
// find one by name.
//
// The list is the screen's (`counts`): the tags of the cards the filters
// left, less those already picked, each with how many cards a pick would
// leave. So a pick narrows the list as it narrows the grid, and a tag that
// would leave nothing is never offered. Picks stay open for another; what is
// picked sits on top, each with ✕ to drop it, as in the filter column.
//
// Keys, in the field: ↑/↓ choose, Enter picks and clears the field for the
// next name, Backspace in an empty field drops the last pick, Esc closes. A
// click beside the sheet closes too. `statusHints` names them, for the
// screen's status line while the panel is up, and runs the same functions
// the keys do, so a hint clicked and a key pressed cannot differ.
//
// A centred dialog (Modal.qml) was the obvious frame, and rejected: the user
// asked for a sidebar, and a sheet on the right leaves the stage and the
// grid in view beside it, so each pick shows its effect at once. For the
// same reason nothing dims them, as a modal's scrim would: the hairline on
// the sheet's edge is frame enough.
Item {
  id: root
  objectName: "tagPanel"

  property var counts: []
  property var selected: []
  property int cardCount: 0
  property bool opened: false
  signal picked(string tag)
  signal dropped(string tag)
  signal closed()

  readonly property var matches: Cards.matchTags(counts, field.text)
  property int highlight: 0

  function open() {
    field.text = ""
    root.highlight = 0
    root.opened = true
    field.forceActiveFocus()
  }
  // The keyboard back in the field, without starting over: the screen's
  // takeFocus() while the panel is up (an overlay over it closed).
  function focusField() { field.forceActiveFocus() }
  function dropLast() {
    if (root.selected.length > 0) root.dropped(root.selected[root.selected.length - 1])
    field.forceActiveFocus()
  }
  function close() {
    if (!root.opened) return
    root.opened = false
    root.closed()
  }
  function pick(i) {
    var m = root.matches[i]
    if (!m) return
    root.picked(m.tag)
  }
  function pickHighlighted() {
    if (root.matches.length === 0) return
    root.pick(root.highlight)
    field.text = ""
  }
  function move(d) {
    root.highlight = Math.max(0, Math.min(root.matches.length - 1, root.highlight + d))
    var row = rows.itemAt(root.highlight)
    if (!row) return
    if (row.y < list.contentY) list.contentY = row.y
    else if (row.y + row.height > list.contentY + list.height) list.contentY = row.y + row.height - list.height
  }

  readonly property var statusHints: [
    { keys: "↑↓", label: "choose", run: function() { root.move(1) } },
    { keys: "↵", label: "pick", run: function() { root.pickHighlighted() } },
    { keys: "⌫", label: "drop last", run: function() { root.dropLast() } },
    { keys: "esc", label: "close", run: function() { root.close() } }
  ]

  // A new list (a pick, a letter typed) starts the choice at its top.
  onMatchesChanged: { root.highlight = 0; list.contentY = 0 }

  // 0 shut, 1 open; the sheet follows it, so closing slides out as opening
  // slid in.
  property real shown: opened ? 1 : 0
  Behavior on shown { NumberAnimation { duration: Theme.sheetDuration; easing.type: Easing.OutCubic } }
  visible: shown > 0
  z: 30

  // Clear, not a scrim: a click beside the sheet closes it rather than
  // reaching the grid under it, as Esc would.
  MouseArea { anchors.fill: parent; onClicked: root.close() }

  Rectangle {
    id: sheet
    width: Math.min(Theme.sheetWidth, root.width)
    height: root.height
    x: root.width - width * root.shown
    color: Theme.paper
    MouseArea { anchors.fill: parent } // clicks inside stay inside
    // One hairline on the edge that meets the screen, as the dialogs' frame.
    Rectangle { width: Theme.hairlineWidth; height: parent.height; color: Theme.border }

    Column {
      id: head
      x: Theme.spaceXl
      y: Theme.spaceXl
      width: sheet.width - Theme.spaceXl * 2
      spacing: Theme.spaceSm

      Item {
        width: parent.width
        height: Theme.smallControlHeight
        SectionLabel { text: "Tags"; anchors.verticalCenter: parent.verticalCenter }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Theme.spaceMd
          UiText {
            text: Format.plural(root.cardCount, "card")
            font.pixelSize: Theme.captionSize; color: Theme.dim
            anchors.verticalCenter: parent.verticalCenter
          }
          PlainButton { objectName: "tagPanelClose"; label: "✕"; tip: "Close (Esc)"; onActivated: root.close() }
        }
      }

      // The picks. A chip's words start on its own left edge, so they line
      // up with the field's (layout rule 2); its outline reaches past it,
      // and nothing clips the sheet's sides, so the outline is drawn whole.
      Flow {
        visible: root.selected.length > 0
        width: parent.width
        spacing: Theme.spaceXs
        Repeater {
          model: root.selected
          delegate: Chip {
            id: pickedChip
            required property string modelData
            objectName: "tagPanelSelected:" + pickedChip.modelData
            label: "#" + pickedChip.modelData + " ✕"
            selected: true
            onActivated: root.dropped(pickedChip.modelData)
          }
        }
      }

      TextField {
        id: field
        objectName: "tagPanelField"
        width: parent.width
        leftPadding: 0
        rightPadding: 0
        placeholderText: "find a tag"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.bodySmallSize
        color: Theme.ink
        placeholderTextColor: Theme.faint
        background: Item {
          Rectangle {
            y: parent.height - height
            width: parent.width
            height: Theme.hairlineWidth
            color: field.activeFocus ? Theme.accentColor : Theme.border
          }
        }
        Keys.onPressed: function(event) {
          if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
          if (event.key === Qt.Key_Escape) root.close()
          else if (event.key === Qt.Key_Down) root.move(1)
          else if (event.key === Qt.Key_Up) root.move(-1)
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.pickHighlighted()
          else if (event.key === Qt.Key_Backspace && field.text === "" && root.selected.length > 0)
            root.dropLast()
          else return
          event.accepted = true
        }
      }
    }

    // The tags, one a row, the count on the right. Rows fill the sheet's
    // width and their words keep to the field's edge (layout rule 3); the
    // list scrolls here, in the sheet, rather than in the filter column.
    GlideFlickable {
      id: list
      objectName: "tagPanelList"
      y: head.y + head.height + Theme.spaceMd
      width: sheet.width
      height: sheet.height - y
      contentHeight: rowsCol.implicitHeight + Theme.spaceXl
      ScrollBar.vertical: ScrollBar {}

      Column {
        id: rowsCol
        width: list.width
        Repeater {
          id: rows
          // Rows only while the sheet is on screen: shut, the panel stays
          // loaded, and every filter change would rebuild a row per tag
          // for a list nobody sees.
          model: root.visible ? root.matches : []
          delegate: Rectangle {
            id: tagRow
            required property var modelData
            required property int index
            objectName: "tagRow:" + tagRow.modelData.tag
            width: rowsCol.width
            height: Theme.listRowHeight
            color: tagRow.index === root.highlight ? Theme.accentFill : (rowArea.containsMouse ? Theme.hoverFill : "transparent")
            UiText {
              x: Theme.spaceXl
              width: parent.width - x * 2 - rowCount.implicitWidth - Theme.spaceMd
              anchors.verticalCenter: parent.verticalCenter
              text: "#" + tagRow.modelData.tag
              elide: Text.ElideRight
              font.pixelSize: Theme.bodySmallSize
              color: tagRow.index === root.highlight ? Theme.accentColor : Theme.ink
            }
            UiText {
              id: rowCount
              anchors.right: parent.right
              anchors.rightMargin: Theme.spaceXl
              anchors.verticalCenter: parent.verticalCenter
              text: tagRow.modelData.count
              font.pixelSize: Theme.captionSize
              color: Theme.faint
            }
            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.pick(tagRow.index); field.forceActiveFocus() }
            }
          }
        }
      }

      UiText {
        x: Theme.spaceXl
        visible: root.matches.length === 0
        width: list.width - Theme.spaceXl * 2
        wrapMode: Text.Wrap
        text: root.counts.length === 0 ? "No other tag narrows these cards." : "No tag matches."
        font.pixelSize: Theme.bodySmallSize
        color: Theme.dim
      }
    }
  }
}
