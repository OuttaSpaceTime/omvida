import QtQuick

import "StudyKeys.js" as StudyKeys
import "Format.js" as Format
import "Launch.js" as Launch
import "Session.js" as Session

// A study session: the /study skill's loop, as state and actions with no view.
// StudyScreen draws it; omvida.qml owns it, beside the deck and wiki clients,
// so the tests drive it directly and the window can ask it for the current
// card or a pending log entry.
//
//   front shown, answer typed (or not)  ->  reveal: the back, and Claude's
//                                            suggested rating with its reason
//   then: submit the suggestion, Good, or any rating
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

  property var app: null
  property var deck: null
  property var wikiService: null
  // The answer as typed, bound from the view's answer box.
  property string answer: ""

  // idle | syncing | starting | loading | answering | grading | revealed |
  // submitting | blocked | done | error
  property string phase: "idle"
  property string sessionId: ""
  property var info: null        // startSession's result
  property var next: null        // nextCard's result
  readonly property var card: next && next.card ? next.card : null
  property var suggestion: null
  property string gradeError: ""
  property bool acceptPending: false
  property int gradeSeq: 0
  property var rec: Session.empty()
  property var lastResult: null  // { front, rating, line, overridden }
  property double shownAt: 0
  property double revealedAt: 0
  property var blocked: null     // { card, lapses }
  readonly property var summaryData: phase === "done" ? Session.summary(rec) : null
  property var related: []
  property bool logPending: false
  property string errorText: ""
  property string syncNote: ""

  readonly property bool inCard: phase === "answering" || phase === "grading" || phase === "revealed" || phase === "submitting"
  // The back is on screen: grading, revealed, and a rating on its way after
  // a reveal. A rating given straight from the answer (Shift+1-4) keeps the
  // answering layout until the next card.
  readonly property bool backShown: phase === "grading" || phase === "revealed" || (phase === "submitting" && revealedAt > 0)

  // The view empties the answer box: a new card is on its way.
  signal answerReset()

  property AnkiSync sync: AnkiSync {}

  // ---- the session ----------------------------------------------------------------
  function startIfIdle() {
    if (phase === "idle" || phase === "done" || phase === "error") start()
  }

  function start() {
    root.phase = "syncing"   // first: leaving the summary writes its log entry
    root.rec = Session.empty()
    root.lastResult = null
    root.related = []
    root.syncNote = ""
    sync.run(function(r) {
      if (r.note !== "") root.syncNote = r.note
      if (r.moved) root.app.store.refreshDeck()
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
      root.info = res
      root.loadNext()
    })
  }

  function loadNext() {
    root.phase = "loading"
    root.suggestion = null
    root.gradeError = ""
    root.acceptPending = false
    root.gradeSeq++
    root.answerReset()
    deck.call("nextCard", { sessionId: root.sessionId }, function(err, res) {
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
    })
  }

  function fail(msg) {
    root.errorText = String(msg)
    root.phase = "error"
  }

  // ---- one card -------------------------------------------------------------------
  function reveal(thenAccept) {
    if (root.phase !== "answering") return
    root.revealedAt = Date.now()
    var text = root.answer
    if (text.trim() === "") {
      root.phase = "revealed"
      return
    }
    root.phase = "grading"
    root.acceptPending = !!thenAccept
    var seq = ++root.gradeSeq
    var cardId = root.card.id
    deck.call("grade", { cardId: cardId, answer: text }, function(err, res) {
      if (seq !== root.gradeSeq || !root.card || root.card.id !== cardId) return
      if (err) {
        root.gradeError = err
        root.acceptPending = false
      } else {
        root.suggestion = res
      }
      if (root.phase === "grading") root.phase = "revealed"
      if (root.acceptPending && root.suggestion) root.submit(root.suggestion.rating)
    })
  }

  function submit(rating) {
    if (!root.card || root.phase === "submitting") return
    var c = root.card
    var repeat = root.next.repeat
    var suggested = root.suggestion ? root.suggestion.rating : 0
    var responseMs = (root.revealedAt || Date.now()) - root.shownAt
    root.gradeSeq++   // a grade still running for this card is no longer wanted
    root.phase = "submitting"
    deck.call("review", { sessionId: root.sessionId, cardId: c.id, rating: rating, responseMs: responseMs }, function(err, sched) {
      if (err) { root.fail(err); return }
      root.rec = Session.rated(root.rec, c, rating, suggested, repeat, Date.now())
      root.lastResult = { front: Format.stripHtml(c.front), rating: rating, line: Format.scheduleLine(rating, sched),
                          overridden: suggested !== 0 && suggested !== rating }
      root.loadNext()
    })
  }

  function skip() {
    if (!root.inCard) return
    deck.call("skip", { sessionId: root.sessionId }, function() { root.loadNext() })
  }

  function discuss() {
    if (!root.card) return
    root.app.launch(Launch.discussArgv(Paths.studyDir, root.card, root.answer, root.suggestion),
                    "Discussing in Claude Code. Rate the card when you're back.")
  }

  function fixCard() {
    if (!root.card || !root.suggestion || !root.suggestion.quality) return
    root.app.launch(Launch.fixCardArgv(Paths.studyDir, root.card, root.suggestion.quality), "Opened Claude Code to fix the card")
  }

  // A key from the answer box (or, with no card up, the screen): true when
  // it was a study key, which the box then doesn't type.
  function handleKey(event) {
    var a = StudyKeys.action({ phase: root.phase, hasSuggestion: !!root.suggestion, answerEmpty: root.answer.trim() === "" },
                             event.key, event.modifiers, event.nativeScanCode)
    if (!a) return false
    switch (a.action) {
    case "reveal": root.reveal(false); break
    case "revealAccept": root.reveal(true); break
    case "accept": root.submit(root.suggestion.rating); break
    case "acceptLater": root.acceptPending = true; break
    case "submit": root.submit(a.rating); break
    case "discuss": root.discuss(); break
    case "skip": root.skip(); break
    case "end": root.endNow(); break
    case "start": root.start(); break
    case "continue": root.loadNext(); break
    }
    return true
  }

  // ---- leeches ------------------------------------------------------------------------
  function leechFix(how) {
    root.app.launch(Launch.leechArgv(Paths.studyDir, root.blocked.card, root.blocked.lapses, how),
                    "Fix it in Claude Code, then press Continue")
    root.rec = Session.leech(root.rec, root.blocked.card, root.blocked.lapses, how === "split" ? "split in Claude Code" : "rewritten in Claude Code")
  }

  // Keep the card as is (resolveLeech) or drop it (deleteCard), then go on.
  function leechResolve(method, note) {
    var b = root.blocked
    deck.call(method, { cardId: b.card.id }, function(err) {
      if (err) { root.fail(err); return }
      root.rec = Session.leech(root.rec, b.card, b.lapses, note)
      root.loadNext()
    })
  }

  // ---- the end ------------------------------------------------------------------------
  function finish() {
    root.phase = "done"
    root.next = null
    var sid = root.sessionId
    if (sid !== "") deck.call("endSession", { sessionId: sid }, function() {})
    root.sessionId = ""
    if (root.rec.reviews.length === 0) return
    root.logPending = true
    wikiService.call("related", { studied: Session.studiedCards(root.rec), limit: 3 }, function(err, pages) {
      if (!err) root.related = pages
    })
    root.app.store.refreshDeck()
  }

  // End early: what was reviewed still counts, and the session is closed.
  function endNow() {
    if (root.phase === "idle" || root.phase === "done") return
    root.gradeSeq++
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
    var entry = Session.logEntry(root.rec, root.app.store.overview ? root.app.store.overview.calibration : null)
    wikiService.call("logSession", { entry: entry }, function(err) {
      if (then) { then(); return }
      if (err) { root.app.store.status = "session log: " + err; return }
      sync.run(function(r) { if (r.note !== "") root.app.toast(r.note) })
    })
  }
}
