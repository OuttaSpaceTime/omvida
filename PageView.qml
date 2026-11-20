pragma ComponentBehavior: Bound
import QtQuick

// A wiki page as the wiki service's blocks (render.py says why blocks), laid
// out down one column. Headings are items, so a section link scrolls to one.
// A link clicked in any block comes out as linkActivated, for the screen
// that shows the page to follow.
Column {
  id: root

  property var blocks: []
  signal linkActivated(string link)
  spacing: Theme.spaceMd

  // The y of the heading with this anchor, or -1. The heading is looked up in
  // the blocks, not on the delegates: itemAt returns a plain Item, so a
  // property of the delegate's own would be invisible to qmllint.
  function anchorY(anchor) {
    for (let i = 0; i < root.blocks.length && i < rep.count; i++) {
      let b = root.blocks[i]
      if (b.kind !== "heading" || b.anchor !== anchor) continue
      let it = rep.itemAt(i)
      return it ? it.y : -1
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
      }

      // One component per kind of block. They live in the delegate, so each reads
      // its block straight from blockItem.modelData; declared once beside the Repeater, they
      // took it from the Loader's onLoaded, through `item`, which is typed as a
      // bare QObject, so the assignment was untyped.
      Component {
        id: heading
        RichBlock {
          onLinkActivated: function(link) { root.linkActivated(link) }
          objectName: "heading:" + (blockItem.modelData.anchor || "")
          width: root.width
          html: blockItem.modelData.html || ""
          size: blockItem.modelData.level <= 2 ? Theme.headingSize - Theme.spaceXs : (blockItem.modelData.level === 3 ? Theme.titleSize + Theme.spaceXxs : Theme.subtitleSize)
          font.bold: true
        }
      }
      Component {
        id: rich
        RichBlock {
          onLinkActivated: function(link) { root.linkActivated(link) }
          width: root.width
          html: blockItem.modelData.html || ""
        }
      }
      Component {
        id: code
        CodeBlock {
          width: root.width
          html: blockItem.modelData.html || ""
          code: blockItem.modelData.text || ""
          lang: blockItem.modelData.lang || ""
        }
      }
      Component {
        id: callout
        Rectangle {
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
            SectionLabel { text: blockItem.modelData.label || ""; color: Theme.accentColor }
            RichBlock { width: parent.width; html: blockItem.modelData.html || ""; onLinkActivated: function(link) { root.linkActivated(link) } }
          }
        }
      }
      Component {
        id: quote
        Item {
          width: root.width
          height: qb.implicitHeight
          Rectangle { width: Theme.selectionBarWidth; height: parent.height; color: Theme.hairline }
          RichBlock { id: qb; x: Theme.spaceLg; width: parent.width - Theme.spaceLg; html: blockItem.modelData.html || ""; color: Theme.secondaryInk; onLinkActivated: function(link) { root.linkActivated(link) } }
        }
      }
      Component {
        id: rule
        Item {
          width: root.width
          height: Theme.spaceLg
          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }
        }
      }
    }
  }
}
