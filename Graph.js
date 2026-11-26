.pragma library

// The wiki graph's layout: a small force simulation, run in JS because the
// graph is ~70 nodes and ~140 links, far below where an O(n²) repulsion pass
// costs anything at 60fps. Pure, so tests/unit can check it converges and is
// deterministic. GraphView.qml steps it from a Timer and paints a Canvas.
//
// Rejected: a QtQuick item per node with Behaviors. Every tick would move
// every item through the scene graph, and the links still need a Canvas.

// Whether two nodes share a tag. A topic is a folder plus a tag, and every page
// carries its folder's tag, so this is "same topic" as well as "same subject".
function sharesTag(a, b) {
  var tags = a.tags || []
  return (b.tags || []).some(function(t) { return tags.indexOf(t) >= 0 })
}

// The neighbourhood of `focus`: what lies within `hops` links, undirected (the
// viewer's "local" mode, GraphPanel.tsx localSubgraph), and every page that
// shares a tag with it, linked or not. Pages on one topic often don't link
// each other, and once a topic's index page linked them all; the tag is what
// still says they belong together. Only the focus's own tags count: a tag hop
// from each neighbour too would pull in most of the wiki. An unknown focus
// keeps it all.
function localSubgraph(graph, focus, hops) {
  var centre = graph ? graph.nodes.filter(function(n) { return n.id === focus })[0] : null
  if (!centre) return graph
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
  graph.nodes.forEach(function(n) { if (sharesTag(centre, n)) keep[n.id] = true })
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
// `text` sizes each node's title box for the collision pass in step():
// { charWidth, lineHeight } in pixels, the caption font's. The box is in layout
// units, which are pixels at a scale of 1; a bigger canvas only adds room, and
// a smaller one is the paint's job (GraphView drops what then collides).
function initLayout(graph, previous, text) {
  var charWidth = text && text.charWidth || 7
  var lineHeight = text && text.lineHeight || 14
  var rand = rng(graph.nodes.length * 7919 + graph.links.length)
  var n = graph.nodes.length
  var nodes = graph.nodes.map(function(src, i) {
    var p = previous && previous[src.id]
    var a = (i / Math.max(1, n)) * Math.PI * 2
    var r = 120 + rand() * 80
    return {
      id: src.id, title: src.title, folder: src.folder, tags: src.tags || [], linkCount: src.linkCount,
      labelW: LABEL_GAP + (src.title || "").length * charWidth, labelH: lineHeight,
      x: p ? p.x : Math.cos(a) * r, y: p ? p.y : Math.sin(a) * r, vx: 0, vy: 0
    }
  })
  var index = {}
  nodes.forEach(function(nd, i) { index[nd.id] = i })
  var links = graph.links.filter(function(l) { return index[l.source] !== undefined && index[l.target] !== undefined })
    .map(function(l) { return { s: index[l.source], t: index[l.target] } })
  return { nodes: nodes, links: links, kin: tagPairs(nodes), index: index, alpha: 1 }
}

// Every pair of nodes that shares a tag, by index: the layout's topic springs.
// Weaker and longer than a link's, so a topic gathers into one region without
// collapsing into a ball, and links still decide who sits next to whom. They
// do what the index pages' hub-and-spoke links used to. ~200 pairs for this
// wiki, the same order as its links.
function tagPairs(nodes) {
  var byTag = {}
  nodes.forEach(function(n, i) {
    n.tags.forEach(function(t) { (byTag[t] = byTag[t] || []).push(i) })
  })
  var seen = {}, out = []
  Object.keys(byTag).forEach(function(t) {
    var ids = byTag[t]
    for (var a = 0; a < ids.length; a++) {
      for (var b = a + 1; b < ids.length; b++) {
        var key = ids[a] + ":" + ids[b]
        if (ids[a] === ids[b] || seen[key]) continue
        seen[key] = true
        out.push({ s: ids[a], t: ids[b] })
      }
    }
  })
  return out
}

// Below this alpha the layout is at rest: nothing moves visibly any more.
var REST_ALPHA = 0.02
// Between a node and its title, in pixels (GraphView paints at this gap too).
var LABEL_GAP = 4
// Kept clear around each title box, so neighbouring titles do not touch.
var LABEL_MARGIN = 6

// A node's box: the dot, and its title to the right, where GraphView draws it
// when that side is free.
function box(nd) {
  var r = radius(nd), h = Math.max(r * 2, nd.labelH || 0) / 2 + LABEL_MARGIN / 2
  return { x0: nd.x - r - LABEL_MARGIN / 2, x1: nd.x + r + (nd.labelW || 0) + LABEL_MARGIN / 2, y0: nd.y - h, y1: nd.y + h }
}

// Pushes apart every two nodes whose boxes overlap until they touch, half each
// (all of it on the free one when the other is being dragged), along the axis
// they overlap least on (titles are wide, so mostly up and down: a column of
// titles reads, a row of them overprints). Positional, like d3's forceCollide,
// and not scaled by alpha: titles that print over each other are what made
// the graph unreadable, and a repulsion strong enough to keep them apart from
// the centres alone blew the topics' clusters apart.
function collide(nodes) {
  var boxes = nodes.map(box)
  function shift(i, dx, dy) {
    nodes[i].x += dx; nodes[i].y += dy
    var bx = boxes[i]
    bx.x0 += dx; bx.x1 += dx; bx.y0 += dy; bx.y1 += dy
  }
  for (var i = 0; i < nodes.length; i++) {
    for (var j = i + 1; j < nodes.length; j++) {
      var a = boxes[i], b = boxes[j]
      var ox = Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0)
      var oy = Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0)
      if (ox <= 0 || oy <= 0) continue
      // The push on i; j takes the rest of it the other way.
      var dx = 0, dy = 0
      if (ox < oy) dx = a.x0 + a.x1 <= b.x0 + b.x1 ? -ox : ox
      else dy = nodes[i].y <= nodes[j].y ? -oy : oy
      var share = nodes[i].pinned ? 0 : (nodes[j].pinned ? 1 : 0.5)
      shift(i, dx * share, dy * share)
      shift(j, -dx * (1 - share), -dy * (1 - share))
    }
  }
}

// One tick. Returns the new alpha; the caller stops ticking below REST_ALPHA.
function step(layout) {
  // Spread wider than it was (2400, 70, 90): at those the dots sat a title's
  // height apart and every title overprinted its neighbours.
  var repulsion = 4000, springLen = 90, springK = 0.05, kinLen = 100, kinK = 0.02, gravity = 0.02, damping = 0.82
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
  function spring(l, len, k) {
    var a = nodes[l.s], b = nodes[l.t]
    var dx = b.x - a.x, dy = b.y - a.y
    var d = Math.sqrt(dx * dx + dy * dy) || 0.1
    var f = (d - len) * k * alpha
    var fx = f * dx / d, fy = f * dy / d
    a.vx += fx; a.vy += fy
    b.vx -= fx; b.vy -= fy
  }
  layout.links.forEach(function(l) { spring(l, springLen, springK) })
  layout.kin.forEach(function(l) { spring(l, kinLen, kinK) })
  for (i = 0; i < nodes.length; i++) {
    var nd = nodes[i]
    if (nd.pinned) { nd.vx = 0; nd.vy = 0; continue }
    nd.vx = (nd.vx - nd.x * gravity * alpha) * damping
    nd.vy = (nd.vy - nd.y * gravity * alpha) * damping
    nd.x += nd.vx
    nd.y += nd.vy
  }
  // Twice: separating one pair can push a node into a third.
  collide(nodes); collide(nodes)
  layout.alpha = alpha * 0.985
  return layout.alpha
}

// Node radius from its degree, the way the viewer sizes them.
function radius(node) {
  return 4 + Math.sqrt(node.linkCount || 0) * 2
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

// Ids that share a tag with `id` but are not linked to it: the local view
// draws these as dashed lines, so a page that is there only for its tag says why.
function tagOnly(layout, id) {
  var i = layout.index[id], out = {}
  if (i === undefined) return out
  var linked = neighbours(layout, id)
  layout.kin.forEach(function(l) {
    var other = l.s === i ? l.t : (l.t === i ? l.s : -1)
    if (other >= 0 && !linked[layout.nodes[other].id]) out[layout.nodes[other].id] = true
  })
  return out
}

// The layout's bounding box, to fit it to the canvas. Titles are left out:
// most are hidden, and one at the right edge goes left of its dot (GraphView).
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
