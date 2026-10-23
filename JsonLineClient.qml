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
// Nor when it hangs without exiting: a request unanswered for `timeout`
// (Config.requestTimeout) gets an error too, and its answer, should one
// come, is dropped. The clock starts when the line is written, not when it
// is queued, so a slow start (the wiki service builds its venv on first
// launch) costs no request its answer.
Item {
  id: root

  property string name: "backend"
  property var command: []

  property bool ready: false
  // The last line it wrote to stderr, and why it is down, for the status line.
  property string lastStderr: ""
  property string failure: ""

  property int timeout: Config.requestTimeout

  property int nextId: 1
  // id -> { cb, method, line, sentAt }: sentAt is 0 until the line is
  // written, which waits for the ready line. Integer keys keep their order,
  // so queued requests go out as they were made.
  property var pending: ({})
  property int restarts: 0

  // cb(error, result): error is null or a message string.
  function call(method, params, cb) {
    var id = root.nextId++
    root.pending[id] = { cb: cb, method: method, sentAt: 0,
                         line: JSON.stringify({ id: id, method: method, params: params || {} }) }
    if (root.ready) send(root.pending[id])
  }

  function send(p) {
    p.sentAt = Date.now()
    proc.write(p.line + "\n")
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
      for (let id in root.pending) if (root.pending[id].sentAt === 0) root.send(root.pending[id])
      return
    }
    // Answered once: a request already failed (timed out, or the backend
    // exited) is no longer pending, and its late answer is dropped.
    var p = root.pending[msg.id]
    if (p === undefined) return
    delete root.pending[msg.id]
    if (msg.error) p.cb(msg.error.message || "error", null)
    else p.cb(null, msg.result)
  }

  function failAll(reason) {
    var p = root.pending
    root.pending = ({})
    for (let id in p) p[id].cb(reason, null)
  }

  // The requests written longer than `timeout` ago get their error.
  function expire() {
    var now = Date.now()
    for (let id in root.pending) {
      let p = root.pending[id]
      if (p.sentAt === 0 || now - p.sentAt < root.timeout) continue
      delete root.pending[id]
      p.cb(root.name + ": no answer to " + p.method + " in " + (root.timeout / 1000) + "s", null)
    }
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

  // Checks for overdue requests, often enough that an error comes at most a
  // quarter of the timeout late. Over an empty `pending` it costs nothing.
  Timer {
    interval: Math.min(1000, root.timeout / 4)
    running: root.ready
    repeat: true
    onTriggered: root.expire()
  }

  // A run that stayed up a while has earned its restarts back.
  Timer {
    interval: 60000
    running: root.ready
    repeat: true
    onTriggered: root.restarts = 0
  }
}
