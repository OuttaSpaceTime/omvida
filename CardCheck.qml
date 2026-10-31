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
// the skill's one-line result comes back as a toast. So a check dies with the
// app, possibly halfway through a split; quitting waits for running checks
// (App.qml, Config.cardCheckQuitDeadline). At most Config.cardCheckLimit run
// at once, one per card: each is a Sonnet session, and every write it makes
// runs the gate's judge too, so a run of Ctrl+Q's would hit the
// subscription's rate limit, and the gate fails closed.
QtObject {
  id: root

  // The ids of the cards being checked.
  property var running: ({})
  readonly property int count: Object.keys(running).length

  // What happened, for the window to toast: the skill's last line, or why it failed.
  signal finished(var card, string text, bool ok)

  // "started", or why not: "checking" (that card already is) or "busy"
  // (Config.cardCheckLimit checks are running).
  function run(card) {
    if (root.running[card.id]) return "checking"
    if (root.count >= Config.cardCheckLimit) return "busy"
    var p = checkProcess.createObject(root, { card: card, command: Launch.cardCheckArgv(card.id) }) as Process
    var r = Object.assign({}, root.running)
    r[card.id] = true
    root.running = r
    p.running = true
    return "started"
  }

  function done(p, text, ok) {
    var r = Object.assign({}, root.running)
    delete r[p.card.id]
    root.running = r
    root.finished(p.card, text, ok)
    p.destroy()
  }

  property Component checkProcess: Component {
    Process {
      id: p
      property var card
      property string out: ""
      property string err: ""
      property bool didStart: false
      workingDirectory: Paths.studyDir
      stdout: SplitParser { onRead: function(line) { p.out += line + "\n" } }
      stderr: SplitParser { onRead: function(line) { if (line.trim() !== "") p.err = line } }
      onStarted: p.didStart = true
      onExited: function(code) {
        var r = Launch.parseCardCheck(p.out)
        root.done(p, r.ok ? r.text : (r.text || p.err || "claude exited " + code), r.ok)
      }
      // A claude that never started (not on the PATH) sends no exited, and
      // would leave its card marked as being checked for good.
      onRunningChanged: if (!running && !p.didStart) root.done(p, "claude could not be started", false)
    }
  }
}
