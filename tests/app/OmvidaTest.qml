import QtQuick
import QtTest
import Quickshell
import Quickshell.Io

// The base type of every whole-app test (tests/app/tst_*.qml), Omvision's
// OmvisionTest adapted. A test file is loaded *inside the running app* by
// omvida.qml's test hook (OMVIDA_TEST=<file>), so it clicks and types into
// the real screens, against real backends: the deck server on the fixture
// deck, the wiki service on the fixture wiki. bin/test runs each file in its
// own sandbox (bin/sandbox), with fake claude, kitty and qmd first on PATH.
//
// What a test file gets:
//   app, study, wiki, cardsScreen, searchPalette, target, window   set by the hook
//   click(name), item(name)       by objectName, waiting for it
//   type(text), key(k, mods)      real key events to the focused item
//   run(argv)                     { code, out }
//   readFile(path), sandbox       files in the sandbox
//   sql(query)                    rows from the fixture deck, as arrays
//   kittyCalls(), claudeCalls()   what the fake kitty and claude were run with
//   waitReady()                   both backends up and the data loaded
//   startSession()                Study, a session started, a card up
// plus everything TestCase has.
//
// Results go to stdout one line per test (PASS / FAIL / XFAIL / SKIP), then
// DONE, for bin/test to read. The qtest_results stand-in is Omvision's: Qt's
// TestResult logs through a C++ logger only qmltestrunner sets up.
TestCase {
  id: base
  when: false

  property var app: null
  property var study: null
  property var wiki: null
  property var cardsScreen: null
  property var searchPalette: null
  property Item target: null
  property var window: null
  property int timeout: 10000

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string sandbox: Quickshell.env("OMVIDA_SANDBOX") || ""
  readonly property string outDir: Quickshell.env("OMVIDA_TEST_OUT") || ""
  readonly property string studyDir: Quickshell.env("OMVIDA_STUDY_DIR") || ""
  readonly property string deckDb: Quickshell.env("FLASHCARD_DB") || ""
  readonly property string only: Quickshell.env("OMVIDA_TEST_ONLY") || ""
  readonly property string fileName: String(base.name || "test")

  // Runs inside the hook's onLoaded, before the event loop turns: no
  // processes (run(), sql()) here, they need wait(). Do setup in the test.
  function started() {}
  onAppChanged: if (app) { try { base.started() } catch (e) { console.warn(e) } startTimer.start() }

  Rectangle { anchors.fill: parent; color: base.window ? base.window.color : "white" }
  Timer { id: startTimer; interval: 0; onTriggered: base.runAll() }

  qtest_results: results
  TestResult { id: realResults }

  QtObject {
    id: results
    property var failures: []
    property var xfails: []
    property string skipMessage: ""
    property string pendingXfail: ""
    property bool pendingXfailAborts: false
    property bool failed: failures.length > 0
    property bool skipped: skipMessage !== ""

    function begin() { failures = []; xfails = []; skipMessage = ""; pendingXfail = ""; pendingXfailAborts = false }
    function where(file, line) { return file ? " (" + String(file).replace(/^.*\//, "") + ":" + line + ")" : "" }
    function outcome(ok, detail) {
      if (pendingXfail !== "") {
        var why = pendingXfail, aborts = pendingXfailAborts
        pendingXfail = ""
        if (ok) { failures = failures.concat(["XPASS (expected to fail: " + why + "): " + detail]); return true }
        xfails = xfails.concat([why])
        return !aborts
      }
      if (!ok) failures = failures.concat([detail])
      return ok
    }
    function fail(msg, file, line) { outcome(false, (msg || "fail()") + where(file, line)) }
    function verify(cond, msg, file, line) { return outcome(!!cond, "verify failed" + (msg ? ": " + msg : "") + where(file, line)) }
    function compare(ok, msg, act, exp, file, line) { return outcome(ok, (msg ? msg + ": " : "") + "got " + act + ", expected " + exp + where(file, line)) }
    function fuzzyCompare(a, b, delta) { return Math.abs(a - b) <= delta }
    function skip(msg) { skipMessage = msg || "skipped" }
    function expectFail(tag, msg) { pendingXfail = msg || "expected failure"; pendingXfailAborts = true; return true }
    function expectFailContinue(tag, msg) { pendingXfail = msg || "expected failure"; pendingXfailAborts = false; return true }
    function warn(msg) { console.warn(base.fileName + ": " + msg) }
    function ignoreWarning(msg) {}
    function failOnWarning(msg) {}
    function stringify(v) {
      if (v === undefined) return "undefined"
      if (v === null) return "null"
      if (typeof v === "string") return JSON.stringify(v)
      if (typeof v === "object") { try { return JSON.stringify(v) } catch (e) { return String(v) } }
      return String(v)
    }
    function wait(ms) { realResults.wait(ms) }
    function sleep(ms) { realResults.sleep(ms) }
    function waitForRendering(item, timeout) { realResults.wait(50); return true }
    function isPolishScheduled(item) { return realResults.isPolishScheduled(item) }
    function waitForPolish(item, timeout) { return realResults.waitForPolish(item, timeout) }
  }

  function testFunctions() {
    var names = []
    for (var p in base) if (p.indexOf("test_") === 0 && typeof base[p] === "function") names.push(p)
    names.sort()
    if (base.only !== "") names = names.filter(function(n) { return n === base.only })
    return names
  }

  function say(line) { console.info("[omvida-test] " + line) }

  function runAll() {
    var counts = { pass: 0, fail: 0, xfail: 0, skip: 0 }
    if (!safeHome()) {
      say("FAIL " + base.fileName + "::setup: refusing to run: HOME (" + base.home + ") is not a sandbox made by bin/sandbox")
      say("DONE " + base.fileName + " 0 passed, 1 failed, 0 xfail, 0 skipped")
      Qt.exit(2)
      return
    }
    var names = testFunctions()
    for (var i = 0; i < names.length; i++) counts[runOne(names[i])]++
    say("DONE " + base.fileName + " " + counts.pass + " passed, " + counts.fail + " failed, " + counts.xfail + " xfail, " + counts.skip + " skipped")
    Qt.exit(counts.fail > 0 || names.length === 0 ? 1 : 0)
  }

  function runStep(fn) {
    try { fn() } catch (e) {
      var m = String(e && e.message !== undefined ? e.message : e)
      if (m.indexOf("QtQuickTest::") !== 0)
        results.failures = results.failures.concat(["uncaught exception: " + m
          + (e && e.fileName ? " (" + String(e.fileName).replace(/^.*\//, "") + ":" + e.lineNumber + ")" : "")])
    }
  }

  function runOne(name) {
    results.begin()
    var label = base.fileName + "::" + name
    runStep(function() { base.waitReady() })
    if (!results.failed) runStep(function() { base.init() })
    if (!results.failed && !results.skipped) runStep(function() { base[name]() })
    runStep(function() { base.cleanup() })
    if (results.failed) { say("FAIL " + label + ": " + results.failures.join(" | ")); screenshot(name); return "fail" }
    if (results.skipped) { say("SKIP " + label + ": " + results.skipMessage); return "skip" }
    if (results.xfails.length > 0) { say("XFAIL " + label + ": " + results.xfails.join(" | ")); return "xfail" }
    say("PASS " + label)
    return "pass"
  }

  function screenshot(name) {
    if (!base.target) return
    var path = base.outDir + "/" + base.fileName + "-" + name + ".png"
    var done = false
    base.target.grabToImage(function(result) { if (result.saveToFile(path)) say("SHOT " + path); done = true })
    for (var t = 0; t < 3000 && !done; t += 50) wait(50)
  }

  // ---- processes and files ------------------------------------------------------
  Component {
    id: processComponent
    Process {
      id: proc
      property bool finished: false
      property int code: -1
      property string out: ""
      property bool streamDone: false
      stdout: StdioCollector { onStreamFinished: { proc.out = text; proc.streamDone = true } }
      onExited: function(exitCode) { proc.code = exitCode; proc.finished = true }
    }
  }

  function run(argv, ms) {
    var p = processComponent.createObject(base, { command: argv })
    p.running = true
    var limit = ms || 10000
    for (var t = 0; t < limit && !p.finished; t += 10) wait(10)
    for (var s = 0; s < 500 && !p.streamDone; s += 10) wait(10)
    var r = { code: p.finished ? p.code : -1, out: p.out }
    p.destroy()
    return r
  }

  function safeHome() {
    if (base.home === "" || base.sandbox === "") return false
    return run(["/usr/bin/test", "-f", base.home + "/.omvida-test-home"]).code === 0
  }

  function readFile(path) {
    var r = run(["/usr/bin/cat", "--", path])
    return r.code === 0 ? r.out : null
  }

  // Rows from the fixture deck, read-only.
  function sql(query) {
    var r = run(["python3", "-c",
      "import json,sqlite3,sys; c=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True); print(json.dumps(c.execute(sys.argv[2]).fetchall()))",
      base.deckDb, query])
    if (r.code !== 0) { qtest_fail("sql failed: " + query, 1); return [] }
    return JSON.parse(r.out)
  }

  // A change to the fixture deck before the app reads it (a test's started()).
  function sqlWrite(statement) {
    var r = run(["python3", "-c",
      "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.execute(sys.argv[2]); c.commit()", base.deckDb, statement])
    if (r.code !== 0) qtest_fail("sql write failed: " + statement, 1)
  }

  function jsonLines(path) {
    var t = readFile(path)
    if (!t) return []
    return t.split("\n").filter(function(l) { return l !== "" }).map(function(l) { return JSON.parse(l) })
  }
  function kittyCalls() { return jsonLines(base.outDir + "/kitty-calls.jsonl") }
  function claudeCalls() { return jsonLines(base.outDir + "/claude-calls.jsonl") }
  function gradeCalls() { return claudeCalls().filter(function(a) { return a.indexOf("--json-schema") !== -1 }) }

  // ---- the app ----------------------------------------------------------------------------
  function waitReady() {
    tryVerify(function() { return base.app.store.wikiIndex !== null && base.app.store.overview !== null && base.app.store.cardsLoaded },
              20000, "backends never came up (deck: " + (base.app.store.overview !== null) + ", wiki: " + (base.app.store.wikiIndex !== null) + ")")
  }

  function startSession() {
    base.app.setScreen("study")
    base.study.start()
    tryCompare(base.study, "phase", "answering", 15000)
    // The answer box takes the keyboard a moment after the phase changes
    // (StudyScreen focuses it with Qt.callLater); a key typed before that
    // went to the screen, and the test lost its first letter.
    var field = item("answerField")
    tryVerify(function() { return field.activeFocus }, base.timeout, "the answer box has the keyboard")
  }

  // ---- finding and clicking -----------------------------------------------------------------
  function effectiveOpacity(it) { var o = 1; for (var p = it; p; p = p.parent) o *= p.opacity; return o }

  function findNamed(root, name) {
    if (!root) return null
    if (root.objectName === name && root.visible) return root
    var kids = root.children
    for (var i = 0; kids && i < kids.length; i++) { var r = findNamed(kids[i], name); if (r) return r }
    return null
  }

  function item(name, ms) {
    var found = null
    tryVerify(function() { found = findNamed(base.target, name); return found !== null }, ms || base.timeout, "no visible item named " + name)
    return found
  }

  function settle(it) {
    var last = null
    for (var t = 0; t < 2000; t += 50) {
      var p = it.mapToItem(base.target, 0, 0)
      var here = p.x + "," + p.y + "," + it.width + "," + it.height
      if (here === last) return
      last = here
      wait(50)
    }
  }

  function click(name, ms) {
    var it = item(name, ms)
    settle(it)
    var x = it.width / 2, y = it.height / 2
    mouseMove(it, x, y)
    tryVerify(function() { return it.visible && it.enabled && base.effectiveOpacity(it) > 0 }, ms || base.timeout, name + " never became clickable")
    mouseClick(it, x, y)
    return it
  }

  function type(text) {
    for (var i = 0; i < text.length; i++) {
      var c = text.charAt(i)
      if (c === "\n") keyClick(Qt.Key_Return)
      else keyClick(c)
    }
  }

  function key(k, modifiers) { keyClick(k, modifiers === undefined ? Qt.NoModifier : modifiers) }
}
