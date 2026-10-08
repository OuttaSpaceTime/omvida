.pragma library

// The hints and the alert the window's status line (StatusLine.qml) adds
// after every screen's own, Study's excepted. The keys these hints name are the window's own
// (omvida.qml's contentRoot), and each hint's run() calls the same function
// its key does, so a click on a hint and the key never drift apart.
// One line at the bottom teaches the keys, so the buttons say only what
// they do.

function search(app) {
  return { keys: "⌃K", label: "search", run: function() { app.openSearch("") } }
}

function add(app) {
  return { keys: "⌃N", label: "add", run: function() { app.toggleAdd() } }
}

function back(app) {
  if (!app || app.history.length === 0) return null
  return { keys: "alt+←", label: "back", run: function() { app.goBack() } }
}

function study(app) {
  return { keys: "⌃2", label: "study", run: function() { app.startStudy() } }
}

// The hints every reading screen shares, after its own.
function common(app, own) {
  if (!app) return []
  return (own || []).concat([search(app), add(app), back(app)]).filter(function(h) { return h !== null })
}

// The pressure verdict as an alert, verbatim, while it asks for something
// (warn, pause); "ok" says nothing. A click goes to Study, the one thing that
// clears it. `color` is Theme.verdictColor, passed in because a .pragma
// library script cannot see the Theme singleton.
// `p` is a pressure verdict object (the overview's, or Study's session's);
// `tip` what clears it.
function pressure(app, p, tip, color) {
  if (!p || p.verdict === "ok") return []
  return [{ text: "● " + p.verdict, color: color(p.verdict), tip: tip,
            run: function() { app.startStudy() } }]
}
