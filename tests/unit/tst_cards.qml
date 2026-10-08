import QtQuick
import QtTest
import "../../Cards.js" as C

TestCase {
  name: "Cards"

  readonly property var deck: [
    { id: "a", deck: "Web", front: "What is <b>HSTS</b>?", back: "A header", tags: ["web", "security"], state: "review", suspended: false },
    { id: "b", deck: "Web", front: "CSRF?", back: "Forgery", tags: ["security"], state: "new", suspended: false },
    { id: "c", deck: "Rails", front: "N+1", back: "Queries", tags: ["rails"], state: "review", suspended: true }
  ]

  function ids(cards) { return cards.map(function(c) { return c.id }) }

  function test_filters_combine() {
    compare(ids(C.filterCards(deck, { query: "hsts", state: null, tags: [], deck: null })), ["a"])
    compare(ids(C.filterCards(deck, { query: "", state: "suspended", tags: [], deck: null })), ["c"])
    compare(ids(C.filterCards(deck, { query: "", state: null, tags: ["security"], deck: "Web" })), ["a", "b"])
    // Markup is not searchable text.
    compare(ids(C.filterCards(deck, { query: "<b>", state: null, tags: [], deck: null })), [])
  }

  // Several tags narrow: a card must carry every one.
  function test_tags_combine_with_and() {
    compare(ids(C.filterCards(deck, { query: "", tags: ["security", "web"] })), ["a"])
    compare(ids(C.filterCards(deck, { query: "", tags: ["security", "rails"] })), [])
    compare(ids(C.filterCards(deck, { query: "" })), ["a", "b", "c"])
  }

  // Counted over what a filter left, less the tags already picked: what is
  // still worth picking, and how many cards each pick would leave.
  function test_tag_counts_follow_the_filter() {
    var left = C.filterCards(deck, { query: "", tags: ["security"] })
    compare(C.tagCounts(left, ["security"]), [{ tag: "web", count: 1 }])
  }

  function test_match_tags() {
    var counts = [{ tag: "websecurity", count: 5 }, { tag: "Security", count: 3 }, { tag: "rails", count: 1 }]
    compare(C.matchTags(counts, "").length, 3)
    compare(C.matchTags(counts, "sec").map(function(c) { return c.tag }), ["Security", "websecurity"])
    compare(C.matchTags(counts, " #SEC").map(function(c) { return c.tag }), ["Security", "websecurity"])
    compare(C.matchTags(counts, "zz"), [])
  }

  function test_counts() {
    compare(C.tagCounts(deck), [{ tag: "security", count: 2 }, { tag: "rails", count: 1 }, { tag: "web", count: 1 }])
    compare(C.stateCounts(deck), [{ state: "new", count: 1 }, { state: "review", count: 1 }, { state: "suspended", count: 1 }])
    compare(C.deckNames(deck), ["Rails", "Web"])
  }

  function test_cards_for_a_page() {
    compare(ids(C.cardsForPage({ flashcardIds: ["b", "zz", "a"], tags: [] }, deck)), ["b", "a"])
    compare(ids(C.cardsForPage({ flashcardIds: [], tags: ["Rails"] }, deck)), ["c"])
    compare(C.cardsForPage({ flashcardIds: [], tags: [] }, deck), [])
  }

  function test_filter_summary() {
    compare(C.filterSummary({ query: "", state: "", tags: [], deck: "" }), "")
    compare(C.filterSummary({ query: " etag ", state: "review", tags: ["http"], deck: "Web" }), "review · Web · #http · “etag”")
    compare(C.filterSummary({ query: "", state: "", tags: ["web", "csp"], deck: "" }), "#web · #csp")
    compare(C.selectedFilters({ query: "x", state: "new", tags: ["web"], deck: "" }),
            [{ kind: "state", value: "new", label: "new" }, { kind: "tag", value: "web", label: "#web" }])
  }
}
