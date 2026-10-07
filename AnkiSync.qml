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

  // cb({ ran, moved, note })
  function run(cb) {
    if (proc.running) { if (cb) cb({ ran: false, moved: false, note: "" }); return }
    root.callback = cb || null
    root.output = ""
    proc.running = true
  }

  // A missing script (a machine without the sync set up, the tests' fixture)
  // exits 99 and counts as skipped, not failed.
  Process {
    id: proc
    command: ["sh", "-c", "[ -x \"$1\" ] || exit 99; exec \"$1\" sync", "sh", Paths.ankiSync]
    stdout: StdioCollector { onStreamFinished: root.output = text }
    stderr: StdioCollector {}
    onExited: function(code) {
      var cb = root.callback
      root.callback = null
      if (!cb) return
      if (code === 99) { cb({ ran: false, moved: false, note: "" }); return }
      var lines = String(root.output).trim().split("\n").filter(function(l) { return l !== "" })
      var last = lines.length ? lines[lines.length - 1] : ""
      var m = /^sync: done \((.*)\)$/.exec(last)
      if (code === 0 && m) cb({ ran: true, moved: m[1] !== "nothing to do", note: m[1] === "nothing to do" ? "" : "Anki sync: " + m[1] })
      else cb({ ran: true, moved: false, note: "Anki sync failed: " + (last || ("exit " + code)) })
    }
  }

  // Sync must never hold a session hostage.
  Timer {
    interval: 45000
    running: proc.running
    onTriggered: { proc.running = false }
  }
}
