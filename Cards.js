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

// filters: { query, state, deck, tags }: query, state and deck "" or null
// for "any"; tags a list, every one of which a card must carry. All, not
// any: picking a second tag narrows to the cards that have both, so each
// pick is a step further in, the way the user asked for it. "Any of them"
// would widen with every pick and leave no way to say "security and csp".
function filterCards(cards, filters) {
  var q = String(filters.query || "").trim().toLowerCase()
  var tags = filters.tags || []
  return cards.filter(function(card) {
    if (filters.state && stateOf(card) !== filters.state) return false
    if (filters.deck && card.deck !== filters.deck) return false
    var own = card.tags || []
    for (var i = 0; i < tags.length; i++) if (own.indexOf(tags[i]) === -1) return false
    if (q && searchableText(card).indexOf(q) === -1) return false
    return true
  })
}

// Tags across the given cards, most frequent first, then by name, leaving
// out those in `except`. Given the cards a filter left, these are the tags
// still worth picking, each counted as the cards a pick would leave.
function tagCounts(cards, except) {
  var counts = {}, skip = except || []
  cards.forEach(function(c) {
    (c.tags || []).forEach(function(t) { if (skip.indexOf(t) === -1) counts[t] = (counts[t] || 0) + 1 })
  })
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

// The chosen filters, in the order the explorer lists them, each with its
// label: the chips on top of the filter column.
function selectedFilters(filters) {
  var out = []
  if (filters.state) out.push({ kind: "state", value: filters.state, label: filters.state })
  if (filters.deck) out.push({ kind: "deck", value: filters.deck, label: filters.deck })
  var tags = filters.tags || []
  for (var i = 0; i < tags.length; i++) out.push({ kind: "tag", value: tags[i], label: "#" + tags[i] })
  return out
}

// The tag counts whose name holds `text`, ignoring case and a leading "#":
// the tag panel's list as you type. Tags that start with it come first, so
// "sec" puts #security above #websecurity; each keeps its count order.
function matchTags(counts, text) {
  var t = String(text || "").trim().toLowerCase().replace(/^#/, "")
  if (t === "") return counts
  var starts = [], within = []
  counts.forEach(function(c) {
    var i = c.tag.toLowerCase().indexOf(t)
    if (i === 0) starts.push(c)
    else if (i > 0) within.push(c)
  })
  return starts.concat(within)
}

// The active filters in a few words ("review · #http · “etag”"), "" for
// none: the status line's segment for the deck explorer.
function filterSummary(filters) {
  var parts = selectedFilters(filters).map(function(f) { return f.label })
  var q = filters.query.trim()
  if (q) parts.push("“" + q + "”")
  return parts.join(" · ")
}
