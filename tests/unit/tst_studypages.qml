import QtQuick
import QtTest
import "../../StudyPages.js" as P

TestCase {
  name: "StudyPages"

  function entry(path, lapsed) { return { path: path, title: path.toUpperCase(), lapsed: lapsed || [] } }
  function found(path) { return { path: path, title: path.toUpperCase() } }
  function paths(list) { return list.map(function(e) { return e.path }) }

  function test_a_rated_cards_pages_go_on_top_and_the_rest_stay() {
    var out = P.touched([entry("a"), entry("b")], [found("c"), found("d")], "card", false)
    compare(paths(out), ["c", "d", "a", "b"])
  }

  function test_a_page_touched_again_moves_up_and_appears_once() {
    compare(paths(P.touched([entry("a"), entry("b")], [found("b")], "card", false)), ["b", "a"])
  }

  function test_a_page_keeps_the_lapses_of_its_other_cards() {
    var out = P.touched([entry("a", ["old"])], [found("a")], "new", true)
    compare(out[0].lapsed, ["old", "new"])
    out = P.touched(out, [found("a")], "new", true)
    compare(out[0].lapsed, ["old", "new"], "a card counts once")
  }

  function test_a_later_session_getting_the_card_right_takes_its_lapse_off() {
    compare(P.touched([entry("a", ["x", "y"])], [found("a")], "x", false)[0].lapsed, ["y"])
  }

  function test_a_title_comes_from_the_wiki_as_it_now_is() {
    var out = P.touched([{ path: "a", title: "old", lapsed: [] }], [{ path: "a", title: "new" }], "card", false)
    compare(out[0].title, "new")
  }

  function test_unlapsed_takes_one_card_off_every_page() {
    var out = P.unlapsed([entry("a", ["x", "y"]), entry("b", ["x"]), entry("c")], "x")
    compare(out.map(function(e) { return e.lapsed }), [["y"], [], []])
  }

  function test_unlapsed_of_a_card_behind_no_tint_is_the_list_itself() {
    var list = [entry("a", ["y"])]
    verify(P.unlapsed(list, "x") === list)
  }

  function test_dropped_takes_only_that_page() {
    compare(paths(P.dropped([entry("a"), entry("b"), entry("c")], "b")), ["a", "c"])
  }

  function test_lists_are_never_edited_in_place() {
    var list = [entry("a", ["x"])]
    P.touched(list, [found("a")], "y", true)
    P.unlapsed(list, "x")
    P.dropped(list, "a")
    compare(list.length, 1)
    compare(list[0].lapsed, ["x"])
  }
}
