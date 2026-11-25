pragma ComponentBehavior: Bound
import QtQuick

import "CardHtml.js" as CardHtml
import "Format.js" as Format

// A card's front or back. Card text is the simple HTML authored for Anki
// (<br>, <code>, <pre>, <b>, lists), which Qt's rich text draws directly; the
// theme's stylesheet colours code and links. A <pre> block is the exception:
// Qt's rich text puts a grey bar behind each of its lines and has no way to
// colour it, so it is lifted out and drawn as a CodeBlock, highlighted as the
// wiki's code is (CodeHighlight). The language is the block's own
// (<code class="language-ruby">) or else the card's `tags`, which usually name
// it; with neither, the code stays plain.
Column {
  id: root

  property string html: ""
  property int size: Theme.bodySize
  property color color: Theme.ink
  // The card's tags, for a block that names no language. A face with none
  // (a code card's brief, an explanation) is as plain as before.
  property var tags: []

  spacing: Theme.spaceMd

  Repeater {
    model: CardHtml.split(root.html)
    delegate: Loader {
      id: piece
      required property var modelData
      width: root.width
      sourceComponent: piece.modelData.kind === "code" ? codeBlock : prose

      Component {
        id: prose
        UiText {
          textFormat: Text.RichText
          text: Theme.richTextStyle + piece.modelData.html
          wrapMode: Text.Wrap
          font.pixelSize: root.size
          color: root.color
          lineHeight: Theme.proseLineHeight
          // Card HTML has no wiki: links (the wiki service never renders it).
          onLinkActivated: function(link) { if (Format.isExternalUrl(link)) Qt.openUrlExternally(link) }
        }
      }
      Component {
        id: codeBlock
        CodeBlock {
          objectName: "cardCode"
          html: CodeHighlight.html(piece.modelData.text, piece.modelData.lang, root.tags)
          code: piece.modelData.text
          lang: piece.modelData.lang
        }
      }
    }
  }
}
