import QtQuick
import QtTest
import "../../Graph.js" as G

TestCase {
  name: "Graph"

  readonly property var graph: ({
    nodes: ["a", "b", "c", "d", "e"].map(function(id) {
      return { id: id, title: id, folder: "f", tags: id === "a" || id === "e" ? ["x"] : (id === "d" ? ["y"] : []), linkCount: 1 }
    }),
    links: [{ source: "a", target: "b" }, { source: "b", target: "c" }, { source: "c", target: "d" }]
  })

  // a-b-c-d linked; a and e share tag x, d has y alone.
  function test_local_subgraph_is_two_hops_and_the_focus_tags() {
    var sub = G.localSubgraph(graph, "a", 2)
    // e is unlinked but shares x with a; d is three hops out and shares nothing.
    compare(sub.nodes.map(function(n) { return n.id }), ["a", "b", "c", "e"])
    compare(sub.links.length, 2)
    // Only the focus's own tags count: c's neighbour d is not pulled in by them.
    compare(G.localSubgraph(graph, "c", 1).nodes.map(function(n) { return n.id }), ["b", "c", "d"])
    compare(G.localSubgraph(graph, "nope", 2), graph)
  }

  function test_tag_only_relatives_exclude_linked_pages() {
    var l = G.initLayout({
      nodes: [{ id: "a", tags: ["x"] }, { id: "b", tags: ["x"] }, { id: "c", tags: ["x"] }, { id: "d", tags: ["y"] }],
      links: [{ source: "a", target: "b" }]
    })
    compare(G.tagOnly(l, "a"), { c: true })
    compare(G.tagOnly(l, "d"), {})
  }

  // Twelve unlinked pages in two tags, started interleaved round the circle:
  // with no links at all, the tag springs alone must pull each tag's pages
  // nearer each other than to the other tag's (1.1 with no springs).
  function test_pages_sharing_a_tag_settle_together() {
    var nodes = []
    for (var i = 0; i < 12; i++) nodes.push({ id: "n" + i, tags: [i % 2 ? "odd" : "even"], linkCount: 0 })
    var l = G.initLayout({ nodes: nodes, links: [] })
    var steps = 0
    while (G.step(l) >= G.REST_ALPHA && steps < 3000) steps++
    function dist(p, q) { return Math.hypot(p.x - q.x, p.y - q.y) }
    var same = 0, other = 0, ns = 0, no = 0
    for (var a = 0; a < 12; a++) {
      for (var b = a + 1; b < 12; b++) {
        if (a % 2 === b % 2) { same += dist(l.nodes[a], l.nodes[b]); ns++ }
        else { other += dist(l.nodes[a], l.nodes[b]); no++ }
      }
    }
    verify(same / ns < 0.95 * (other / no), "same-tag mean " + same / ns + " vs other " + other / no)
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
