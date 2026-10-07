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

  function test_plain_text_for_a_tile() {
    compare(C.plainText("What is <b>HSTS</b>?<br>Say <code>max-age</code>."), "What is HSTS? Say max-age.")
    compare(C.plainText("<pre>a  &lt;b&gt;\n  c</pre><p>x &amp; y</p>"), "a <b> c x & y")
    // Decoded once: an escaped entity stays the entity's text.
    compare(C.plainText("&amp;lt; &quot;q&quot; &#39;s&#39; &#65;"), "&lt; \"q\" 's' A")
    compare(C.plainText(""), "")
    compare(C.plainText(null), "")
  }

  function test_filter_summary() {
    compare(C.filterSummary({ query: "", state: "", tag: "", deck: "" }), "")
    compare(C.filterSummary({ query: " etag ", state: "review", tag: "http", deck: "Web" }), "review · Web · #http · “etag”")
    compare(C.filterSummary({ query: null, state: null, tag: "web", deck: null }), "#web")
  }

  function test_index_of_id() {
    compare(C.indexOfId(deck, "b"), 1)
    compare(C.indexOfId(deck, "zz"), -1)
    compare(C.indexOfId(deck, ""), -1)
    compare(C.indexOfId([], "a"), -1)
  }
}
