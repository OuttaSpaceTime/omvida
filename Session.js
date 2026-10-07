.pragma library
.import "Format.js" as Format

// One study session's own record: what was shown and rated, kept by the app
// because the server only stores counts. It feeds the summary screen, the
// related-pages offer and the session log entry. Pure: every function
// returns a new record, never edits the one it was given.

function empty() {
  return {
    firstShownMs: 0, lastRatedMs: 0,
    reviews: [],      // { cardId, front, tags, rating, suggested, repeat }
    leeches: [],      // "front (N lapses) -> action"
    wikiExplored: []
  }
}

// A new record: `rec` with `changes` laid over it.
function patch(rec, changes) { return Object.assign({}, rec, changes) }

function shown(rec, nowMs) {
  return rec.firstShownMs ? rec : patch(rec, { firstShownMs: nowMs })
}

function rated(rec, card, rating, suggested, repeat, nowMs) {
  var review = {
    cardId: card.id, front: Format.stripHtml(card.front), tags: card.tags || [],
    rating: rating, suggested: suggested || 0, repeat: !!repeat
  }
  return patch(rec, { reviews: rec.reviews.concat([review]), lastRatedMs: nowMs })
}

function leech(rec, card, lapses, what) {
  var line = "\"" + shorten(Format.stripHtml(card.front), 60) + "\" (" + lapses + " lapses) → " + what
  return patch(rec, { leeches: rec.leeches.concat([line]) })
}

function explored(rec, path) {
  return rec.wikiExplored.indexOf(path) !== -1 ? rec : patch(rec, { wikiExplored: rec.wikiExplored.concat([path]) })
}

function shorten(s, n) { return s.length > n ? s.slice(0, n - 1) + "…" : s }

// Unique cards, repeats, accuracy (Good or Easy share), lapses, overrides.
function summary(rec) {
  var unique = {}, repeats = 0, good = 0, overrides = 0, lapses = [], lapsedIds = {}
  rec.reviews.forEach(function(rv) {
    if (rv.repeat) repeats++
    else unique[rv.cardId] = true
    if (rv.rating >= 3) good++
    if (rv.suggested && rv.suggested !== rv.rating) overrides++
    if (rv.rating === 1 && !lapsedIds[rv.cardId]) {
      lapsedIds[rv.cardId] = true
      lapses.push(shorten(rv.front, 60))
    }
  })
  var n = rec.reviews.length
  return {
    cards: Object.keys(unique).length,
    repeats: repeats,
    reviews: n,
    accuracy: n ? good / n : null,
    lapses: lapses,
    overrides: overrides,
    minutes: Format.minutesBetween(rec.firstShownMs, rec.lastRatedMs)
  }
}

// What the related-pages ranking needs: each card once, lapsed if any of its
// ratings was Again.
function studiedCards(rec) {
  var byId = {}, order = []
  rec.reviews.forEach(function(rv) {
    if (!byId[rv.cardId]) { byId[rv.cardId] = { id: rv.cardId, tags: rv.tags, lapsed: false }; order.push(rv.cardId) }
    if (rv.rating === 1) byId[rv.cardId].lapsed = true
  })
  return order.map(function(id) { return byId[id] })
}

// The session log entry the wiki service writes (logs.py format_entry).
function logEntry(rec, calibration) {
  var s = summary(rec)
  return {
    cardsReviewed: s.cards,
    repeats: s.repeats,
    accuracy: s.accuracy,
    calibration: Format.calibrationLine(calibration),
    lapses: s.lapses,
    leeches: rec.leeches,
    overrides: s.overrides,
    duration: Format.durationText(s.minutes),
    wikiExplored: rec.wikiExplored
  }
}
