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
    compare(ids(C.filterCards(deck, { query: "hsts", state: null, tag: null, deck: null })), ["a"])
    compare(ids(C.filterCards(deck, { query: "", state: "suspended", tag: null, deck: null })), ["c"])
    compare(ids(C.filterCards(deck, { query: "", state: null, tag: "security", deck: "Web" })), ["a", "b"])
    // Markup is not searchable text.
    compare(ids(C.filterCards(deck, { query: "<b>", state: null, tag: null, deck: null })), [])
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
    compare(C.filterSummary({ query: "", state: "", tag: "", deck: "" }), "")
    compare(C.filterSummary({ query: " etag ", state: "review", tag: "http", deck: "Web" }), "review · Web · #http · “etag”")
    compare(C.filterSummary({ query: "", state: "", tag: "web", deck: "" }), "#web")
    compare(C.selectedFilters({ query: "x", state: "new", tag: "web", deck: "" }),
            [{ kind: "state", value: "new", label: "new" }, { kind: "tag", value: "web", label: "#web" }])
  }
}
