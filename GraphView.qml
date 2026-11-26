import QtQuick

import "Graph.js" as Graph

// The wiki's link graph on a Canvas, laid out by Graph.js's force simulation.
// Nodes are coloured by topic and sized by degree, and pages that share a tag
// are drawn towards each other. Hover lights a node and its neighbours; click
// opens the page (pageChosen: the view only says which, the screen opens
// it); drag pins a node; the wheel zooms.
//
// `local` shows the focus page, two hops out, and every page sharing a tag
// with it; those that are there only for a tag hang off it on dashed lines.
Item {
  id: root
  clip: true

  // The wiki service's graph: { nodes, links }.
  property var graph: null
  property string focusPath: ""
  property bool local: false
  property bool compact: false
  // Topics switched on in the legend (top folder -> true): their pages are
  // titled, and the rest dimmed while nothing is hovered.
  property var activeTopics: ({})
  readonly property bool anyTopic: Object.keys(activeTopics).length > 0
  onActiveTopicsChanged: canvas.requestPaint()
  function inTopic(n) { return activeTopics[String(n.folder || "").split("/")[0]] === true }
  // Until the layout comes to rest. The ticker runs only while this is set and
  // the graph is on screen, so a hidden graph costs nothing.
  property bool settling: false

  property var layout: null
  property string hovered: ""
  property var hoverNeighbours: ({})
  property real zoom: 1
  property real panX: 0
  property real panY: 0
  property var dragNode: null
  // Where the last paint put each title, in canvas pixels, with its node.
  property var titleBoxes: []
  // A node was clicked, not dragged: its page.
  signal pageChosen(string path)

  readonly property var shown: graph ? (local ? Graph.localSubgraph(graph, focusPath, 2) : graph) : null
  // The local view's tag-only pages (the dashed lines), worked out once per
  // layout: paint runs every settling frame and hover asks on every move.
  readonly property var tagKin: local && layout ? Graph.tagOnly(layout, focusPath) : ({})

  // A graph is laid out before it is seen: settled on screen, a new one grew
  // out of its starting circle while fit() rescaled it to its bounds every
  // frame, and jumped about for seconds. So a new layout, or one that
  // changed while hidden, is run to rest just before it is shown, and the
  // first paint is the finished layout; hidden, it waits, so a graph nobody
  // looks at (the narrow window's rail, the local view on another screen)
  // costs nothing per change. It is a few hundred steps of well under a
  // millisecond for a wiki this size; the budget only guards a much bigger
  // one, which then settles the rest on screen. A change under a layout on
  // screen (a page added, the local view moved) keeps the old positions and
  // eases into the new ones.
  function rebuild() {
    if (!shown) { layout = null; canvas.requestPaint(); return }
    var prev = {}
    if (layout) layout.nodes.forEach(function(n) { prev[n.id] = n })
    // Monospace at the caption size: a character is about 0.6 of the size.
    var next = Graph.initLayout(shown, prev, { charWidth: Theme.captionSize * 0.6, lineHeight: Theme.captionSize + Theme.spaceXs })
    var kept = Object.keys(prev).length > 0
    if (kept) next.alpha = 0.3
    layout = next
    if (visible && !kept) settleNow()
    settling = next.alpha >= Graph.REST_ALPHA
    canvas.requestPaint()
  }
  function settleNow() {
    var start = Date.now()
    while (layout.alpha >= Graph.REST_ALPHA && Date.now() - start < Theme.graphSettleBudget) Graph.step(layout)
    settling = layout.alpha >= Graph.REST_ALPHA
  }
  onVisibleChanged: if (visible && layout) { settleNow(); canvas.requestPaint() }
  onShownChanged: rebuild()

  // Layout space to the canvas: fitted to the box, then the user's zoom and pan.
  function fit() {
    if (!layout) return { s: 1, ox: width / 2, oy: height / 2 }
    var b = Graph.bounds(layout)
    // A node is drawn at least 0.7 of its size however far the graph is
    // scaled down (onPaint), more than the bounds allow for when the scale is
    // small, so the edge keeps room for the largest one and its focus ring.
    var rMax = 0
    layout.nodes.forEach(function(n) { rMax = Math.max(rMax, Graph.radius(n)) })
    var pad = (compact ? Theme.spaceLg : Theme.space2xl) + rMax * 0.7 + Theme.spaceXs
    var s = Math.min((width - pad * 2) / b.w, (height - pad * 2) / b.h, compact ? 1.2 : 1.6) * zoom
    return { s: s, ox: width / 2 - (b.x + b.w / 2) * s + panX, oy: height / 2 - (b.y + b.h / 2) * s + panY }
  }
  // What hovering `id` lights: its links, and in the local view the dashed
  // tag lines too, from either end.
  function related(id) {
    var out = Graph.neighbours(layout, id)
    if (id === focusPath) Object.keys(tagKin).forEach(function(k) { out[k] = true })
    else if (tagKin[id]) out[focusPath] = true
    return out
  }
  function toLayout(x, y) { var f = fit(); return { x: (x - f.ox) / f.s, y: (y - f.oy) / f.s } }
  // The node under the pointer: its dot, or else its title, so a title hovers,
  // opens and drags like the dot it names.
  function nodeAt(x, y) {
    if (!layout) return null
    var p = toLayout(x, y)
    var n = Graph.hit(layout, p.x, p.y, 6 / Math.max(0.3, fit().s))
    if (n) return n
    var t = titleBoxes.filter(function(b) { return x >= b.x0 && x <= b.x1 && y >= b.y0 && y <= b.y1 })[0]
    return t ? t.n : null
  }

  Timer {
    id: ticker
    interval: Theme.graphTickInterval
    repeat: true
    running: root.settling && root.layout !== null && root.visible
    // Three steps a frame: a step is under a millisecond, the paint is most
    // of the cost, and the layout rests in a third of the frames.
    onTriggered: {
      var a = 1
      for (let i = 0; i < 3; i++) a = Graph.step(root.layout)
      canvas.requestPaint()
      if (a < Graph.REST_ALPHA && !root.dragNode) root.settling = false
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var L = root.layout
      if (!L) return
      var f = root.fit()
      var hv = root.hovered
      var nb = root.hoverNeighbours
      ctx.lineWidth = 1
      // While hovering, what is not the hovered page's all but goes: at a
      // quarter strength the rest of the graph still read as noise around
      // the lit page and its titles.
      var litLink = Theme.accentColor, plainLink = Theme.alpha(Theme.ink, hv !== "" ? 0.03 : 0.14)
      // An edge, lit when the hovered node is either end.
      function edge(a, b) {
        ctx.strokeStyle = hv !== "" && (a.id === hv || b.id === hv) ? litLink : plainLink
        ctx.beginPath()
        ctx.moveTo(f.ox + a.x * f.s, f.oy + a.y * f.s)
        ctx.lineTo(f.ox + b.x * f.s, f.oy + b.y * f.s)
        ctx.stroke()
      }
      L.links.forEach(function(l) { edge(L.nodes[l.s], L.nodes[l.t]) })
      // Only the local view: across the whole wiki a line per shared tag is
      // a few hundred more, and the clustering already shows the topics.
      var centre = root.local ? L.nodes[L.index[root.focusPath]] : null
      if (centre) {
        let kin = root.tagKin
        ctx.setLineDash([Theme.spaceXs, Theme.spaceXs])
        L.nodes.forEach(function(n) { if (kin[n.id]) edge(centre, n) })
        ctx.setLineDash([])
      }
      // Dots first, all of them, so the titles can then be placed around
      // every dot rather than only the ones painted so far.
      let dots = []
      L.nodes.forEach(function(n) {
        let r = Graph.radius(n) * Math.max(0.7, Math.min(1.4, f.s))
        let x = f.ox + n.x * f.s, y = f.oy + n.y * f.s
        let dim = hv !== "" ? n.id !== hv && !nb[n.id] : root.anyTopic && !root.inTopic(n)
        dots.push({ n: n, x: x, y: y, r: r, dim: dim })
        ctx.globalAlpha = dim ? (hv !== "" ? 0.1 : 0.25) : 1
        ctx.beginPath()
        ctx.arc(x, y, r, 0, Math.PI * 2)
        ctx.fillStyle = Theme.topicColor(n.folder)
        ctx.fill()
        if (n.id === root.focusPath) {
          ctx.lineWidth = 2
          ctx.strokeStyle = Theme.ink
          ctx.beginPath()
          ctx.arc(x, y, r + 3, 0, Math.PI * 2)
          ctx.stroke()
        }
      })
      ctx.globalAlpha = 1
      root.titleBoxes = root.paintTitles(ctx, dots, hv, nb)
    }
  }

  // Titles, only for what was asked for: the hovered page and every page it
  // links to, the open page, and the pages of the topics switched on in the
  // legend. Every title at once was more than anyone reads. Each is placed
  // where it prints over no other title and no other dot: to the right of its
  // dot, else to its left, else not at all; the hovered page, its links and
  // the open page get theirs anyway, and go first so the rest give way to
  // them. Returns where each title went, so a title is a hover and click
  // target like its dot.
  function paintTitles(ctx, dots, hv, nb) {
    function rank(d) {
      if (d.n.id === hv) return 0
      if (d.n.id === focusPath) return 1
      if (nb[d.n.id]) return 2
      if (inTopic(d.n)) return 3
      return 4
    }
    var order = dots.filter(function(d) { return rank(d) < 4 })
    order.sort(function(a, b) { return rank(a) - rank(b) || (b.n.linkCount || 0) - (a.n.linkCount || 0) })
    var placed = []
    var halfH = Theme.captionSize / 2 + 1
    function free(x0, x1, y0, y1, self) {
      if (x0 < 0 || x1 > width) return false
      if (placed.some(function(p) { return x0 < p.x1 && x1 > p.x0 && y0 < p.y1 && y1 > p.y0 })) return false
      // A dot is hit when the box's nearest point to its centre lies inside it.
      return !dots.some(function(d) {
        if (d === self) return false
        let cx = Math.max(x0, Math.min(d.x, x1)), cy = Math.max(y0, Math.min(d.y, y1))
        return (d.x - cx) * (d.x - cx) + (d.y - cy) * (d.y - cy) < d.r * d.r
      })
    }
    order.forEach(function(d) {
      ctx.font = (d.n.id === hv ? "bold " : "") + Theme.captionSize + "px monospace"
      var w = ctx.measureText(d.n.title).width
      var y0 = d.y - halfH, y1 = d.y + halfH
      var right = d.x + d.r + Graph.LABEL_GAP, left = d.x - d.r - Graph.LABEL_GAP - w
      var x = free(right, right + w, y0, y1, d) ? right
            : free(left, left + w, y0, y1, d) ? left
            : rank(d) < 3 ? Math.max(0, Math.min(right, width - w))
            : -1
      if (x < 0) return
      placed.push({ x0: x - 2, x1: x + w + 2, y0: y0, y1: y1, n: d.n })
      ctx.fillStyle = d.dim ? Theme.faint : (d.n.id === hv ? Theme.ink : Theme.dim)
      ctx.fillText(d.n.title, x, d.y + 4)
    })
    return placed
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    property real pressX: 0
    property real pressY: 0
    property bool moved: false
    property real startPanX: 0
    property real startPanY: 0
    // Where on the node it was picked up, in layout units: dragged by its
    // title, the dot keeps its distance from the pointer instead of jumping to it.
    property real grabX: 0
    property real grabY: 0
    cursorShape: root.hovered !== "" ? Qt.PointingHandCursor : (pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor)

    onPositionChanged: function(mouse) {
      if (!root.layout) return
      var p = root.toLayout(mouse.x, mouse.y)
      if (pressed) {
        if (Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) > 3) moved = true
        if (root.dragNode) {
          root.dragNode.x = p.x + grabX; root.dragNode.y = p.y + grabY
          root.layout.alpha = Math.max(root.layout.alpha, 0.2)
          root.settling = true
        } else {
          root.panX = startPanX + mouse.x - pressX
          root.panY = startPanY + mouse.y - pressY
        }
        canvas.requestPaint()
        return
      }
      var n = root.nodeAt(mouse.x, mouse.y)
      var id = n ? n.id : ""
      if (id !== root.hovered) {
        root.hovered = id
        root.hoverNeighbours = id ? root.related(id) : ({})
        canvas.requestPaint()
      }
    }
    onPressed: function(mouse) {
      pressX = mouse.x; pressY = mouse.y; moved = false
      startPanX = root.panX; startPanY = root.panY
      var n = root.nodeAt(mouse.x, mouse.y)
      if (n) { let p = root.toLayout(mouse.x, mouse.y); grabX = n.x - p.x; grabY = n.y - p.y }
      root.dragNode = n
      if (n) n.pinned = true
    }
    onReleased: function(mouse) {
      var n = root.dragNode
      root.dragNode = null
      if (n) n.pinned = false
      if (!moved && n) root.pageChosen(n.id)
    }
    onExited: { root.hovered = ""; root.hoverNeighbours = ({}); canvas.requestPaint() }
    onWheel: function(wheel) {
      root.zoom = Math.max(0.3, Math.min(4, root.zoom * (wheel.angleDelta.y > 0 ? 1.1 : 1 / 1.1)))
      canvas.requestPaint()
    }
  }

  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  Connections { target: Theme; function onBackgroundChanged() { canvas.requestPaint() } }
}
