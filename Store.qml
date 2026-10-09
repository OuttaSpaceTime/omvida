import QtQuick

// The app's data, apart from the window that shows it: the two backends
// (flashcard-mcp's app server for the deck, backend/omvida_backend for the
// wiki, both JSON lines through JsonLineClient.qml) and what has been loaded
// from them. It holds no business rules: the deck's live in flashcard-mcp,
// the wiki's in the study repo's scripts/wiki. Screens read it as app.store.
Item {
  id: root

  readonly property alias deck: deckClient
  readonly property alias wiki: wikiClient
  // Whether the window is in front: the wiki poll runs only then.
  property bool active: true

  property var wikiIndex: null          // {pages, tree, graph, stamp}
  property var pagesByPath: ({})
  property var allCards: []
  property bool cardsLoaded: false
  property var overview: null
  property var recentPages: []
  property string status: ""            // a one-line note for the top bar
  property double refreshedAt: 0

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

  function loadOverview() {
    deckClient.call("overview", { pendingLimit: 0 }, function(err, o) {
      if (err) { root.status = "deck: " + err; return }
      root.overview = o
    })
  }

  function loadCards() {
    deckClient.call("cards", {}, function(err, cards) {
      if (err) { root.status = "deck: " + err; return }
      // A refresh that changed nothing keeps the same array: a new one
      // rebuilds every tile of the Cards grid, and refreshes come on every
      // visit to Cards and every return to the window.
      if (JSON.stringify(cards) !== JSON.stringify(root.allCards)) root.allCards = cards
      root.cardsLoaded = true
    })
  }

  function loadRecentPages() {
    deckClient.call("recentlyStudied", { limit: 100 }, function(err, studied) {
      if (err || !root.wikiIndex) return
      wikiClient.call("recent", { studied: studied, limit: 8 }, function(err2, pages) {
        if (!err2) root.recentPages = pages
      })
    })
  }

  // After anything that changes the deck: a session, a leech decision, a
  // return from Claude Code.
  function refreshDeck() {
    root.refreshedAt = Date.now()
    loadOverview()
    loadCards()
    loadRecentPages()
  }

  JsonLineClient {
    id: deckClient
    name: "deck"
    command: [Paths.deckBin]
    onReadyChanged: if (ready) { root.loadOverview(); root.loadCards() }
  }

  JsonLineClient {
    id: wikiClient
    name: "wiki"
    command: [Paths.wikiBin]
    onReadyChanged: if (ready) root.loadIndex()
  }

  // A page written by a Claude session shows up without a restart: the wiki
  // service's stamp is the mtime and size of every page, cheap to compare.
  // Only while the window is in front: a background window has nothing to
  // show it on, and coming back to the front refreshes anyway.
  Timer {
    interval: Theme.wikiPollInterval
    running: wikiClient.ready && root.active
    repeat: true
    onTriggered: wikiClient.call("stamp", {}, function(err, s) {
      if (!err && root.wikiIndex && s.stamp !== root.wikiIndex.stamp) {
        root.loadIndex()
        root.wikiFilesChanged()
      }
    })
  }
}
