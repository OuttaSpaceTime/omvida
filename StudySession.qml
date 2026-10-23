import QtQuick

import "StudyKeys.js" as StudyKeys
import "Launch.js" as Launch
import "Session.js" as Session
import "Format.js" as Format

// A study session: the /study skill's loop, as state and actions with no view.
// StudyScreen draws it; App.qml owns it (app.study), beside the store, so the
// tests drive it directly and the window can ask it for a pending log entry.
// It is handed the store and nothing of the window: what it wants shown (a
// toast, Claude Code in kitty, the note dialog, the delete confirm) it asks
// for by a signal, and App.qml decides how. It held the whole App at first,
// and so opened overlays from inside the study loop's logic. Which phases mean what (running, cardShown, frontShown,
// backShown...) is said here once; views and the window read those, never a
// list of phases of their own, so a new phase is one file's change.
//
//   front shown, answer typed (or not)  ->  reveal: the back, and Claude's
//                                            suggested rating with its reason
//   then: submit the suggestion, Good, or any rating
//
// The grade starts before the reveal: whenever typing pauses (Config.gradePause),
// the answer so far is graded in the background, and a reveal with the answer
// unchanged takes that grade, often already in. A changed answer is graded
// afresh, never sent on to the earlier grade's conversation, so a draft and
// its verdict cannot sway the rating. The deck server runs the claudes:
// nextCard ends the last card's grade, so a rating given without Claude's
// leaves none running, and one spare claude stays booted for the session.
//
// StudyKeys.js decides what a key means; handleKey() carries it out. The
// session itself is flashcard-mcp's: the queue, the scheduling, the leech
// block and the new-card cap live in the deck server, and what is shown
// (Card 3/12, the next-review line) is its own numbers.
//
// What /study does around the loop is kept: Anki sync before (phone reviews
// first) and after; at the end the summary, the wiki pages related to what
// was studied, and the session log entry. Leeches stop the session until
// they are dealt with.
QtObject {
  id: root

  required property Store store
  readonly property JsonLineClient deck: store.deck
  readonly property JsonLineClient wikiService: store.wiki
  // The answer as typed, bound from the view's answer box.
  property string answer: ""

  // idle | syncing | starting | loading | answering | grading | revealed |
  // submitting | blocked | done | error
  property string phase: "idle"
  property string sessionId: ""
  // The session the summary is about, once finish() has cleared sessionId.
  property string endedId: ""
  // The cards noted during this session: the deck server's account of it
  // (Store.sessions, `noted`: notes written in its time and still open), the
  // same as Home's, so a note deleted again no longer counts. Not kept here
  // as well: two records of one fact disagreed.
  readonly property var noted: {
    var id = root.sessionId !== "" ? root.sessionId : root.endedId
    var s = root.store.sessions.find(function(x) { return x.id === id })
    return s ? s.noted : []
  }
  property var info: null        // startSession's result
  property var next: null        // nextCard's result
  readonly property var card: next && next.card ? next.card : null
  property var suggestion: null
  property string gradeError: ""
  property bool acceptPending: false
  // The rating Shift+digit picked on this card, 1..4, else 0: the same
  // digit again or Shift+Enter submits it (StudyKeys.js).
  property int picked: 0
  // The rating on its way to the deck, 1..4, else 0: the view shows it taken
  // (StudyCard.qml) before the card fades out.
  property int chosen: 0
  property int gradeSeq: 0
  // The latest grade asked for, { text, done, err, res }: reveal() takes it
  // when the answer is still that text (trimmed, for the comparison only),
  // done or on its way. A failed one is asked for again.
  property var early: null
  property var rec: Session.empty()
  property double shownAt: 0
  property double revealedAt: 0
  property var blocked: null     // { card, lapses }
  readonly property var summaryData: phase === "done" ? Session.summary(rec) : null
  property var related: []
  property bool logPending: false
  property string errorText: ""
  property string syncNote: ""

  // A session is under way: from the sync to the summary, which is not.
  // The store holds the cards' scheduling back meanwhile (Store.studying).
  readonly property bool running: phase !== "idle" && phase !== "done" && phase !== "error"
  // Before the first card: syncing with Anki, then asking the deck for a session.
  readonly property bool opening: phase === "syncing" || phase === "starting"
  readonly property bool inCard: phase === "answering" || phase === "grading" || phase === "revealed" || phase === "submitting"
  // A card is up and nothing is on its way to the deck: it can still change
  // under the session (catchUp) or be deleted (askDelete).
  readonly property bool cardOpen: phase === "answering" || phase === "grading" || phase === "revealed"
  // The back is on screen: grading, revealed, and a rating on its way (every
  // rating follows a reveal: a first Shift+digit reveals and picks). A
  // delete from the answer keeps the answering layout until the next card.
  readonly property bool backShown: phase === "grading" || phase === "revealed" || (phase === "submitting" && revealedAt > 0)
  // The card on screen: one up, or the next on its way (loading), when the
  // view dims the last one rather than drop it.
  readonly property bool cardShown: inCard || phase === "loading"
  // Its front is what counts: answering, between cards (so the status line
  // does not flicker through a third set of keys on every card), or a delete
  // from the answer on its way.
  readonly property bool frontShown: phase === "answering" || phase === "loading" || (phase === "submitting" && !backShown)

  // What it asks of the window (App.qml wires each).
  signal toastRequested(string text)
  // Claude Code in kitty (Launch.js has every argv), with a toast.
  signal launchRequested(var argv, string note)
  // The note dialog on `card`; `prefill` starts a new note.
  signal noteAsked(var card, string prefill)
  // The delete confirm for `card`; its accept calls deleteCard(card).
  signal deleteAsked(var card)

  // The view empties the answer box: a new card is on its way.
  signal answerReset()
  // Alt+?: the view shows the list of keys (KeyHelp.qml).
  signal keysWanted()

  property AnkiSync sync: AnkiSync {}

  property Timer pauseTimer: Timer {
    interval: Config.gradePause
    onTriggered: root.gradeEarly()
  }
  onAnswerChanged: if (phase === "answering") pauseTimer.restart()

  // A rating is written at once and the next card asked for right after,
  // but shown only once settleMs have passed: the view shows the rating
  // taken and fades the card out within them (StudyCard.qml fits its fade
  // into this one number), and a card shown sooner would swap the layout
  // under the fade. Asking only after the wait, as at first, added a round
  // trip to every rating. Ended or failed meanwhile (or ended and started
  // again before the reply), the session is past that card: the phase and
  // cardSeq drop the reply.
  property int settleMs: Theme.acceptShowDuration + Theme.acceptFadeDuration
  property int cardSeq: 0
  property var held: null        // { seq, err, res }: nextCard's reply, waiting out settleMs
  property Timer settleTimer: Timer {
    interval: root.settleMs
    onTriggered: root.showHeld()
  }

  // ---- the session ----------------------------------------------------------------
  function startIfIdle() {
    if (!running) start()
  }

  function start() {
    root.phase = "syncing"   // first: leaving the summary writes its log entry
    root.rec = Session.empty()
    root.related = []
    root.syncNote = ""
    sync.run(function(r) {
      if (r.note !== "") root.syncNote = r.note
      if (r.moved) root.store.refreshDeck()
      root.openSession()
    })
  }

  function skipSync() {
    if (root.phase === "syncing") root.openSession()
  }

  function openSession() {
    if (root.phase !== "syncing") return
    root.phase = "starting"
    deck.call("startSession", {}, function(err, res) {
      if (err) { root.fail(err); return }
      root.sessionId = res.sessionId
      root.endedId = ""
      root.info = res
      root.loadNext()
    })
  }

  function loadNext() {
    root.clearCard()
    deck.call("nextCard", { sessionId: root.sessionId }, root.showNext)
  }

  // The card that was up goes, with its pick, its rating, its grade and its
  // answer, and any next card still held for it.
  function clearCard() {
    root.phase = "loading"
    root.picked = 0
    root.chosen = 0
    root.cardSeq++
    root.held = null
    settleTimer.stop()
    root.dropGrade()
    root.answerReset()
  }

  // nextCard's reply: a card, a leech's block, or the end.
  function showNext(err, res) {
    if (err) { root.fail(err); return }
    if (res.blocked) {
      root.blocked = res.blocked
      root.next = null
      root.phase = "blocked"
      return
    }
    if (res.done) { root.finish(); return }
    root.blocked = null
    root.next = res
    root.shownAt = Date.now()
    root.revealedAt = 0
    root.rec = Session.shown(root.rec, root.shownAt)
    root.phase = "answering"
  }

  // The next card after a rating, once it is in and settleMs are over.
  function showHeld() {
    var h = root.held
    if (!h || settleTimer.running || h.seq !== root.cardSeq || root.phase !== "submitting") return
    root.clearCard()
    root.showNext(h.err, h.res)
  }

  // Forget the suggestion, and any grade still running.
  function dropGrade() {
    root.suggestion = null
    root.gradeError = ""
    root.acceptPending = false
    root.forgetGrade()
  }

  // A grade still running (or one to come on a pause) is no longer wanted:
  // gradeSeq drops its reply.
  function forgetGrade() {
    root.gradeSeq++
    root.early = null
    pauseTimer.stop()
  }

  function fail(msg) {
    root.errorText = String(msg)
    root.phase = "error"
  }

  // ---- one card -------------------------------------------------------------------
  function reveal(thenAccept) {
    if (root.phase !== "answering") return
    root.revealedAt = Date.now()
    if (root.answer.trim() === "") {
      root.phase = "revealed"
      return
    }
    root.phase = "grading"
    root.acceptPending = !!thenAccept
    // Graded on a pause: take it now, or as it comes in (requestGrade).
    var e = root.early
    if (!e || e.text !== root.answer.trim() || (e.done && e.err)) root.requestGrade()
    else if (e.done) root.takeGrade(null, e.res)
  }

  // Typing paused: grade the answer so far, unless it was graded as it is.
  function gradeEarly() {
    var text = root.answer.trim()
    if (root.phase !== "answering" || text === "" || (root.early && root.early.text === text)) return
    root.requestGrade()
  }

  // Grades the answer as typed. A newer grade ends the one still running on
  // the server, and gradeSeq drops its reply.
  function requestGrade() {
    var seq = ++root.gradeSeq
    var early = { text: root.answer.trim(), done: false, err: null, res: null }
    root.early = early
    deck.call("grade", { cardId: root.card.id, answer: root.answer }, function(err, res) {
      if (seq !== root.gradeSeq) return
      early.done = true
      early.err = err
      early.res = res
      if (root.phase === "grading") root.takeGrade(err, res)
    })
  }

  function takeGrade(err, res) {
    if (err) {
      root.gradeError = err
      root.acceptPending = false
    } else {
      root.suggestion = res
    }
    if (root.phase === "grading") root.phase = "revealed"
    if (root.acceptPending && root.suggestion) root.submit(root.suggestion.rating)
  }

  // Shift+digit: reveal if need be and hold the rating for a second press.
  // A pick overrides the suggestion, so an Alt+Enter still pending from the
  // reveal no longer takes it.
  function pick(rating) {
    if (!root.card || root.phase === "submitting") return
    root.picked = rating
    root.acceptPending = false
    root.reveal(false)
  }

  function submit(rating) {
    if (!root.card || root.phase === "submitting") return
    var c = root.card
    var repeat = root.next.repeat
    var suggested = root.suggestion ? root.suggestion.rating : 0
    var responseMs = (root.revealedAt || Date.now()) - root.shownAt
    var seq = root.cardSeq
    root.forgetGrade()
    root.chosen = rating
    root.phase = "submitting"
    settleTimer.restart()
    deck.call("review", { sessionId: root.sessionId, cardId: c.id, rating: rating, responseMs: responseMs }, function(err) {
      if (err) { root.fail(err); return }
      root.rec = Session.rated(root.rec, c, rating, suggested, repeat, Date.now())
      if (seq !== root.cardSeq || root.phase !== "submitting") return
      deck.call("nextCard", { sessionId: root.sessionId }, function(err, res) {
        root.held = { seq: seq, err: err, res: res }
        root.showHeld()
      })
    })
  }

  // ---- a card changed in Claude Code ----------------------------------------------
  // Discuss, Fix card and a leech's Rewrite or Split hand the card to Claude
  // Code, which saves it from another process; the store reloads every card
  // (Store.checkDeck) and the session looks its own up in that list.
  //   changed: it replaces the shown one where it is, back shown or not, so
  //            the rating is of the card as it now is; the suggestion was for
  //            the old one and goes.
  //   gone (split, deleted): on to the next card.
  //   a blocked leech changed or gone: ask for the next card, and the server
  //            decides whether the block lifts (Continue, pressed for you).
  property Connections deckWatch: Connections {
    target: root.store
    function onAllCardsChanged() { root.catchUp() }
  }

  function catchUp() {
    var byId = root.store.cardsById
    var find = function(id) { return byId[id] || null }
    if (root.phase === "blocked") {
      let b = find(root.blocked.card.id)
      if (b && JSON.stringify(b) === JSON.stringify(root.blocked.card)) return
      root.toastRequested(b ? "The leech changed in Claude Code" : "The leech is gone from the deck")
      root.loadNext()
      return
    }
    if (!root.cardOpen) return
    var c = find(root.card.id)
    if (!c) {
      root.toastRequested("This card was removed in Claude Code")
      root.loadNext()
      return
    }
    if (JSON.stringify(c) === JSON.stringify(root.card)) return
    root.next = Object.assign({}, root.next, { card: c })
    root.dropGrade()
    if (root.phase === "grading") root.phase = "revealed"
    // An answer already typed is graded against the card as it now is.
    if (root.phase === "answering") pauseTimer.restart()
    root.toastRequested("Card updated in Claude Code")
  }

  // Only while the card is open: once a rating is on its way (and the view
  // shows it taken), the server's queue has moved on, so a skip would pass
  // over the next card unseen.
  function skip() {
    if (!root.cardOpen) return
    deck.call("skip", { sessionId: root.sessionId }, function() { root.loadNext() })
  }

  function discuss() {
    if (!root.card) return
    root.launchRequested(Launch.discussArgv(Paths.studyDir, root.card, root.answer, root.suggestion),
                    "Discussing in Claude Code. Rate the card when you're back.")
  }

  function fixCard() {
    if (!root.card || !root.suggestion || !root.suggestion.quality) return
    root.launchRequested(Launch.fixCardArgv(Paths.studyDir, root.card, root.suggestion.quality), "Opened Claude Code to fix the card")
  }

  // Note the card for later (NoteDialog.qml), and go on studying: a fix
  // session takes every note at once (Launch.fixNotesArgv). A card the
  // grader flagged starts its note with the flag, so "fix in claude" need
  // not break the session. The answer box keeps what was typed; the window
  // hands the keyboard back to it when the dialog closes.
  function note() {
    if (!root.card) return
    var q = root.suggestion ? root.suggestion.quality : null
    root.noteAsked(root.card, q ? "> " + Format.cardIssue(q) + "\n\n" : "")
  }

  // Delete the card on screen, once the window's confirm dialog says so
  // (deleteAsked: its accept calls deleteCard with the card asked about).
  // The deck server deletes it and its history (deleteCard, as for a leech)
  // and its session passes over a deleted card's place in the queue
  // (flashcard-mcp's getNextCard), so the next card follows as after a
  // rating. The session record notes nothing: the card was not rated, and
  // the log's lines are flashcard-mcp's format.
  function askDelete() {
    if (!root.card || !root.cardOpen) return
    root.deleteAsked(root.card)
  }

  function deleteCard(c) {
    if (!root.card || root.card.id !== c.id || root.phase === "submitting") return
    root.forgetGrade()
    root.phase = "submitting"
    root.store.deleteCard(c.id, function(err) {
      if (err) { root.fail(err); return }
      root.loadNext()
    })
  }

  // A key from the answer box (or, with no card up, the screen): true when
  // it was a study key, which the box then doesn't type.
  function handleKey(event) {
    var a = StudyKeys.action({ phase: root.phase, hasSuggestion: !!root.suggestion, answerEmpty: root.answer.trim() === "", picked: root.picked },
                             event.key, event.modifiers, event.nativeScanCode)
    if (!a) return false
    switch (a.action) {
    case "reveal": root.reveal(false); break
    case "revealAccept": root.reveal(true); break
    case "accept": root.submit(root.suggestion.rating); break
    case "acceptLater": root.acceptPending = true; break
    case "pick": root.pick(a.rating); break
    case "submit": root.submit(a.rating); break
    case "discuss": root.discuss(); break
    case "skip": root.skip(); break
    case "note": root.note(); break
    case "delete": root.askDelete(); break
    case "end": root.endNow(); break
    case "start": root.start(); break
    case "continue": root.loadNext(); break
    case "help": root.keysWanted(); break
    }
    return true
  }

  // ---- leeches ------------------------------------------------------------------------
  function leechFix(how) {
    root.launchRequested(Launch.leechArgv(Paths.studyDir, root.blocked.card, root.blocked.lapses, how),
                    "Fix it in Claude Code: the session goes on once it is saved")
    root.rec = Session.leech(root.rec, root.blocked.card, root.blocked.lapses, how === "split" ? "split in Claude Code" : "rewritten in Claude Code")
  }

  // Keep the card as is (the deck server's resolveLeech) or drop it, then go on.
  function leechKeep() {
    var b = root.blocked
    deck.call("resolveLeech", { cardId: b.card.id }, function(err) { root.leechResolved(err, b, "kept as is") })
  }
  function leechDrop() {
    var b = root.blocked
    root.store.deleteCard(b.card.id, function(err) { root.leechResolved(err, b, "deleted") })
  }
  function leechResolved(err, b, note) {
    if (err) { root.fail(err); return }
    root.rec = Session.leech(root.rec, b.card, b.lapses, note)
    root.loadNext()
  }

  // ---- pages from study ----------------------------------------------------------------
  // The wiki pages a finished session pointed to (its summary's related
  // pages), kept for the wiki's side panel so they stay one click apart while
  // you read them: the summary is gone once a page is open, and was the only
  // place they were listed. Newest session's first, each page once, until
  // cleared (one by one or all) or the app closes, so across sessions.
  // [{ path, title, lapsed, via, cards }]
  property var pages: []
  function addPages(list) {
    var paths = list.map(function(p) { return p.path })
    root.pages = list.concat(root.pages.filter(function(p) { return paths.indexOf(p.path) === -1 }))
  }
  function dropPage(path) { root.pages = root.pages.filter(function(p) { return p.path !== path }) }
  function clearPages() { root.pages = [] }

  // ---- the end ------------------------------------------------------------------------
  function finish() {
    root.phase = "done"
    root.next = null
    var sid = root.sessionId
    if (sid !== "") deck.call("endSession", { sessionId: sid }, function() {})
    root.endedId = sid
    root.sessionId = ""
    if (root.rec.reviews.length === 0) return
    root.logPending = true
    wikiService.call("related", { studied: Session.studiedCards(root.rec), limit: 3 }, function(err, pages) {
      if (err) return
      root.related = pages
      // Kept in the wiki's side panel too, where they stay once a page is open.
      root.addPages(pages)
    })
    root.store.refreshDeck()
  }

  // End early: what was reviewed still counts, and the session is closed.
  function endNow() {
    if (root.phase === "idle" || root.phase === "done") return
    root.forgetGrade()
    root.finish()
  }

  // A page opened from the summary (or anywhere, mid-session) goes in the log's
  // Wiki explored line. The view writes the entry when the summary stops being
  // shown (another screen, another session), and the window when the app
  // quits, so what was opened from the summary is in it.
  function notePageOpened(path) {
    if (root.phase === "idle") return
    root.rec = Session.explored(root.rec, path)
  }

  // `then` runs once the entry is on disk (the app quitting waits for it).
  function writeLog(then) {
    if (!root.logPending) { if (then) then(); return }
    root.logPending = false
    var entry = Session.logEntry(root.rec, root.store.overview ? root.store.overview.calibration : null)
    wikiService.call("logSession", { entry: entry }, function(err) {
      if (then) { then(); return }
      if (err) { root.store.status = "session log: " + err; return }
      sync.run(function(r) { if (r.note !== "") root.toastRequested(r.note) })
    })
  }
}
