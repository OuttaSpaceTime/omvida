import QtQuick
import QtTest
import "../../Format.js" as F

TestCase {
  name: "Format"

  function test_interval_label() {
    var served = new Date(2026, 9, 8, 9, 0).getTime()
    var at = function(mins) { return new Date(served + mins * 60000).toISOString() }
    compare(F.intervalLabel({ intraDay: true, interval: 0, due: at(0.2) }, served), "<1m")
    compare(F.intervalLabel({ intraDay: true, interval: 0, due: at(10) }, served), "10m", "counted from when it was served")
    compare(F.intervalLabel({ intraDay: true, interval: 0, due: at(300) }, served), "5h")
    compare(F.intervalLabel({ intraDay: false, interval: 1, due: at(1440) }, served), "1d")
    compare(F.intervalLabel({ intraDay: false, interval: 12, due: at(0) }, served), "12d")
    compare(F.intervalLabel({ intraDay: false, interval: 45, due: at(0) }, served), "1.5mo")
    compare(F.intervalLabel({ intraDay: false, interval: 60, due: at(0) }, served), "2mo")
    compare(F.intervalLabel({ intraDay: false, interval: 400, due: at(0) }, served), "1.1y")
    compare(F.intervalLabel(undefined, served), "", "an older deck server sends none")
  }

  function test_position_uses_the_servers_numbers() {
    compare(F.position({ card: { deck: "Web" }, position: 3, total: 12, repeat: false }), "3/12")
    compare(F.position({ card: { deck: "Web" }, position: null, total: null, repeat: false }), "")
    compare(F.position(null), "")
  }

  function test_escape_html() {
    compare(F.escapeHtml("a <b> & \"c\""), "a &lt;b&gt; &amp; &quot;c&quot;")
    compare(F.escapeHtml(null), "")
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

  function test_plain_text_for_a_tile() {
    compare(F.stripHtml("What is <b>HSTS</b>?<br>Say <code>max-age</code>."), "What is HSTS? Say max-age.")
    compare(F.stripHtml("<pre>a  &lt;b&gt;\n  c</pre><p>x &amp; y</p>"), "a <b> c x & y")
    // Decoded once: an escaped entity stays the entity's text.
    compare(F.stripHtml("&amp;lt; &quot;q&quot; &#39;s&#39; &#65;"), "&lt; \"q\" 's' A")
    compare(F.stripHtml(""), "")
    compare(F.stripHtml(null), "")
  }
}
