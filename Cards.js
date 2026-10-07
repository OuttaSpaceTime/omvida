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
