.pragma library

// A card's HTML cut into the prose around its <pre> blocks and the blocks
// themselves. Qt's rich text draws a <pre> with a grey bar behind every line
// (the theme's `code` background applied per line) and nothing to colour it by,
// so CardFace draws a block as a CodeBlock instead, as the wiki does. Pure;
// tests/unit/tst_cardhtml.qml.
//
//   split(html) -> [{ kind: "prose", html }, { kind: "code", text, lang }]
//
// `lang` is "" unless the block says one (<code class="language-ruby">): a plain
// card names none, and CardFace falls back to its tags. A block's `text` is the
// code itself: entities decoded, <br> as a newline, stray tags dropped, the
// blank lines around it trimmed. The <br>s that only separated prose from a
// block are dropped from the prose, the block being a block already.

var ENTITIES = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " " }

function decode(s) {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, function(m, e) {
    if (e[0] === "#") {
      var n = e[1].toLowerCase() === "x" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10)
      return isNaN(n) ? m : String.fromCodePoint(n)
    }
    var v = ENTITIES[e.toLowerCase()]
    return v === undefined ? m : v
  })
}

function codeOf(inner) {
  var lang = ""
  var m = /<code\b[^>]*\bclass\s*=\s*["'][^"']*\b(?:language|lang)-([\w+#-]+)/i.exec(inner)
  if (m) lang = m[1]
  var text = decode(inner.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, ""))
  return { kind: "code", text: text.replace(/^\n+|\n+$/g, ""), lang: lang }
}

function trimBreaks(html) {
  return html.replace(/^(\s|<br\s*\/?>)+|(\s|<br\s*\/?>)+$/gi, "")
}

function split(html) {
  var out = []
  var re = /<pre\b[^>]*>([\s\S]*?)<\/pre>/gi
  var at = 0
  var m
  function prose(s) {
    s = trimBreaks(s)
    if (s !== "") out.push({ kind: "prose", html: s })
  }
  while ((m = re.exec(html || "")) !== null) {
    prose(html.slice(at, m.index))
    out.push(codeOf(m[1]))
    at = m.index + m[0].length
  }
  prose((html || "").slice(at))
  return out
}
