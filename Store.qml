import QtQuick
import Quickshell

// The app's data, apart from the window that shows it: the two backends
// (flashcard-mcp's app server for the deck, backend/omvida_backend for the
// wiki, both JSON lines through JsonLineClient.qml) and what has been loaded
// from them. It holds no business rules: the deck's live in flashcard-mcp,
// the wiki's in the study repo's scripts/wiki. Screens, dialogs and the
// sessions read it as app.store, backends included (app.store.deck,
// app.store.wiki): none is handed a client of its own, so there is one way in.
Item {
  id: root

  readonly property alias deck: deckClient
  readonly property alias wiki: wikiClient
  // Whether the window is in front: the wiki and deck polls run only then.
  property bool active: true

  property var wikiIndex: null          // {pages, tree, graph, stamp}
  property var pagesByPath: ({})
  readonly property var graph: wikiIndex ? wikiIndex.graph : null
  property var allCards: []
  property bool cardsLoaded: false
  property var overview: null
  property var recentPages: []
  property string status: ""            // a one-line note for the top bar
  property double refreshedAt: 0
  // The deck server's stamp, in three parts: the cards' content (count and
  // newest edit; a review does not move it), the reviews, and the notes, so
  // each reloads only what it changed.
  property string deckStamp: ""
  property string reviewsStamp: ""
  property string notesStamp: ""
  // A study session is open (App.qml binds it). Its ratings then reload
  // only the overview, for the due count and the bar; the cards' scheduling
  // waits for the session's end (scheduleStale), as nothing on screen shows
  // it, where a reload per rating cost a whole-deck read each time.
  property bool studying: false
  property bool scheduleStale: false
  // Every card by id, for the lists that name a card by its id (notes,
  // Home's past sessions), as pagesByPath does for pages.
  readonly property var cardsById: {
    var m = {}
    allCards.forEach(function(c) { m[c.id] = c })
    return m
  }
  // Card notes (flashcard-mcp's CardNote), card id -> { cardId, body,
  // createdAt }, oldest first as the server sends them; written mid-study,
  // handled in a fix session.
  property var notes: ({})
  readonly property int noteCount: Object.keys(notes).length
  // Recent study sessions with the cards each lapsed and noted (the deck
  // server's `sessions`), newest first, for Home.
  property var sessions: []

  // A wiki page changed on disk (a Claude session wrote one).
  signal wikiFilesChanged()

  function loadIndex() {
    wikiClient.call("index", {}, function(err, idx) {
      if (err) { root.status = "wiki: " + err; return }
      var by = {}
      idx.pages.forEach(function(p) { by[p.path] = p })
      root.pagesByPath = by
      root.wikiIndex = idx
      root.loadRecentPages()
    })
  }

  // Sets `prop` to a freshly loaded `value` only if it differs: an unchanged
  // reload keeps the same object, so nothing bound to it re-runs. A new cards
  // array rebuilds every tile of the Cards grid, a new overview goes to the
  // bar, and reloads come with every poll that sees the stamp move.
  function put(prop, value) {
    if (JSON.stringify(value) !== JSON.stringify(root[prop])) root[prop] = value
  }

  function loadOverview() {
    root.refreshedAt = Date.now()
    deckClient.call("overview", { pendingLimit: 0 }, function(err, o) {
      if (err) { root.status = "deck: " + err; return }
      root.put("overview", o)
    })
  }

  // The bar shows this same overview; hand it each new one (its setOverview,
  // docs/architecture.md). Best effort: -q is quiet with no shell or plugin.
  onOverviewChanged: Quickshell.execDetached(["omarchy-shell", "-q", "omvida.bar", "setOverview", JSON.stringify(overview)])

  function loadCards() {
    deckClient.call("cards", {}, function(err, cards) {
      if (err) { root.status = "deck: " + err; return }
      root.put("allCards", cards)
      root.cardsLoaded = true
    })
  }

  function loadNotes() {
    deckClient.call("notes", {}, function(err, list) {
      if (err) { root.status = "deck: " + err; return }
      var m = {}
      list.forEach(function(n) { m[n.cardId] = n })
      root.put("notes", m)
    })
  }

  function loadSessions() {
    deckClient.call("sessions", { limit: Config.homeSessions }, function(err, list) {
      if (!err) root.put("sessions", list)
    })
  }

  // Deletes a card and its review history (flashcard-mcp's deleteCard: a
  // leech dropped, Del in Study or on the Cards stage), then checks the deck:
  // a delete moves the cards' stamp, so that is one reload, even mid-session,
  // and the poll does not repeat it. `done(err)` runs once the deck has it.
  function deleteCard(cardId, done) {
    deckClient.call("deleteCard", { cardId: cardId }, function(err) {
      if (!err) root.checkDeck()
      if (done) done(err)
    })
  }

  // Writes a card's note (an empty body deletes it), then reloads the notes
  // whatever their stamp says, as refreshDeck does the cards. `done(err)`
  // runs once the deck has it.
  function saveNote(cardId, body, done) {
    deckClient.call("setNote", { cardId: cardId, body: body }, function(err) {
      if (!err) { root.notesStamp = ""; root.checkDeck() }
      if (done) done(err)
    })
  }

  // The cards with an open note, oldest note first (the order `notes`
  // keeps): what a fix session gets (Launch.fixNotesArgv). `ids` narrows it
  // to those cards (a summary's, the Cards filter's); null takes every note.
  function notedIds(ids) {
    return Object.keys(root.notes).filter(function(id) { return root.cardsById[id] && (!ids || ids.indexOf(id) !== -1) })
  }

  function loadRecentPages() {
    deckClient.call("recentlyStudied", { limit: 100 }, function(err, studied) {
      if (err || !root.wikiIndex) return
      wikiClient.call("recent", { studied: studied, limit: 8 }, function(err2, pages) {
        if (!err2) root.recentPages = pages
      })
    })
  }

  // A moved stamp (a card written by anyone: Claude Code, the CLI, this
  // app) reloads the deck; the first check is the initial load. Pushed by the
  // deckChanged IPC and polled while in front: docs/architecture.md has why.
  // Reviews (this app's, a /study chat's) reload the deck too, except during
  // a session (`studying`); the notes have their own part, which reloads only
  // them. Past sessions follow the deck and the notes. `overviewToo` re-reads
  // the overview even if nothing moved: its due counts move with the clock.
  function checkDeck(overviewToo) {
    if (!deckClient.ready) return
    deckClient.call("stamp", {}, function(err, s) {
      if (err) return
      var cards = s.stamp !== root.deckStamp
      var reviews = s.reviews !== root.reviewsStamp
      var notes = s.notes !== root.notesStamp
      root.deckStamp = s.stamp
      root.reviewsStamp = s.reviews
      root.notesStamp = s.notes
      var deck = cards || ((reviews || root.scheduleStale) && !root.studying)
      if (reviews && !deck) root.scheduleStale = true
      if (deck || reviews || overviewToo) root.loadOverview()
      if (deck) {
        root.scheduleStale = false
        root.loadCards()
        root.loadRecentPages()
      }
      if (notes) root.loadNotes()
      if (deck || notes) root.loadSessions()
    })
  }

  // After the app's own writes (a session, a leech decision, a delete): a
  // reload whatever the stamp says, which it then holds, so the poll does not
  // reload the same writes again.
  function refreshDeck() {
    root.deckStamp = ""
    root.checkDeck()
  }

  // Coming back to the front checks the deck at once, and re-reads the
  // overview if it is a while old: its due counts move with no write at all.
  onActiveChanged: if (active) checkDeck(Date.now() - refreshedAt > 15000)

  JsonLineClient {
    id: deckClient
    name: "deck"
    command: [Paths.deckBin]
    onReadyChanged: if (ready) root.checkDeck()
  }

  JsonLineClient {
    id: wikiClient
    name: "wiki"
    command: [Paths.wikiBin]
    onReadyChanged: if (ready) root.loadIndex()
  }

  // A page written by a Claude session shows up without a restart: the wiki
  // service's stamp is compared, only while the window is in front. A
  // background window has nothing to show it on, and coming back to the
  // front refreshes anyway.
  Timer {
    interval: Config.wikiPollInterval
    running: wikiClient.ready && root.active
    repeat: true
    onTriggered: wikiClient.call("stamp", {}, function(err, s) {
      if (!err && root.wikiIndex && s.stamp !== root.wikiIndex.stamp) {
        root.loadIndex()
        root.wikiFilesChanged()
      }
    })
  }

  // Not triggered on start: the client's start and coming back to the front
  // check the deck already (onReadyChanged, onActiveChanged).
  Timer {
    interval: Config.deckPollInterval
    running: deckClient.ready && root.active
    repeat: true
    onTriggered: root.checkDeck()
  }

  // Debounced: the IPC comes once per card Claude writes.
  Timer {
    id: pushed
    interval: Config.deckPushDebounce
    onTriggered: root.checkDeck()
  }
  function deckPushed() { pushed.restart() }
}
