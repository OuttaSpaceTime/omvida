.pragma library

// The wiki graph's layout: a small force simulation, run in JS because the
// graph is ~70 nodes and ~140 links, far below where an O(n²) repulsion pass
// costs anything at 60fps. Pure, so tests/unit can check it converges and is
// deterministic. GraphView.qml steps it from a Timer and paints a Canvas.
//
// Rejected: a QtQuick item per node with Behaviors. Every tick would move
// every item through the scene graph, and the links still need a Canvas.

// The neighbourhood of `focus` within `hops` links, undirected: the viewer's
// "local" mode (GraphPanel.tsx localSubgraph). An unknown focus keeps it all.
function localSubgraph(graph, focus, hops) {
  if (!graph || !focus || !graph.nodes.some(function(n) { return n.id === focus })) return graph
  var adj = {}
  graph.links.forEach(function(l) {
    (adj[l.source] = adj[l.source] || []).push(l.target);
    (adj[l.target] = adj[l.target] || []).push(l.source)
  })
  var keep = {}
  keep[focus] = true
  var frontier = [focus]
  for (var h = 0; h < (hops || 2); h++) {
    var next = []
    frontier.forEach(function(id) {
      (adj[id] || []).forEach(function(n) { if (!keep[n]) { keep[n] = true; next.push(n) } })
    })
    frontier = next
  }
  return {
    nodes: graph.nodes.filter(function(n) { return keep[n.id] }),
    links: graph.links.filter(function(l) { return keep[l.source] && keep[l.target] })
  }
}

// Seeded so the same wiki lays out the same way every time.
function rng(seed) {
  var s = seed >>> 0 || 1
  return function() { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296 }
}

// Nodes get x, y, vx, vy, placed on a jittered circle. `previous` (id -> node)
// keeps positions across a rebuild, so switching local/all does not scramble.
function initLayout(graph, previous) {
  var rand = rng(graph.nodes.length * 7919 + graph.links.length)
  var n = graph.nodes.length
  var nodes = graph.nodes.map(function(src, i) {
    var p = previous && previous[src.id]
    var a = (i / Math.max(1, n)) * Math.PI * 2
    var r = 120 + rand() * 80
    return {
      id: src.id, title: src.title, folder: src.folder, isIndex: src.isIndex, linkCount: src.linkCount,
      x: p ? p.x : Math.cos(a) * r, y: p ? p.y : Math.sin(a) * r, vx: 0, vy: 0
    }
  })
  var index = {}
  nodes.forEach(function(nd, i) { index[nd.id] = i })
  var links = graph.links.filter(function(l) { return index[l.source] !== undefined && index[l.target] !== undefined })
    .map(function(l) { return { s: index[l.source], t: index[l.target] } })
  return { nodes: nodes, links: links, index: index, alpha: 1 }
}

// One tick. Returns the new alpha; the caller stops ticking below ~0.02.
function step(layout) {
  var repulsion = 2400, springLen = 70, springK = 0.05, gravity = 0.02, damping = 0.82
  var nodes = layout.nodes, alpha = layout.alpha
  var i, j
  for (i = 0; i < nodes.length; i++) {
    for (j = i + 1; j < nodes.length; j++) {
      var dx = nodes[j].x - nodes[i].x, dy = nodes[j].y - nodes[i].y
      var d2 = dx * dx + dy * dy
      if (d2 < 0.01) { dx = 0.1 * (i - j); dy = 0.1; d2 = dx * dx + dy * dy }
      var f = repulsion * alpha / d2
      var d = Math.sqrt(d2)
      var fx = f * dx / d, fy = f * dy / d
      nodes[i].vx -= fx; nodes[i].vy -= fy
      nodes[j].vx += fx; nodes[j].vy += fy
    }
  }
  layout.links.forEach(function(l) {
    var a = nodes[l.s], b = nodes[l.t]
    var dx = b.x - a.x, dy = b.y - a.y
    var d = Math.sqrt(dx * dx + dy * dy) || 0.1
    var f = (d - springLen) * springK * alpha
    var fx = f * dx / d, fy = f * dy / d
    a.vx += fx; a.vy += fy
    b.vx -= fx; b.vy -= fy
  })
  for (i = 0; i < nodes.length; i++) {
    var nd = nodes[i]
    if (nd.pinned) { nd.vx = 0; nd.vy = 0; continue }
    nd.vx = (nd.vx - nd.x * gravity * alpha) * damping
    nd.vy = (nd.vy - nd.y * gravity * alpha) * damping
    nd.x += nd.vx
    nd.y += nd.vy
  }
  layout.alpha = alpha * 0.985
  return layout.alpha
}

// Node radius from its degree, the way the viewer sizes them.
function radius(node) {
  return 4 + Math.sqrt(node.linkCount || 0) * 2 + (node.isIndex ? 2 : 0)
}

// The node under (x, y) in layout space, or null.
function hit(layout, x, y, slop) {
  var best = null, bestD = Infinity
  layout.nodes.forEach(function(nd) {
    var dx = nd.x - x, dy = nd.y - y
    var d = Math.sqrt(dx * dx + dy * dy)
    if (d <= radius(nd) + (slop || 4) && d < bestD) { best = nd; bestD = d }
  })
  return best
}

// Ids linked to `id`, for highlighting a hovered node's neighbours.
function neighbours(layout, id) {
  var i = layout.index[id], out = {}
  if (i === undefined) return out
  layout.links.forEach(function(l) {
    if (l.s === i) out[layout.nodes[l.t].id] = true
    if (l.t === i) out[layout.nodes[l.s].id] = true
  })
  return out
}

// The layout's bounding box, to fit it to the canvas.
function bounds(layout) {
  if (layout.nodes.length === 0) return { x: -1, y: -1, w: 2, h: 2 }
  var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
  layout.nodes.forEach(function(nd) {
    var r = radius(nd)
    x0 = Math.min(x0, nd.x - r); y0 = Math.min(y0, nd.y - r)
    x1 = Math.max(x1, nd.x + r); y1 = Math.max(y1, nd.y + r)
  })
  return { x: x0, y: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) }
}
