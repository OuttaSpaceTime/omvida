import QtQuick

// JsonLineClient.qml against a backend that misbehaves on request
// (tests/fixtures/echo-backend.py): queued calls, a request that never gets
// its answer, and a backend that exits mid-request. An app test, not a unit
// one: its Process is Quickshell's, which only exists inside qs.
OmvidaTest {
  id: suite
  name: "client"

  property var clients: []

  // A client of the echo backend, destroyed after the test.
  function client(extraArgs, timeoutMs) {
    var c = Qt.createComponent("file://" + repo + "/JsonLineClient.qml")
    verify(c.status === Component.Ready, c.errorString())
    var o = c.createObject(suite, { name: "echo", timeout: timeoutMs || 10000,
                                    command: ["python3", repo + "/tests/fixtures/echo-backend.py"].concat(extraArgs || []) })
    clients.push(o)
    return o
  }

  function cleanup() {
    clients.forEach(function(c) { c.destroy() })
    clients = []
  }

  // Calls back into `out`, so a test can wait on it.
  function recorder() {
    var out = { done: false, err: null, res: null }
    out.cb = function(err, res) { out.done = true; out.err = err; out.res = res }
    return out
  }

  function test_a_call_before_ready_is_queued_and_answered() {
    var c = client()
    var r = recorder()
    c.call("echo", { n: 1 }, r.cb)
    verify(!c.ready, "asked before the ready line")
    tryVerify(function() { return r.done }, 5000)
    compare(r.err, null)
    compare(r.res.n, 1)
    compare(Object.keys(c.pending).length, 0)
  }

  function test_an_unanswered_request_gets_an_error_and_the_rest_go_on() {
    var c = client([], 400)
    tryVerify(function() { return c.ready }, 5000)
    var hung = recorder(), next = recorder()
    c.call("hang", {}, hung.cb)
    c.call("echo", { n: 2 }, next.cb)
    tryVerify(function() { return next.done }, 2000)
    verify(!hung.done, "still waiting, inside its timeout")
    tryVerify(function() { return hung.done }, 2000)
    compare(hung.err, "echo: no answer to hang in 0.4s")
    compare(Object.keys(c.pending).length, 0)
    verify(c.ready, "a timeout is not a restart")
  }

  function test_the_timeout_counts_from_the_write_not_the_queue() {
    // Up after 0.8s, with a 0.4s timeout: a request queued at the start
    // still gets its answer.
    var c = client(["--slow-start", "0.8"], 400)
    var r = recorder()
    c.call("echo", { n: 3 }, r.cb)
    tryVerify(function() { return r.done }, 5000)
    compare(r.err, null)
    compare(r.res.n, 3)
  }

  function test_an_exit_fails_what_was_in_flight() {
    var c = client()
    tryVerify(function() { return c.ready }, 5000)
    var hung = recorder()
    c.call("hang", {}, hung.cb)
    c.call("exit", {}, function() {})
    tryVerify(function() { return hung.done }, 3000)
    compare(hung.err, "echo stopped")
    compare(Object.keys(c.pending).length, 0)
  }
}
