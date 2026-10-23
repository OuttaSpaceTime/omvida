pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

import "Launch.js" as Launch

// One Ask: a question to `claude -p` in the study repo under the Query
// Protocol (Launch.askArgv), its answer streamed in, apart from the palette
// that shows it, as StudySession is apart from the Study screen.
//
// Each question gets a claude process of its own, and only the current one
// is listened to. A stopped claude only ends when it gets to it, and one
// process shared by every question let the last one's exit finish the next
// with nothing in it; a flag to wait for that exit was the other way, with a
// check in every handler and the new question held up meanwhile.
QtObject {
  id: root

  required property Store store

  property string question: ""
  property string text: ""
  property string status: ""
  property string sessionId: ""   // claude's, for "Continue in Claude"
  property bool done: false
  property string error: ""
  property var blocks: null       // the finished answer, rendered like a page
  property var proc: null         // the current question's claude

  function start(q) {
    root.stop()
    root.question = q
    root.text = ""
    root.status = "thinking"
    root.sessionId = ""
    root.done = false
    root.error = ""
    root.blocks = null
    root.proc = askProcess.createObject(root, { command: Launch.askArgv(q) })
    root.proc.running = true
  }

  function stop() { if (root.proc) root.proc.running = false }

  // While it streams the answer is shown as markdown; once complete it goes
  // through the wiki service's renderer, so its [[links]] resolve the way a
  // page's do and it takes the theme's colours.
  function finish() {
    if (root.done) return
    root.done = true
    root.status = ""
    if (root.text === "") return
    root.store.wiki.call("markdown", { text: root.text }, function(err, res) { if (!err) root.blocks = res.blocks })
  }

  property Component askProcess: Component {
    Process {
      id: p
      workingDirectory: Paths.studyDir
      stdout: SplitParser {
        onRead: function(line) {
          if (p !== root.proc) return
          var ev = Launch.parseAskLine(line)
          if (ev.sessionId) root.sessionId = ev.sessionId
          if (ev.blockStart && root.text !== "" && !/\n\n$/.test(root.text)) root.text += "\n\n"
          if (ev.text) { root.text += ev.text; root.status = "" }
          if (ev.tool) root.status = Launch.toolLabel(ev.tool)
          if (ev.done) { root.finish(); if (ev.error) root.error = ev.error }
        }
      }
      stderr: SplitParser { onRead: function(line) { if (p === root.proc && line.trim() !== "") root.error = line } }
      onExited: function(code) {
        if (p === root.proc) {
          root.finish()
          if (code !== 0 && root.error === "") root.error = "claude exited " + code
          root.proc = null
        }
        p.destroy()
      }
    }
  }
}
