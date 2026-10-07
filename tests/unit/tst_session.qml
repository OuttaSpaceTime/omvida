import QtQuick
import QtTest
import "../../Session.js" as S

TestCase {
  name: "Session"

  function card(id, tags) { return { id: id, front: "Front <b>" + id + "</b>", tags: tags || [] } }

  function test_summary_counts_unique_cards_repeats_and_lapses() {
    var r = S.empty()
    r = S.shown(r, 1000)
    r = S.rated(r, card("a"), 1, 3, false, 2000)
    r = S.rated(r, card("b"), 3, 3, false, 3000)
    r = S.rated(r, card("a"), 3, 0, true, 61000)
    var s = S.summary(r)
    compare(s.cards, 2)
    compare(s.repeats, 1)
    compare(s.reviews, 3)
    compare(s.lapses, ["Front a"])
    compare(s.overrides, 1)
    compare(Math.round(s.accuracy * 100), 67)
    compare(s.minutes, 1)
  }

  function test_records_are_never_edited_in_place() {
    var a = S.empty()
    var b = S.rated(a, card("x"), 3, 3, false, 5)
    compare(a.reviews.length, 0)
    compare(b.reviews.length, 1)
    compare(S.shown(b, 9).firstShownMs, 9)
    compare(S.shown(S.shown(b, 9), 20).firstShownMs, 9)
  }

  function test_studied_cards_marks_lapsed_once() {
    var r = S.rated(S.rated(S.empty(), card("a", ["web"]), 1, 0, false, 1), card("a", ["web"]), 3, 0, true, 2)
    compare(S.studiedCards(r), [{ id: "a", tags: ["web"], lapsed: true }])
  }

  function test_log_entry() {
    var r = S.explored(S.leech(S.rated(S.shown(S.empty(), 0), card("a"), 3, 3, false, 1), card("a"), 6, "kept"), "web/x")
    var e = S.logEntry(r, { verdict: "calibrated", marginal: false, true_retention: 0.85 })
    compare(e.cardsReviewed, 1)
    compare(e.calibration, "calibrated (true retention 85%)")
    compare(e.leeches, ["\"Front a\" (6 lapses) → kept"])
    compare(e.wikiExplored, ["web/x"])
  }
}
