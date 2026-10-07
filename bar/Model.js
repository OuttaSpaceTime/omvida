.pragma library

// What the panel says, from the deck's overview (flashcard-mcp's
// src/app/overview.ts, through `master overview`). Pure: tests/unit in the
// Omvida repo runs it under qmltestrunner. The verdicts are the deck's own,
// shown verbatim, never re-derived here.

function parse(text) {
  var t = String(text || "").trim()
  var start = t.lastIndexOf("\n{")
  try { return JSON.parse(start === -1 ? t : t.slice(start + 1)) } catch (e) { return null }
}

function plural(n, one) { return n + " " + (n === 1 ? one : one + "s") }

function pct(x) { return x === null || x === undefined ? "–" : Math.round(x * 100) + "%" }

// The words beside the hero's count.
function headline(o) {
  if (!o) return "Loading…"
  var n = o.pressure.flashcardsDue
  return n === 0 ? "nothing due" : (n === 1 ? "review due" : "reviews due")
}

function clearance(o) {
  if (!o || o.pressure.verdict === "ok") return ""
  var c = o.pressure.clearance.flashcards
  if (o.pressure.verdict === "pause" && c.toExitPause > 0) return "Review " + c.toExitPause + " to leave pause, " + c.toExitWarn + " to leave warn"
  if (c.toExitWarn > 0) return "Review " + c.toExitWarn + " to leave warn"
  return "Cards added today raised it; that resets tomorrow"
}

function calibration(o) {
  if (!o) return ""
  var c = o.calibration
  var s = c.verdict + (c.marginal ? " (marginal)" : "")
  if (c.true_retention !== null) s += " · retention " + pct(c.true_retention)
  return s
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

function weekday(day) {
  return "MTWTFSS".charAt((new Date(day + "T12:00:00").getDay() + 6) % 7)
}

function expandHome(path, home) {
  var p = String(path || "")
  if (p.indexOf("~/") === 0) return home + p.slice(1)
  if (p.indexOf("$HOME/") === 0) return home + p.slice(5)
  return p
}
