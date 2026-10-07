import QtQuick
import QtTest
import "../../bar/Model.js" as M

// The bar panel's wording, from a deck overview.
TestCase {
  name: "BarModel"

  function overview(due, verdict, extra) {
    var o = {
      pressure: { verdict: verdict, flashcardsDue: due, newAvailable: 2, newToday: 0, reasons: [],
                  clearance: { flashcards: { due: due, toExitWarn: Math.max(0, due - 19), toExitPause: Math.max(0, due - 49) } } },
      calibration: { verdict: "calibrated", marginal: false, true_retention: 0.86, reviews: 120, window_days: 30 },
      streak: 3, reviewedToday: 12,
      maturity: { new: 2, learning: 1, familiar: 3, internalized: 4 },
      week: [{ day: "2026-10-05", reviews: 4, again: 1 }, { day: "2026-10-06", reviews: 12, again: 0 }],
      pending: []
    }
    for (var k in extra) o[k] = extra[k]
    return o
  }

  function test_clearance() {
    compare(M.clearance(overview(35, "warn")), "Review 16 to leave warn")
    compare(M.clearance(overview(60, "pause")), "Review 11 to leave pause, 41 to leave warn")
    compare(M.clearance(overview(3, "ok")), "")
    compare(M.clearance(overview(3, "warn")), "Cards added today raised it; that resets tomorrow")
  }

  function test_lines() {
    compare(M.headline(overview(1, "ok")), "review due")
    compare(M.headline(overview(0, "ok")), "nothing due")
    compare(M.calibration(overview(0, "ok")), "calibrated · retention 86%")
    compare(M.today(overview(0, "ok")), "12 reviews today · 3 days streak · 2 new waiting")
    compare(M.weekPeak(overview(0, "ok")), 12)
    compare(M.maturityParts(overview(0, "ok"))[3], { key: "internalized", n: 4, f: 0.4 })
  }

  function test_parse_takes_the_last_json_line() {
    compare(M.parse('warning\n{"a":1}').a, 1)
    compare(M.parse("not json"), null)
  }

  function test_expand_home() {
    compare(M.expandHome("~/Code/omvida", "/home/x"), "/home/x/Code/omvida")
    compare(M.expandHome("$HOME/a", "/home/x"), "/home/x/a")
    compare(M.expandHome("/abs", "/home/x"), "/abs")
  }

  function test_glance_line_says_what_clears_the_pressure() {
    compare(M.glanceLine(overview(37, "warn")), "Review 18 to leave warn · 2 new waiting")
    // With nothing to clear, it falls back to today's line.
    compare(M.glanceLine(overview(3, "ok", { pressure: { verdict: "ok", flashcardsDue: 3, newAvailable: 0,
                                                       clearance: { flashcards: {} } } })),
            "12 reviews today · 3 days streak")
    compare(M.glanceLine(null), "")
  }

  function test_retention_line_keeps_the_verdict_verbatim() {
    compare(M.retentionLine(overview(1, "ok"), "#123456"),
            'Retention 86% over 30 days · <font color="#123456">calibrated</font>')
    var none = overview(1, "ok", { calibration: { verdict: "insufficient-data", true_retention: null, window_days: 30 } })
    compare(M.retentionLine(none, "#000000"), "")
  }
}
