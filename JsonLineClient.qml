import QtQuick
import Quickshell.Io

// One long-lived backend process, spoken to in newline-delimited JSON:
// requests {id, method, params} on its stdin, responses {id, result|error}
// on its stdout, and one {"ready": true} line once it is up. Both backends
// speak it: the deck (flashcard-mcp's src/app/server.ts, via bin/omvida-deck)
// and the wiki (backend/omvida_backend/server.py, via bin/omvida-wiki).
//
// call() before the ready line is queued, not dropped, so screens can ask
// for data at startup without waiting on anything. A backend that exits is
// restarted after 1.5s, up to three times in a row: a
// crash during one request should not cost the rest of the session. Every
// call in flight when it exits gets an error, so no screen waits forever.
Item {
  id: root

  property string name: "backend"
  property var command: []

  property bool ready: false
  // The last line it wrote to stderr, and why it is down, for the status line.
  property string lastStderr: ""
  property string failure: ""

  property int nextId: 1
  property var pending: ({})
  property var queue: []
  property int restarts: 0

  // cb(error, result): error is null or a message string.
  function call(method, params, cb) {
    var id = root.nextId++
    var line = JSON.stringify({ id: id, method: method, params: params || {} })
    root.pending[id] = cb
    if (root.ready) proc.write(line + "\n")
    else root.queue.push(line)
  }

  function handleLine(line) {
    if (line === "") return
    var msg
    try { msg = JSON.parse(line) } catch (e) {
      console.warn(root.name + ": not JSON: " + line.slice(0, 200))
      return
    }
    if (msg.ready === true) {
      root.ready = true
      root.failure = ""
      var q = root.queue
      root.queue = []
      for (var i = 0; i < q.length; i++) proc.write(q[i] + "\n")
      return
    }
    var cb = root.pending[msg.id]
    delete root.pending[msg.id]
    if (cb === undefined) return
    if (msg.error) cb(msg.error.message || "error", null)
    else cb(null, msg.result)
  }

  function failAll(reason) {
    var p = root.pending
    root.pending = ({})
    root.queue = []
    for (var id in p) if (typeof p[id] === "function") p[id](reason, null)
  }

  Process {
    id: proc
    command: root.command
    running: root.command.length > 0
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(data) { root.handleLine(data) }
    }
    stderr: SplitParser {
      onRead: function(data) { if (data.trim() !== "") root.lastStderr = data }
    }
    onExited: function(code, status) {
      root.ready = false
      root.failAll(root.name + " stopped" + (root.lastStderr !== "" ? ": " + root.lastStderr : ""))
      if (root.restarts < 3) {
        root.restarts++
        restartTimer.start()
      } else {
        root.failure = root.name + " keeps stopping (exit " + code + ")" + (root.lastStderr !== "" ? ": " + root.lastStderr : "")
        console.warn(root.failure)
      }
    }
  }

  Timer {
    id: restartTimer
    interval: 1500
    onTriggered: proc.running = true
  }

  // A run that stayed up a while has earned its restarts back.
  Timer {
    interval: 60000
    running: root.ready
    repeat: true
    onTriggered: root.restarts = 0
  }
}
