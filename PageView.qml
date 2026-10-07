pragma ComponentBehavior: Bound
import QtQuick

// A wiki page as the wiki service's blocks (render.py says why blocks), laid
// out down one column. Headings are items, so a section link scrolls to one.
Column {
  id: root

  property var app: null
  property var blocks: []
  spacing: Theme.spaceMd

  // The y of the heading with this anchor, or -1.
  function anchorY(anchor) {
    for (var i = 0; i < rep.count; i++) {
      var it = rep.itemAt(i)
      if (it && it.anchorName === anchor) return it.y
    }
    return -1
  }

  Repeater {
    id: rep
    model: root.blocks
    delegate: Item {
      id: blockItem
      required property var modelData
      required property int index
      readonly property string anchorName: blockItem.modelData.kind === "heading" ? blockItem.modelData.anchor : ""
      // A heading after other blocks gets room above it.
      readonly property int gap: blockItem.modelData.kind === "heading" && blockItem.index > 0 ? Theme.spaceLg : 0
      width: root.width
      height: loader.height + gap

      // Width only: a Loader given a height resizes its item to it, and the
      // item's own height is what the block is.
      Loader {
        id: loader
        y: blockItem.gap
        width: parent.width
        sourceComponent: {
          switch (blockItem.modelData.kind) {
          case "heading": return heading
          case "code": return code
          case "callout": return callout
          case "quote": return quote
          case "hr": return rule
          default: return rich
          }
        }
        onLoaded: item.block = Qt.binding(function() { return blockItem.modelData })
      }
    }
  }

  // Each block's component takes the block as `block`, set by the Loader.
  Component {
    id: heading
    RichBlock {
      id: h
      property var block: ({})
      app: root.app
      objectName: "heading:" + (h.block.anchor || "")
      width: root.width
      html: h.block.html || ""
      size: h.block.level <= 2 ? Theme.headingSize - Theme.spaceXs : (h.block.level === 3 ? Theme.titleSize + Theme.spaceXxs : Theme.subtitleSize)
      font.bold: true
    }
  }
  Component {
    id: rich
    RichBlock {
      id: r
      property var block: ({})
      app: root.app
      width: root.width
      html: r.block.html || ""
    }
  }
  Component {
    id: code
    CodeBlock {
      id: c
      property var block: ({})
      width: root.width
      html: c.block.html || ""
      code: c.block.text || ""
      lang: c.block.lang || ""
    }
  }
  Component {
    id: callout
    Rectangle {
      id: co
      property var block: ({})
      width: root.width
      height: cc.implicitHeight + Theme.spaceMd * 2
      color: Theme.accentFill
      Rectangle { width: Theme.selectionBarWidth; height: parent.height; color: Theme.accentColor }
      Column {
        id: cc
        x: Theme.spaceLg
        y: Theme.spaceMd
        width: parent.width - Theme.spaceLg * 2
        spacing: Theme.spaceXs
        SectionLabel { text: co.block.label || ""; color: Theme.accentColor }
        RichBlock { app: root.app; width: parent.width; html: co.block.html || "" }
      }
    }
  }
  Component {
    id: quote
    Item {
      id: q
      property var block: ({})
      width: root.width
      height: qb.implicitHeight
      Rectangle { width: Theme.selectionBarWidth; height: parent.height; color: Theme.hairline }
      RichBlock { id: qb; x: Theme.spaceLg; width: parent.width - Theme.spaceLg; app: root.app; html: q.block.html || ""; color: Theme.secondaryInk }
    }
  }
  Component {
    id: rule
    Item {
      property var block: ({})
      width: root.width
      height: Theme.spaceLg
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }
    }
  }
}
