import QtQuick
import Quickshell.Io

// scripts/anki-sync in the study repo: /study runs it before a session, so
// phone reviews land before anything is counted, and after the log, so the
// session's reviews reach the phone. Its output is one summary line. The app
// shows it only when something moved, and a failure (offline, not logged in)
// is a one-line note that never blocks studying (AGENTS.md, Anki Sync).
Item {
  id: root

  property var callback: null
  property string output: ""
  property string errors: ""

  // cb({ ran, moved, note })
  function run(cb) {
    if (proc.running) { if (cb) cb({ ran: false, moved: false, note: "" }); return }
    root.callback = cb || null
    root.output = ""
    root.errors = ""
    proc.running = true
  }

  function lastLine(text) {
    var lines = String(text).trim().split("\n").filter(function(l) { return l.trim() !== "" })
    return lines.length ? lines[lines.length - 1].trim() : ""
  }

  // A missing script (a machine without the sync set up, the tests' fixture)
  // exits 99 and counts as skipped, not failed.
  //
  // It runs in the study repo, as /study runs it. The script's shebang is
  // `uv run python3`, and outside the repo uv doesn't find its project and
  // starts a bare interpreter; the app started from ~ and the sync died on
  // `import fastanki` (the script now re-execs into its venv from anywhere,
  // but the repo is still where it belongs).
  Process {
    id: proc
    workingDirectory: Paths.studyDir
    command: ["sh", "-c", "[ -x \"$1\" ] || exit 99; exec \"$1\" sync", "sh", Paths.ankiSync]
    stdout: StdioCollector { onStreamFinished: root.output = text }
    stderr: StdioCollector { onStreamFinished: root.errors = text }
    onExited: function(code) {
      var cb = root.callback
      root.callback = null
      if (!cb) return
      if (code === 99) { cb({ ran: false, moved: false, note: "" }); return }
      var last = root.lastLine(root.output)
      var m = /^sync: done \((.*)\)$/.exec(last)
      if (code === 0 && m) { cb({ ran: true, moved: m[1] !== "nothing to do", note: m[1] === "nothing to do" ? "" : "Anki sync: " + m[1] }); return }
      // The script reports what it knows (not logged in) on stdout; a crash
      // is a traceback on stderr, whose last line is the exception. Prefer
      // that: after a crash stdout's last line is a plan that never ran.
      var why = root.lastLine(root.errors) || last || ("exit " + code)
      cb({ ran: true, moved: false, note: "Anki sync failed: " + why })
    }
  }

  // Sync must never hold a session hostage.
  Timer {
    interval: 45000
    running: proc.running
    onTriggered: { proc.running = false }
  }
}
