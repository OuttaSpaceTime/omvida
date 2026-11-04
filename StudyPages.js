.pragma library

// The wiki pages study has touched, newest first, kept until cleared (the wiki
// panel's "From study"; StudySession.qml holds the list, the wiki service the
// file). Pure: every function returns a new list and never edits the one given.
//
// An entry is { path, title, lapsed }. `lapsed` is the ids of the cards behind
// its red tint rather than a count, so that taking one rating back (Ctrl+Z), or
// a later session getting that card right, can take off just that card's part.

// A rated card's pages (`found`, the wiki service's pagesOfCard) go on top, once
// each. `lapsed` says whether the card was failed in this session.
function touched(pages, found, cardId, lapsed) {
  var paths = found.map(function(p) { return p.path })
  var top = found.map(function(p) {
    var had = pages.find(function(e) { return e.path === p.path })
    var ids = (had ? had.lapsed : []).filter(function(id) { return id !== cardId })
    return { path: p.path, title: p.title, lapsed: lapsed ? ids.concat([cardId]) : ids }
  })
  return top.concat(pages.filter(function(e) { return paths.indexOf(e.path) === -1 }))
}

// The list itself when the card was behind no tint, so the caller can skip
// writing an unchanged list.
function unlapsed(pages, cardId) {
  if (!pages.some(function(e) { return e.lapsed.indexOf(cardId) !== -1 })) return pages
  return pages.map(function(e) {
    return Object.assign({}, e, { lapsed: e.lapsed.filter(function(id) { return id !== cardId }) })
  })
}

function dropped(pages, path) {
  return pages.filter(function(e) { return e.path !== path })
}
