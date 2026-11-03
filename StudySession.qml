import QtQuick

import "StudyKeys.js" as StudyKeys
import "Launch.js" as Launch
import "Session.js" as Session

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
// The answer is graded once, on the reveal, and on what was typed by then. A
// grade bills an API call (flashcard-mcp's grading.ts), so nothing is graded
// ahead. Until 2026-10-30, when grades ran on `claude -p` under the Claude
// subscription, every pause in the typing graded the answer so far, to have
// the verdict in by the reveal; that cost a grade per pause, mostly thrown
// away, to hide a three-second wait the API's 1.5-2.5s no longer needs.
// The deck server makes the call: nextCard aborts the last card's grade, so
// a rating given without Claude's leaves none running.
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
  property var rec: Session.empty()
  property double shownAt: 0
  property double revealedAt: 0
  // How long the answer took: from the card shown to the reveal. Kept apart
  // from those two, since a card back from an undo is shown anew (its intervals
  // are counted from then) and keeps the time it took the first time.
  property double responseMs: 0
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
  // Nothing on its way: what the session shows now is what the deck has.
  readonly property bool atRest: phase === "answering" || phase === "grading" || phase === "revealed" || phase === "blocked" || phase === "done"

  // ---- undo and redo: the state --------------------------------------------------
  // The session's ratings, oldest first, each with what its card showed when it
  // was given: { cardId, rating, answer, suggestion, gradeError, responseMs, leeches }
  // (leeches: the record's leech lines by then, Session.unrated). What a rating
  // changed in the deck is the deck server's to put back (undoReview); these
  // bring the view back, so an undo asks the grader nothing and bills nothing.
  property var rated: []
  // The ratings undone, the next to redo last. The top one's card is shown again
  // revealed (showNext), and rating it the same way is the redo (submit).
  property var undone: []
  // Undo and redo pressed while a card was on its way, in order (moveLater).
  property var moves: []
  // Once the log entry is written, or Anki synced after it, the ratings are out
  // of this session's hands. That is the summary leaving the screen.
  readonly property bool canUndo: rated.length > 0 && (phase === "done" ? logPending : sessionId !== "")
  readonly property bool canRedo: undone.length > 0 && inCard && card !== null && undone[undone.length - 1].cardId === card.id

  // What it asks of the window (App.qml wires each).
  signal toastRequested(string text)
  // Claude Code in kitty (Launch.js has every argv), with a toast.
  signal launchRequested(var argv, string note)
  // The note dialog on `card`.
  signal noteAsked(var card)
  // The delete confirm for `card`; its accept calls deleteCard(card).
  signal deleteAsked(var card)
  // Ctrl+Q: check `card`'s quality in the background (CardCheck.qml).
  signal cardCheckRequested(var card)

  // The view empties the answer box: a new card is on its way.
  signal answerReset()
  // An undo brought a card back: the answer box shows what was typed on it, and
  // takes the keyboard, which the summary's or a leech's screen may hold.
  signal answerRestored(string text)
  // Alt+?: the view shows the list of keys (KeyHelp.qml).
  signal keysWanted()

  property AnkiSync sync: AnkiSync {}

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
    root.rated = []
    root.undone = []
    root.moves = []
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
    root.responseMs = 0
    root.rec = Session.shown(root.rec, root.shownAt)
    var u = root.undone[root.undone.length - 1]
    if (u && u.cardId === res.card.id) {
      root.showAsRated(u)
      return
    }
    root.revealedAt = 0
    root.phase = "answering"
  }

  // A card whose rating was undone comes back as it was rated: revealed, its
  // answer and Claude's verdict in place, its rating picked. Back on the front
  // instead, as Anki does, the answer would be gone and the reveal would bill
  // another grade, for the sake of fixing a slipped key. A repeat Shift+digit or
  // Shift+Enter gives the same rating, another digit changes it.
  function showAsRated(u) {
    root.revealedAt = root.shownAt
    root.responseMs = u.responseMs
    root.suggestion = u.suggestion
    root.gradeError = u.gradeError
    root.picked = u.rating
    root.answerRestored(u.answer)
    root.phase = "revealed"
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

  // A grade still running is no longer wanted: gradeSeq drops its reply.
  function forgetGrade() {
    root.gradeSeq++
  }

  function fail(msg) {
    root.moves = []
    root.errorText = String(msg)
    root.phase = "error"
  }

  // ---- one card -------------------------------------------------------------------
  function reveal(thenAccept) {
    if (root.phase !== "answering") return
    root.revealedAt = Date.now()
    root.responseMs = root.revealedAt - root.shownAt
    if (root.answer.trim() === "") {
      root.phase = "revealed"
      return
    }
    root.phase = "grading"
    root.acceptPending = !!thenAccept
    // Graded as typed: the trim above only decides whether there is an
    // answer. gradeSeq drops the reply of a grade no longer wanted, and the
    // phase one that comes after the session failed.
    var seq = ++root.gradeSeq
    deck.call("grade", { cardId: root.card.id, answer: root.answer }, function(err, res) {
      if (seq !== root.gradeSeq || root.phase !== "grading") return
      root.takeGrade(err, res)
    })
  }

  function takeGrade(err, res) {
    if (err) {
      root.gradeError = err
      root.acceptPending = false
    } else {
      root.suggestion = res
    }
    root.phase = "revealed"
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
    var responseMs = root.responseMs || Date.now() - root.shownAt
    var seq = root.cardSeq
    var given = { cardId: c.id, rating: rating, answer: root.answer, suggestion: root.suggestion,
                  gradeError: root.gradeError, responseMs: responseMs, leeches: 0 }
    // The rating undone given again is the redo, and the ones after it can
    // follow. Any other rating is a new history, as in an editor.
    var top = root.undone[root.undone.length - 1]
    root.undone = top && top.cardId === c.id && top.rating === rating ? root.undone.slice(0, -1) : []
    root.forgetGrade()
    root.chosen = rating
    root.phase = "submitting"
    settleTimer.restart()
    deck.call("review", { sessionId: root.sessionId, cardId: c.id, rating: rating, responseMs: responseMs }, function(err) {
      if (err) { root.fail(err); return }
      given.leeches = root.rec.leeches.length
      root.rated = root.rated.concat([given])
      root.rec = Session.rated(root.rec, c, rating, suggested, repeat, Date.now())
      if (seq !== root.cardSeq || root.phase !== "submitting") return
      deck.call("nextCard", { sessionId: root.sessionId }, function(err, res) {
        root.held = { seq: seq, err: err, res: res }
        root.showHeld()
      })
    })
  }

  // ---- undo and redo ------------------------------------------------------------
  // Ctrl+Z takes the last rating back, as often as there are ratings; Ctrl+Shift+Z
  // gives them back. The deck server undoes the review, position included, so
  // nextCard serves that card again, and showNext shows it as it was rated. Redo
  // needs nothing of its own: it is that rating submitted again.
  //
  // From the summary it reopens the session, until the log entry is written:
  // the slip most likely to be noticed is on the last card, and the summary is
  // what follows it. finish() closes it again and writes the entry anew.
  function undo() {
    if (root.moveLater("undo")) return
    if (!root.canUndo) { root.toastRequested("Nothing to undo"); return }
    var ended = root.phase === "done"
    if (ended) {
      // First: leaving the summary writes the log entry (StudyScreen).
      root.logPending = false
      root.related = []
      root.sessionId = root.endedId
      root.endedId = ""
    }
    root.clearCard()
    deck.call("undoReview", { sessionId: root.sessionId }, function(err, res) {
      if (err) { root.fail(err); return }
      if (root.phase !== "loading") return
      root.takeBack(res)
      if (res) {
        deck.call("nextCard", { sessionId: root.sessionId }, root.showNext)
        return
      }
      // The deck server has nothing to undo: it restarted since, so the ratings
      // stand. Back to where this was.
      root.toastRequested("Nothing to undo")
      if (ended) root.finish()
      else root.loadNext()
    })
  }

  // The rating the server undid moves over to the redos. Ratings it passed over,
  // their cards deleted since, go for good. No answer from it: none of them can
  // be undone any more.
  function takeBack(res) {
    var left = root.rated.slice()
    var rec = root.rec
    while (res && left.length > 0) {
      let r = left.pop()
      rec = Session.unrated(rec, r.leeches)
      if (r.cardId !== res.cardId) continue
      root.undone = root.undone.concat([r])
      root.rated = left
      root.rec = rec
      return
    }
    root.rated = []
  }

  function redo() {
    if (root.moveLater("redo")) return
    if (!root.canRedo) { root.toastRequested("Nothing to redo"); return }
    root.submit(root.undone[root.undone.length - 1].rating)
  }

  // A card on its way: the press waits for it, so a quick Ctrl+Z, Ctrl+Z loses
  // neither, and a slip noticed the moment the key goes down needs no timing. The
  // settling a rating shows is cut short, since the card it leads to is not
  // wanted for long. True when the move was kept for later.
  function moveLater(move) {
    if (root.atRest) return false
    root.moves = root.moves.concat([move])
    if (root.phase === "submitting") {
      settleTimer.stop()
      root.showHeld()
    }
    return true
  }

  function nextMove() {
    if (!root.atRest || root.moves.length === 0) return
    var move = root.moves[0]
    root.moves = root.moves.slice(1)
    if (move === "undo") root.undo()
    else root.redo()
  }

  // On atRest's change, not the phase's: a handler on `phase` can run before the
  // binding on it has caught up, and read atRest stale. Then after that change
  // has run its course, not inside it: showNext is still setting the card up.
  property Timer moveTimer: Timer {
    interval: 0
    onTriggered: root.nextMove()
  }
  onAtRestChanged: if (root.atRest && root.moves.length > 0) moveTimer.restart()

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

  // Ctrl+Q: the card's quality checked, and the card fixed if it is flawed,
  // by Claude Code in the background (CardCheck.qml, which the window runs).
  // The session goes on meanwhile, and catches up if the card changes.
  function checkCard() {
    if (!root.card) return
    root.cardCheckRequested(root.card)
  }

  // Note the card for later (NoteDialog.qml), and go on studying: a fix
  // session takes every note at once (Launch.fixNotesArgv). The answer box
  // keeps what was typed; the window hands the keyboard back to it when the
  // dialog closes.
  function note() {
    if (!root.card) return
    root.noteAsked(root.card)
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
    case "check": root.checkCard(); break
    case "delete": root.askDelete(); break
    case "undo": root.undo(); break
    case "redo": root.redo(); break
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
