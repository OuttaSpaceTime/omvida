.pragma library

// What the panel says, from the deck's overview (agentic-spaced-repetition's
// src/core/overview.ts, through `srs overview`). Pure: tests/unit in the
// Omvida repo runs it under qmltestrunner. The verdicts are the deck's own,
// shown verbatim, never re-derived here.

function parse(text) {
  var t = String(text || "").trim()
  var start = t.lastIndexOf("\n{")
  try { return JSON.parse(start === -1 ? t : t.slice(start + 1)) } catch (e) { return null }
}

function plural(n, one) { return n + " " + (n === 1 ? one : one + "s") }

function pct(x) { return x === null || x === undefined ? "–" : Math.round(x * 100) + "%" }

// The count beside the bar icon: reviews due, never the new-card pool
// (pressure's own rule), and nothing when none are due, so the count only
// appears when there is work.
function badge(o) {
  if (!o) return ""
  var n = o.pressure.flashcardsDue
  return n <= 0 ? "" : (n > 99 ? "99+" : String(n))
}

// The words beside the hero's count.
function headline(o) {
  if (!o) return "Loading…"
  var n = o.pressure.flashcardsDue
  if (n === 0) return restDay(o) ? "due · rest day" : "nothing due"
  return n === 1 ? "review due" : "reviews due"
}

// ---- rest days ------------------------------------------------------------------
// A rest day is a weekday Anki's Easy Days set to Minimum; the deck's overview
// then carries `ahead`, the share of the week it offers to study ahead
// (agentic-spaced-repetition's study-ahead.ts), and null on a study day. Absent from a
// deck server started before it had them: no rest day then.

function restDay(o) { return !!(o && o.ahead) }

// The cards today's share still holds, learning steps due included.
function aheadCount(plan) { return plan ? plan.learning + plan.reviews + plan.newCards : 0 }

// What the share is made of: "8 reviews (2 due now) · 2 new, borrowed from Mo (it keeps 3 of 5)".
function aheadLine(plan) {
  if (!plan) return ""
  var parts = []
  if (plan.learning > 0) parts.push(plural(plan.learning, "learning step"))
  if (plan.reviews > 0) parts.push(plural(plan.reviews, "review") + (plan.dueNow > 0 ? " (" + plan.dueNow + " due now)" : ""))
  if (plan.newCards > 0) {
    var from = plan.days.length > 0 ? ", borrowed from " + plan.days[0].label + " (it keeps " + plan.nextDayNew + " of " + plan.newPerDay + ")" : ""
    parts.push(plan.newCards + " new" + from)
  }
  return parts.join(" · ")
}

// The study days ahead, as scheduled and as the share leaves them: "Mo 15→12 · Tu 3".
// Nothing when the week holds no reviews: a row of zeros says nothing.
function aheadDays(plan) {
  if (!plan || !plan.days.some(function(d) { return d.due > 0 })) return ""
  return plan.days.map(function(d) { return d.label + " " + d.due + (d.after !== d.due ? "→" + d.after : "") }).join(" · ")
}

function clearance(o) {
  if (!o || o.pressure.verdict === "ok") return ""
  var c = o.pressure.clearance.flashcards
  if (o.pressure.verdict === "pause" && c.toExitPause > 0) return "Review " + c.toExitPause + " to leave pause, " + c.toExitWarn + " to leave warn"
  if (c.toExitWarn > 0) return "Review " + c.toExitWarn + " to leave warn"
  return "Cards added today raised it; that resets tomorrow"
}

// The sentence under the count: what clears the pressure, and the new cards
// it holds back.
function glanceLine(o) {
  if (!o) return ""
  if (restDay(o)) {
    var n = aheadCount(o.ahead)
    return n > 0 ? "Rest day · " + n + " to study ahead, if you have time" : "Rest day · today's share is studied"
  }
  var parts = []
  var c = clearance(o)
  if (c !== "") parts.push(c)
  if (o.pressure.newAvailable > 0) parts.push(o.pressure.newAvailable + " new waiting")
  if (parts.length === 0) parts.push(today(o))
  return parts.join(" · ")
}

// Retention over the calibration window, then the verdict, coloured (rich
// text: `color` is the verdict's colour as #rrggbb).
function retentionLine(o, color) {
  if (!o) return ""
  var c = o.calibration
  if (c.true_retention === null || c.true_retention === undefined) return ""
  var s = "Retention " + pct(c.true_retention) + " over " + c.window_days + " days"
  var v = c.verdict + (c.marginal ? " (marginal)" : "")
  return s + " · <font color=\"" + color + "\">" + v + "</font>"
}

function today(o) {
  if (!o) return ""
  var s = plural(o.reviewedToday, "review") + " today"
  if (o.streak > 0) s += " · " + plural(o.streak, "day") + " streak"
  if (o.pressure.newAvailable > 0) s += " · " + o.pressure.newAvailable + " new waiting"
  return s
}

// Maturity as fractions of the live deck, in bar order.
function maturityParts(o) {
  if (!o) return []
  var m = o.maturity
  var total = Math.max(1, m.new + m.learning + m.familiar + m.internalized)
  return [
    { key: "new", n: m.new, f: m.new / total },
    { key: "learning", n: m.learning, f: m.learning / total },
    { key: "familiar", n: m.familiar, f: m.familiar / total },
    { key: "internalized", n: m.internalized, f: m.internalized / total }
  ]
}

function weekPeak(o) {
  var peak = 1
  if (o) o.week.forEach(function(d) { peak = Math.max(peak, d.reviews) })
  return peak
}

// The chart's bars, the deck's own (overview.ts `load`). None from a deck
// server started before it had them: the panel then leaves the chart out.
function loadBars(o) { return o && o.load ? o.load : [] }

// The tallest bar's total, at least 1 so an empty chart divides safely.
function loadPeak(bars) {
  return bars.reduce(function(peak, b) { return Math.max(peak, b.reviews + b.due) }, 1)
}

function expandHome(path, home) {
  var p = String(path || "")
  if (p.indexOf("~/") === 0) return home + p.slice(1)
  if (p.indexOf("$HOME/") === 0) return home + p.slice(5)
  return p
}
