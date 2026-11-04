pragma ComponentBehavior: Bound
import QtQuick

import "Exercise.js" as Exercise

// One try at a code card (flashcard-mcp's exercises.ts, after Execute Program):
// what is typed in its blanks, the last result of running it, and the three ways
// the card ends up: a pass, a give-up, or neither yet. A logic object, as
// Navigator is: it holds no phases and no window. The session hands it the card
// and whether that card is being answered, and hears `settled` when the card is
// over; what that does to the phases (a second Shift+Enter writes the rating) is
// the session's, so undo, catching up and the log need nothing of code cards.
//
// It needs no reveal and no grade. It runs at each pause in the typing, a check
// is the same run with the animation (`checked`), and a pass waits for one more
// Shift+Enter, with no step of choosing a rating. What a pass rates, and that a
// wrong try costs nothing, are the deck server's: `rating` comes with the result.
//
// It was StudySession's own, about a hundred lines and fifteen properties among
// the phases, which every other card kind had to read past.
QtObject {
  id: root

  required property JsonLineClient deck
  required property JsonLineClient wikiService
  property var card: null
  // Nothing comes of a reply that arrives once the card is no longer being answered.
  property bool answering: false

  readonly property bool active: card !== null && !!card.exercise
  property var answers: []        // one string per blank or prediction
  property var result: null       // the last run's result, shown as it stands
  property var html: ({})         // the code, highlighted, by segment
  property string explain: ""
  property int checks: 0          // failed checks on this card
  property bool gaveUp: false
  property int rating: 0          // what a pass or a give-up rates, once moved on from
  property bool blockFocused: false // a multi-line blank has the keyboard
  property int seq: 0
  readonly property bool canGiveUp: active && answering && checks >= Config.codeGiveUpAfter
  // Whatever was typed, for what doesn't care which blank.
  readonly property string typed: answers.join("\n")

  signal checked(string status)
  signal answersSet()   // the answers changed other than by typing: the blanks show them
  signal settled()      // a pass or a give-up: the card is over, until Shift+Enter moves on
  signal toastRequested(string text)

  property Timer runTimer: Timer {
    interval: Config.codeRunDebounce
    onTriggered: root.runLive()
  }

  function reset() {
    root.seq++
    runTimer.stop()
    root.answers = []
    root.result = null
    root.html = ({})
    root.explain = ""
    root.checks = 0
    root.gaveUp = false
    root.rating = 0
    root.blockFocused = false
  }

  function setUp() {
    var ex = root.card.exercise
    root.answers = Exercise.startAnswers(ex.parts, ex.answers)
    root.answersSet()
    var id = root.card.id
    wikiService.call("highlight", { segments: Exercise.segments(ex.parts), lang: ex.lang }, function(err, html) {
      // Without it the code is plain, which is no reason to say anything.
      if (!err && root.card && root.card.id === id) root.html = html
    })
  }

  // What the undo of a rating needs to bring this card back as it was.
  function snapshot() {
    return { answers: root.answers, result: root.result, explain: root.explain, gaveUp: root.gaveUp }
  }

  function restore(saved) {
    root.result = saved.result
    root.explain = saved.explain
    root.answers = saved.answers
    root.gaveUp = saved.gaveUp
    root.answersSet()
  }

  function setAnswer(index, text) {
    if (!root.answering || root.answers[index] === text) return
    var next = root.answers.slice()
    next[index] = text
    root.answers = next
    // A prediction shows nothing until it is checked, or the code would answer
    // it. Otherwise the output follows the typing.
    if (root.card.exercise.kind !== "predict") runTimer.restart()
  }

  // A call about the card up, replacing the one before: its answer counts only
  // while it is the latest and the card is still being answered.
  function request(method, params, then) {
    runTimer.stop()
    var mine = ++root.seq
    deck.call(method, Object.assign({ cardId: root.card.id }, params), function(err, res) {
      if (mine !== root.seq || !root.answering) return
      if (err) { root.toastRequested(err); return }
      then(res)
    })
  }

  function settle(rating, explain) {
    root.rating = rating
    root.explain = explain
    root.settled()
  }

  function runLive() {
    if (!root.answering || !root.active) return
    request("runExercise", { answers: root.answers }, function(res) {
      // Half-filled says nothing, and leaves the last result where it is. Nor does
      // code that doesn't compile yet, which is most pauses in a line being typed:
      // a check is where that gets said. Two things do go, the code having changed
      // since: an error a check said, and a pass, which is no longer true.
      var early = Exercise.stoppedEarly(res)
      if (res.status === "incomplete" || early) {
        let shown = root.result
        if (shown && (shown.status === "pass" || (early && Exercise.stoppedEarly(shown)))) root.result = null
        return
      }
      root.result = res
    })
  }

  // A try, whatever comes of it. A wrong one and an error count only towards
  // being offered the way out.
  function check() {
    if (!root.answering || !root.active) return
    request("runExercise", { answers: root.answers }, function(res) {
      root.result = res
      if (res.status !== "pass") root.checks++
      root.checked(res.status)
      if (res.rating !== null) root.settle(res.rating, res.explain || "")
    })
  }

  // The solution, with the reason, up until the next key: reading it is the
  // point of having given up. Rated then, not now, as a card still on screen
  // can be noted or discussed first.
  function giveUp() {
    if (!root.canGiveUp) return
    request("revealExercise", {}, function(res) {
      root.gaveUp = true
      root.result = res.result
      root.answers = res.answers
      root.answersSet()
      root.settle(res.rating, res.explain)
    })
  }
}
