import QtQuick

import "Graph.js" as Graph

// The wiki's link graph on a Canvas, laid out by Graph.js's force simulation.
// Nodes are coloured by topic and sized by degree, and pages that share a tag
// are drawn towards each other. Hover lights a node and its neighbours; click
// opens the page; drag pins a node; the wheel zooms.
//
// `local` shows the focus page, two hops out, and every page sharing a tag
// with it; those that are there only for a tag hang off it on dashed lines.
Item {
  id: root
  clip: true

  property var app: null
  property string focusPath: ""
  property bool local: false
  property bool compact: false
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

  readonly property var graph: app && app.store.wikiIndex ? app.store.wikiIndex.graph : null
  readonly property var shown: graph ? (local ? Graph.localSubgraph(graph, focusPath, 2) : graph) : null

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
    var next = Graph.initLayout(shown, prev)
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
    if (!local || layout.index[focusPath] === undefined) return out
    var kin = Graph.tagOnly(layout, focusPath)
    if (id === focusPath) Object.keys(kin).forEach(function(k) { out[k] = true })
    else if (kin[id]) out[focusPath] = true
    return out
  }
  function toLayout(x, y) { var f = fit(); return { x: (x - f.ox) / f.s, y: (y - f.oy) / f.s } }

  Timer {
    id: ticker
    interval: Theme.graphTickInterval
    repeat: true
    running: root.settling && root.layout !== null && root.visible
    // Three steps a frame: a step is under a millisecond, the paint is most
    // of the cost, and the layout rests in a third of the frames.
    onTriggered: {
      var a = 1
      for (var i = 0; i < 3; i++) a = Graph.step(root.layout)
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
      var litLink = Theme.accentColor, plainLink = Theme.alpha(Theme.ink, hv !== "" ? 0.06 : 0.14)
      L.links.forEach(function(l) {
        var a = L.nodes[l.s], b = L.nodes[l.t]
        var lit = hv !== "" && (a.id === hv || b.id === hv)
        ctx.strokeStyle = lit ? litLink : plainLink
        ctx.beginPath()
        ctx.moveTo(f.ox + a.x * f.s, f.oy + a.y * f.s)
        ctx.lineTo(f.ox + b.x * f.s, f.oy + b.y * f.s)
        ctx.stroke()
      })
      // Only the local view: across the whole wiki a line per shared tag is
      // a few hundred more, and the clustering already shows the topics.
      var centre = root.local ? L.nodes[L.index[root.focusPath]] : null
      if (centre) {
        var kin = Graph.tagOnly(L, centre.id)
        ctx.setLineDash([Theme.spaceXs, Theme.spaceXs])
        L.nodes.forEach(function(n) {
          if (!kin[n.id]) return
          ctx.strokeStyle = hv !== "" && (n.id === hv || centre.id === hv) ? litLink : plainLink
          ctx.beginPath()
          ctx.moveTo(f.ox + centre.x * f.s, f.oy + centre.y * f.s)
          ctx.lineTo(f.ox + n.x * f.s, f.oy + n.y * f.s)
          ctx.stroke()
        })
        ctx.setLineDash([])
      }
      L.nodes.forEach(function(n) {
        var r = Graph.radius(n) * Math.max(0.7, Math.min(1.4, f.s))
        var x = f.ox + n.x * f.s, y = f.oy + n.y * f.s
        var dim = hv !== "" && n.id !== hv && !nb[n.id]
        var c = Theme.topicColor(n.folder)
        ctx.globalAlpha = dim ? 0.25 : 1
        ctx.beginPath()
        ctx.arc(x, y, r, 0, Math.PI * 2)
        ctx.fillStyle = c
        ctx.fill()
        if (n.id === root.focusPath) {
          ctx.lineWidth = 2
          ctx.strokeStyle = Theme.ink
          ctx.beginPath()
          ctx.arc(x, y, r + 3, 0, Math.PI * 2)
          ctx.stroke()
        }
        // Labels for the well-linked pages and for what the pointer is on:
        // every label at once overprints itself in the middle of a wiki this size.
        var label = n.id === hv || nb[n.id] || n.id === root.focusPath
                    || (!root.compact && hv === "" && (n.linkCount >= 4 || L.nodes.length <= 20))
        if (label) {
          ctx.fillStyle = dim ? Theme.faint : (n.id === hv ? Theme.ink : Theme.dim)
          ctx.font = (n.id === hv ? "bold " : "") + Theme.captionSize + "px monospace"
          // To the right of the node, slid left as far as it must to stay on
          // the canvas (a node at the rail's right edge).
          var w = ctx.measureText(n.title).width
          ctx.fillText(n.title, Math.max(0, Math.min(x + r + 3, width - w)), y + 4)
        }
        ctx.globalAlpha = 1
      })
    }
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
    cursorShape: root.hovered !== "" ? Qt.PointingHandCursor : (pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor)

    onPositionChanged: function(mouse) {
      if (!root.layout) return
      var p = root.toLayout(mouse.x, mouse.y)
      if (pressed) {
        if (Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) > 3) moved = true
        if (root.dragNode) {
          root.dragNode.x = p.x; root.dragNode.y = p.y
          root.layout.alpha = Math.max(root.layout.alpha, 0.2)
          root.settling = true
        } else {
          root.panX = startPanX + mouse.x - pressX
          root.panY = startPanY + mouse.y - pressY
        }
        canvas.requestPaint()
        return
      }
      var n = Graph.hit(root.layout, p.x, p.y, 6 / Math.max(0.3, root.fit().s))
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
      if (!root.layout) return
      var p = root.toLayout(mouse.x, mouse.y)
      var n = Graph.hit(root.layout, p.x, p.y, 6 / Math.max(0.3, root.fit().s))
      root.dragNode = n
      if (n) n.pinned = true
    }
    onReleased: function(mouse) {
      var n = root.dragNode
      root.dragNode = null
      if (n) n.pinned = false
      if (!moved && n && root.app) root.app.openPage(n.id, "")
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
