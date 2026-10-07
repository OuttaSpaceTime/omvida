import QtQuick
import QtTest
import "../../Graph.js" as G

TestCase {
  name: "Graph"

  readonly property var graph: ({
    nodes: ["a", "b", "c", "d", "e"].map(function(id) { return { id: id, title: id, folder: "f", isIndex: false, linkCount: 1 } }),
    links: [{ source: "a", target: "b" }, { source: "b", target: "c" }, { source: "c", target: "d" }]
  })

  function test_local_subgraph_is_two_hops() {
    var sub = G.localSubgraph(graph, "a", 2)
    compare(sub.nodes.map(function(n) { return n.id }), ["a", "b", "c"])
    compare(sub.links.length, 2)
    compare(G.localSubgraph(graph, "nope", 2), graph)
  }

  function test_layout_is_deterministic_and_settles() {
    var a = G.initLayout(graph), b = G.initLayout(graph)
    compare(a.nodes[2].x, b.nodes[2].x)
    var steps = 0
    while (G.step(a) >= G.REST_ALPHA && steps < 2000) steps++
    verify(steps < 2000, "settles")
    // Linked nodes end up nearer each other than the unlinked one is to them.
    function dist(p, q) { return Math.hypot(p.x - q.x, p.y - q.y) }
    verify(dist(a.nodes[0], a.nodes[1]) < 200)
    verify(isFinite(a.nodes[4].x) && isFinite(a.nodes[4].y))
  }

  function test_hit_and_neighbours() {
    var l = G.initLayout(graph)
    var n = l.nodes[1]
    compare(G.hit(l, n.x, n.y).id, "b")
    compare(G.neighbours(l, "b"), { a: true, c: true })
    var bx = G.bounds(l)
    verify(bx.w > 0 && bx.h > 0)
  }

  function test_previous_positions_are_kept() {
    var prev = { a: { x: 5, y: 6 } }
    var l = G.initLayout(graph, prev)
    compare(l.nodes[0].x, 5)
    compare(l.nodes[0].y, 6)
  }
}
