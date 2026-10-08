.pragma library

// Small formatters shared by the screens. Pure; tests/unit/tst_format.qml.

function plural(n, one) {
  return n + " " + (n === 1 ? one : one + "s")
}

function pct(x) {
  return x === null || x === undefined || isNaN(x) ? "–" : Math.round(x * 100) + "%"
}

// YYYY-MM-DD in local time.
function dayKey(d) {
  var m = d.getMonth() + 1, day = d.getDate()
  return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day
}

var RATING_NAMES = ["", "Again", "Hard", "Good", "Easy"]
function ratingName(n) { return RATING_NAMES[n] || "" }

// /study's rating line, from submitReview's schedule. An intra-day step gets
// no minute count: the server only says it repeats this session.
function scheduleLine(rating, schedule) {
  var head = ratingName(rating) + " (" + rating + ")"
  if (!schedule) return head
  if (schedule.intraDay || schedule.interval < 1) return head + " · repeats this session"
  var days = Math.round(schedule.interval)
  return head + " · next review in " + plural(days, "day") + " (" + dayKey(new Date(schedule.due)) + ")"
}

// "3/12": where the session is, for the status line, which shows the deck
// and a repeat as segments of their own. From nextCard's own position and
// total, never counted here: the server already accounts for re-queues,
// skips and deletes. "" when the server gives none.
function position(next) {
  if (!next || !next.card) return ""
  if (next.position === null || next.position === undefined || next.total === null || next.total === undefined) return ""
  return next.position + "/" + next.total
}

// Text from elsewhere (Claude's reason) set inside StyledText.
function escapeHtml(s) {
  return String(s === null || s === undefined ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

// Card HTML to one line of plain text (lists, search rows, prompts).
// Line and block ends become spaces, so "a</li><li>b" stays two words, and
// &amp; is decoded last, so "&amp;lt;" stays the literal text "&lt;". The
// Cards grid draws this, not the HTML, because Qt only elides plain text
// (rich text runs on past maximumLineCount).
function stripHtml(html) {
  return String(html || "")
    .replace(/<br\s*\/?>|<\/(p|div|li|pre|tr|h[1-6])>/gi, " ")
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;/g, " ").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'")
    .replace(/&#(\d+);/g, function(m, n) { return String.fromCharCode(parseInt(n, 10)) })
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ").trim()
}

// Card HTML to text with line breaks kept, for a prompt Claude reads.
function htmlToText(html) {
  return String(html || "")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|li|pre|div)>/gi, "\n")
    .replace(/<li>/gi, "- ")
    .replace(/<[^>]*>/g, "")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
    .replace(/\n{3,}/g, "\n\n").trim()
}

// Minutes from ms, for the honest-duration rule: measured from the first card
// shown to the last rating submitted, never from when the session was opened.
function minutesBetween(startMs, endMs) {
  if (!startMs || !endMs || endMs < startMs) return null
  return (endMs - startMs) / 60000
}

// /study's honest duration, as its log template writes it: under two hours
// plainly, longer marked as with breaks. Used on screen and in the log.
function durationText(minutes) {
  if (minutes === null || minutes === undefined) return ""
  if (minutes < 120) return Math.max(1, Math.round(minutes)) + " min"
  var h = Math.floor(Math.round(minutes) / 60), m = Math.round(minutes) % 60
  return h + "h" + (m < 10 ? "0" : "") + m + "m (with breaks)"
}

// The calibration line /study writes: verdict verbatim, retention as given.
function calibrationLine(c) {
  if (!c) return ""
  var s = c.verdict
  if (c.marginal) s += ", marginal"
  if (c.true_retention !== null && c.true_retention !== undefined) s += " (true retention " + pct(c.true_retention) + ")"
  return s
}

// How long ago an ISO day was, for list rows ("today", "3d ago", the date).
function ago(day, now) {
  if (!day) return ""
  var today = dayKey(now || new Date())
  if (day === today) return "today"
  var a = new Date(day + "T00:00:00"), b = new Date(today + "T00:00:00")
  var d = Math.round((b - a) / 86400000)
  if (d === 1) return "yesterday"
  if (d > 1 && d < 14) return d + "d ago"
  return day
}
