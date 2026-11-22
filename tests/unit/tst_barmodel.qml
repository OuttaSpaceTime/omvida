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
    for (let k in extra) o[k] = extra[k]
    return o
  }

  function test_badge_counts_reviews_only() {
    compare(M.badge(overview(35, "warn")), "35")
    compare(M.badge(overview(0, "ok")), "")
    compare(M.badge(overview(150, "pause")), "99+")
    compare(M.badge(null), "")
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

  function test_load_bars_are_the_decks_own() {
    var bars = [{ label: "Mo", reviews: 4, again: 1, due: 0 }, { label: "Tu", reviews: 12, again: 0, due: 5 }]
    compare(M.loadBars(overview(5, "ok", { load: bars })), bars)
    compare(M.loadPeak(bars), 17)
  }

  function test_load_bars_without_any() {
    compare(M.loadBars(overview(0, "ok")), [])
    compare(M.loadBars(null), [])
    compare(M.loadPeak([]), 1)
  }

  function test_retention_line_keeps_the_verdict_verbatim() {
    compare(M.retentionLine(overview(1, "ok"), "#123456"),
            'Retention 86% over 30 days · <font color="#123456">calibrated</font>')
    var none = overview(1, "ok", { calibration: { verdict: "insufficient-data", true_retention: null, window_days: 30 } })
    compare(M.retentionLine(none, "#000000"), "")
  }

  readonly property var plan: ({ learning: 0, reviews: 8, dueNow: 2, newCards: 2, newPerDay: 5, nextDayNew: 3,
                                 days: [{ day: "2026-11-23", label: "Mo", due: 15, after: 12 }, { day: "2026-11-24", label: "Tu", due: 3, after: 3 }] })

  function test_rest_day_comes_from_the_overviews_ahead() {
    verify(M.restDay(overview(0, "ok", { ahead: plan })))
    verify(!M.restDay(overview(0, "ok", { ahead: null })))
    verify(!M.restDay(overview(0, "ok")), "a deck server without it")
    compare(M.headline(overview(0, "ok", { ahead: plan })), "due · rest day")
    compare(M.headline(overview(2, "ok", { ahead: plan })), "reviews due")
  }

  function test_ahead_says_its_share() {
    compare(M.aheadCount(plan), 10)
    compare(M.aheadLine(plan), "8 reviews (2 due now) · 2 new, borrowed from Mo (it keeps 3 of 5)")
    compare(M.aheadDays(plan), "Mo 15→12 · Tu 3")
    compare(M.aheadDays({ days: [{ day: "2026-11-23", label: "Mo", due: 0, after: 0 }] }), "", "no row of zeros")
    compare(M.aheadLine({ learning: 1, reviews: 3, dueNow: 0, newCards: 0, newPerDay: 5, nextDayNew: 5, days: [] }), "1 learning step · 3 reviews")
    compare(M.glanceLine(overview(0, "ok", { ahead: plan })), "Rest day · 10 to study ahead, if you have time")
    compare(M.glanceLine(overview(0, "ok", { ahead: { learning: 0, reviews: 0, dueNow: 0, newCards: 0, newPerDay: 5, nextDayNew: 5, days: [] } })),
            "Rest day · today's share is studied")
  }
}
