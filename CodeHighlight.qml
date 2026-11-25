pragma Singleton
import QtQuick

import "Format.js" as Format

// Syntax colour for the code in a card's HTML, from the wiki service's
// Pygments (the same classes the wiki's code blocks use, so a theme switch
// recolours both). A card has no highlighted form of its own: it is authored
// Anki HTML, and the deck server knows nothing of colour.
//
// A singleton with the client handed in (Store does that), like Theme with its
// colours: CardFace sits below six different screens, and passing the client
// to each would have every one of them carry something only the leaf needs. A
// block shows as plain escaped text until the service answers, and the answers
// are kept, so a card seen again, or the same snippet on its back and in a
// tile, costs one request.
QtObject {
  id: root

  property JsonLineClient client: null
  // key -> html; `version` moves when one arrives, which is what a binding on
  // html() waits for (a var's contents do not notify).
  property var cache: ({})
  property int version: 0
  property var asked: ({})

  // `tags` name the language when the block does not (the first Pygments knows).
  function html(code, lang, tags) {
    // Read only so a binding on html() reruns when an answer arrives.
    if (root.version < 0) return ""
    var key = lang + "\u0000" + (tags || []).join(",") + "\u0000" + code
    var hit = root.cache[key]
    if (hit !== undefined) return hit
    if (root.client !== null && !root.asked[key]) {
      root.asked[key] = true
      // Not from inside the binding that is reading html(): the client's own
      // properties (its request counter) would be written under that read, and
      // QML calls that a binding loop.
      Qt.callLater(function() {
        root.client.call("highlight", { segments: [code], lang: lang, tags: tags || [] }, function(err, out) {
          if (err || !out || out.length !== 1) return
          root.cache[key] = out[0]
          root.version++
        })
      })
    }
    return Format.escapeHtml(code)
  }
}
