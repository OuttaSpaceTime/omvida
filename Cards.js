.pragma library

// The deck explorer's filters and counts, ported from the Next.js viewer's
// components/flashcards/lib.ts so both surfaces filter the same way.

var STATE_ORDER = ["new", "learning", "review", "relearning", "suspended"]

function stateOf(card) {
  return card.suspended ? "suspended" : card.state
}

function searchableText(card) {
  return (card.front + " " + card.back + " " + (card.tags || []).join(" "))
    .replace(/<[^>]*>/g, " ").toLowerCase()
}

// filters: { query, state, tag, deck }, each "" or null for "any".
function filterCards(cards, filters) {
  var q = String(filters.query || "").trim().toLowerCase()
  return cards.filter(function(card) {
    if (filters.state && stateOf(card) !== filters.state) return false
    if (filters.deck && card.deck !== filters.deck) return false
    if (filters.tag && (card.tags || []).indexOf(filters.tag) === -1) return false
    if (q && searchableText(card).indexOf(q) === -1) return false
    return true
  })
}

// Tags across the deck, most frequent first, then by name.
function tagCounts(cards) {
  var counts = {}
  cards.forEach(function(c) { (c.tags || []).forEach(function(t) { counts[t] = (counts[t] || 0) + 1 }) })
  return Object.keys(counts).map(function(t) { return { tag: t, count: counts[t] } })
    .sort(function(a, b) { return b.count - a.count || (a.tag < b.tag ? -1 : a.tag > b.tag ? 1 : 0) })
}

function deckNames(cards) {
  var seen = {}
  cards.forEach(function(c) { seen[c.deck] = true })
  return Object.keys(seen).sort()
}

// Non-empty states in STATE_ORDER, with counts, for the state bar.
function stateCounts(cards) {
  var counts = {}
  cards.forEach(function(c) { var s = stateOf(c); counts[s] = (counts[s] || 0) + 1 })
  return STATE_ORDER.filter(function(s) { return counts[s] > 0 })
    .map(function(s) { return { state: s, count: counts[s] } })
}

// A page's cards: its declared flashcard_ids in order, or, for a page that
// declares none, up to 12 cards sharing a tag (the viewer's fallback).
function cardsForPage(page, allCards) {
  if (!page) return []
  var ids = page.flashcardIds || []
  if (ids.length > 0) {
    var byId = {}
    allCards.forEach(function(c) { byId[c.id] = c })
    return ids.map(function(id) { return byId[id] }).filter(function(c) { return !!c })
  }
  var tags = (page.tags || []).map(function(t) { return t.toLowerCase() })
  if (tags.length === 0) return []
  return allCards.filter(function(c) {
    return (c.tags || []).some(function(t) { return tags.indexOf(t.toLowerCase()) !== -1 })
  }).slice(0, 12)
}

// A card's text with its markup gone, on one line: the grid's tiles show a
// few lines of the front, and Qt only elides plain text (rich text runs on
// past maximumLineCount), so a tile draws this rather than the HTML. Code
// loses its shading here; the app's face is monospace, so it still reads as
// code, and the stage above the grid shows the card as authored. &amp; is
// decoded last, so "&amp;lt;" stays the literal text "&lt;".
function plainText(html) {
  return String(html || "")
    .replace(/<br\s*\/?>|<\/(p|div|li|pre|tr|h[1-6])>/gi, " ")
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;/g, " ").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'")
    .replace(/&#(\d+);/g, function(m, n) { return String.fromCharCode(parseInt(n, 10)) })
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ").trim()
}

// The active filters in a few words ("review · #http · “etag”"), "" for
// none: the status line's segment for the deck explorer.
function filterSummary(filters) {
  var parts = []
  if (filters.state) parts.push(filters.state)
  if (filters.deck) parts.push(filters.deck)
  if (filters.tag) parts.push("#" + filters.tag)
  var q = String(filters.query || "").trim()
  if (q) parts.push("“" + q + "”")
  return parts.join(" · ")
}

// Where a card is in a list, by id, or -1: the flip-through keeps its place
// across a refresh of the deck, which hands it a new list of the same cards.
function indexOfId(cards, id) {
  if (!id) return -1
  for (var i = 0; i < cards.length; i++) if (cards[i].id === id) return i
  return -1
}
