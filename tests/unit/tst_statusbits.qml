import QtQuick
import QtTest
import "../../StatusBits.js" as S

// What the reading screens hand the window's status line: hints that run what
// their keys run, and the pressure verdict as an alert.
TestCase {
  name: "StatusBits"

  function fakeApp(verdict, history) {
    var calls = []
    return {
      calls: calls,
      history: history || [],
      store: { overview: verdict === null ? null : { pressure: { verdict: verdict } } },
      openSearch: function(t) { calls.push("search:" + t) },
      goBack: function() { calls.push("back") },
      startStudy: function() { calls.push("study") }
    }
  }

  function color(v) { return v === "warn" ? "orange" : "red" }

  function test_common_hints_run_what_their_keys_run() {
    var app = fakeApp("ok", [{ screen: "home" }])
    var hints = S.common(app, [S.study(app)])
    compare(hints.map(function(h) { return h.keys }), ["⌃2", "⌃K", "alt+←"])
    hints.forEach(function(h) { h.run() })
    compare(app.calls, ["study", "search:", "back"])
  }

  function test_back_only_with_history() {
    compare(S.back(fakeApp("ok", [])), null)
    compare(S.common(fakeApp("ok", [])).map(function(h) { return h.label }), ["search"])
  }

  // Ctrl+N toggles the Add menu, which only the window reaches: no hint until
  // the window offers toggleAdd(), never one that opens something else.
  function test_add_waits_for_the_window() {
    var app = fakeApp("ok")
    compare(S.add(app), null)
    var toggled = 0
    app.toggleAdd = function() { toggled++ }
    var hint = S.add(app)
    compare(hint.keys, "⌃N")
    hint.run()
    compare(toggled, 1)
  }

  function test_pressure_alert_is_the_verdict_verbatim() {
    compare(S.pressure(fakeApp("ok"), "", color), [])
    compare(S.pressure(fakeApp(null), "", color), [])
    var app = fakeApp("warn")
    var alerts = S.pressure(app, "Review 18 to leave warn", color)
    compare(alerts.length, 1)
    compare(alerts[0].text, "● warn")
    compare(alerts[0].color, "orange")
    compare(alerts[0].tip, "Review 18 to leave warn")
    alerts[0].run()
    compare(app.calls, ["study"])
  }
}
