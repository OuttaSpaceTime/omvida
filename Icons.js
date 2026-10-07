.pragma library

// Material Design glyphs from the Nerd Font the app's monospace resolves to
// (JetBrainsMono Nerd Font on Omarchy), as Omvision's rail draws them. Named
// here once, so a screen says Icons.g("study") rather than a private-use
// code point nobody can read.
var CODES = {
  home: 0xF02DC, study: 0xF0474, wiki: 0xF05DA, cards: 0xF0638, graph: 0xF1049,
  search: 0xF0349, plus: 0xF0415, chevronRight: 0xF0142, chevronDown: 0xF0140,
  discuss: 0xF028C, close: 0xF0156, back: 0xF004D, copy: 0xF018F, page: 0xF0219,
  ask: 0xF0B79, alert: 0xF0026, check: 0xF012C, pencil: 0xF03EB, brain: 0xF09D1
}

function g(name) {
  var c = CODES[name]
  return c ? String.fromCodePoint(c) : ""
}
