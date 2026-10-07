import QtQuick
import QtTest
import "../../Format.js" as F

TestCase {
  name: "Format"

  function test_schedule_line() {
    compare(F.scheduleLine(1, { intraDay: true, interval: 0, due: "2026-10-06T20:00:00Z" }), "Again (1) · repeats this session")
    var due = new Date(2026, 9, 9, 12).toISOString()
    compare(F.scheduleLine(3, { intraDay: false, interval: 3, due: due }), "Good (3) · next review in 3 days (2026-10-09)")
    compare(F.scheduleLine(4, { intraDay: false, interval: 1, due: due }), "Easy (4) · next review in 1 day (2026-10-09)")
    compare(F.scheduleLine(2, null), "Hard (2)")
  }

  function test_position_line_uses_the_servers_numbers() {
    compare(F.positionLine({ card: { deck: "Web" }, position: 3, total: 12, repeat: false }), "Card 3/12 · Web")
    compare(F.positionLine({ card: { deck: "Web" }, position: 13, total: 13, repeat: true }), "Card 13/13 · Web (repeat)")
  }

  function test_html_to_text() {
    compare(F.stripHtml("What is <code>&lt;br&gt;</code>?<br>Two&amp;three"), "What is <br>? Two&three")
    compare(F.htmlToText("<ul><li>a</li><li>b</li></ul>One<br>two"), "- a\n- b\nOne\ntwo")
  }

  function test_durations_are_honest() {
    compare(F.durationText(11.4), "11 min")
    compare(F.durationText(0.3), "1 min")
    compare(F.durationText(356), "5h56m (with breaks)")
    compare(F.minutesBetween(0, 1000), null)
    compare(F.minutesBetween(60000, 180000), 2)
  }

  function test_calibration_line_is_verbatim() {
    compare(F.calibrationLine({ verdict: "over-difficult", marginal: false, true_retention: 0.7457 }), "over-difficult (true retention 75%)")
    compare(F.calibrationLine({ verdict: "low-signal", marginal: false, true_retention: null }), "low-signal")
    compare(F.calibrationLine({ verdict: "calibrated", marginal: true, true_retention: 0.81 }), "calibrated, marginal (true retention 81%)")
  }

  function test_ago() {
    var now = new Date(2026, 9, 6, 12)
    compare(F.ago("2026-10-06", now), "today")
    compare(F.ago("2026-10-05", now), "yesterday")
    compare(F.ago("2026-10-01", now), "5d ago")
    compare(F.ago("2026-09-01", now), "2026-09-01")
  }
}
