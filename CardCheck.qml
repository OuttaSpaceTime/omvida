pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

import "Launch.js" as Launch

// Ctrl+Q's check: a card's quality judged, and the card fixed if it is
// flawed, by Claude Code headless in the study repo (the /study-card-check
// skill, Launch.cardCheckArgv), while the developer studies on. The skill
// owns the rules (references/card-quality.md) and writes through
// flashcard-mcp like every other card edit; the study repo's card-quality
// gate holds its writes too. The app learns of a change the usual way, by
// polling the deck, and a session showing the card catches up
// (StudySession.catchUp).
//
// It replaced the grader's per-review quality flag and its "fix in claude"
// button (2026-10-31): a flag asked the developer to stop and fix the card
// mid-review; this fixes it unattended, and only when asked.
//
// A Process rather than the detached launch kitty gets (App.launch), because
// the skill's verdict comes back to the window: what the card asked, what its
// back carried beyond that, and what became of it (Launch.parseCardCheck),
// which CheckSlot.qml shows until it is dismissed or discussed. It was a
// four-second toast until 2026-11-03: one line that was gone by the time the
// answer in hand was typed, about a card that may have just been split. So a check dies with the
// app, possibly halfway through a split; quitting waits for running checks
// (App.qml, Config.cardCheckQuitDeadline). At most Config.cardCheckLimit run
// at once, one per card: each is a Sonnet session, and every write it makes
// runs the gate's judge too, so a run of Ctrl+Q's would hit the
// subscription's rate limit, and the gate fails closed.
QtObject {
  id: root

  // What CheckSlot.qml shows, oldest first: { key, card, state, outcome, text,
  // asked, extra, cards }. state is "running", "done" or "failed"; the card is
  // as it was when the check began, since a split deletes it. A new list on
  // every change, so bindings on it notice.
  property var reports: []
  property int lastKey: 0
  readonly property int count: reports.filter(function(r) { return r.state === "running" }).length
  // The oldest finished report, the one the slot's keys act on, or null: a
  // check still running has nothing to dismiss or discuss.
  readonly property var settled: {
    var done = root.reports.filter(function(r) { return r.state !== "running" })
    return done.length ? done[0] : null
  }
  function dismiss(key) { root.reports = root.reports.filter(function(r) { return r.key !== key }) }

  // "started", or why not: "checking" (that card already is) or "busy"
  // (Config.cardCheckLimit checks are running).
  function run(card) {
    if (root.reports.some(function(r) { return r.state === "running" && r.card.id === card.id })) return "checking"
    if (root.count >= Config.cardCheckLimit) return "busy"
    root.lastKey += 1
    var p = checkProcess.createObject(root, { reportKey: root.lastKey, command: Launch.cardCheckArgv(card.id) }) as Process
    root.reports = root.reports.concat([{ key: root.lastKey, card: card, state: "running", outcome: "", text: "", asked: [], extra: [], cards: [] }])
    p.running = true
    return "started"
  }

  function done(p, result) {
    root.reports = root.reports.map(function(r) { return r.key === p.reportKey ? Object.assign({}, r, result) : r })
    p.destroy()
  }

  property Component checkProcess: Component {
    Process {
      id: p
      property int reportKey: 0
      property string out: ""
      property string err: ""
      property bool didStart: false
      workingDirectory: Paths.studyDir
      stdout: SplitParser { onRead: function(line) { p.out += line + "\n" } }
      stderr: SplitParser { onRead: function(line) { if (line.trim() !== "") p.err = line } }
      onStarted: p.didStart = true
      onExited: function(code) {
        var r = Launch.parseCardCheck(p.out)
        root.done(p, r.ok ? Object.assign({ state: "done" }, r)
                          : { state: "failed", text: r.text || p.err || "claude exited " + code })
      }
      // A claude that never started (not on the PATH) sends no exited, and
      // would leave its card marked as being checked for good.
      onRunningChanged: if (!running && !p.didStart) root.done(p, { state: "failed", text: "claude could not be started" })
    }
  }
}
