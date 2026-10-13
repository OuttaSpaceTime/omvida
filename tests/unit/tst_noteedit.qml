import QtQuick
import QtTest
import "../../NoteEdit.js" as E

// The note dialog's markdown editing (NoteEdit.js has the why).
TestCase {
  name: "NoteEdit"

  function test_enter_carries_a_list_on() {
    var t = "- one"
    var e = E.continueList(t, t.length)
    compare(e.text, "- one\n- ")
    compare(e.start, e.text.length)
    compare([e.from, e.to, e.insert], [5, 5, "\n- "], "an insert, so undo keeps it")
    compare(E.continueList("  * a", 5).text, "  * a\n  * ", "keeps the indent and marker")
    compare(E.continueList("1. a", 4).text, "1. a\n2. ", "numbers count up")
    compare(E.continueList("9) a", 4).text, "9) a\n10) ")
    compare(E.continueList("- [x] done", 10).text, "- [x] done\n- [ ] ", "a fresh checkbox")
  }

  function test_enter_on_an_empty_item_ends_the_list() {
    var t = "- one\n- "
    var e = E.continueList(t, t.length)
    compare(e.text, "- one\n")
    compare(e.start, 6)
  }

  function test_enter_mid_item_splits_it() {
    compare(E.continueList("- onetwo", 5).text, "- one\n- two")
  }

  function test_plain_lines_are_not_ours() {
    compare(E.continueList("just text", 9), null)
    compare(E.continueList("-not a list", 11), null)
    compare(E.continueList("", 0), null)
  }

  function test_wrap_and_unwrap() {
    var b = E.wrap("make this bold", 5, 9, "**")
    compare(b.text, "make **this** bold")
    compare([b.start, b.end], [7, 11], "the same words stay selected")
    var u = E.wrap(b.text, b.start, b.end, "**")
    compare(u.text, "make this bold")
    compare([u.start, u.end], [5, 9])
    var empty = E.wrap("ab", 1, 1, "*")
    compare(empty.text, "a**b")
    compare([empty.start, empty.end], [2, 2], "the cursor between the pair")
  }

  function test_italic_does_not_eat_a_bold_marker() {
    var t = "**word**"
    compare(E.wrap(t, 2, 6, "*").text, "***word***")
  }

  function test_first_line() {
    compare(E.firstLine("- **Split** it\nmore"), "Split it")
    compare(E.firstLine("## Why `with_lock`?"), "Why with_lock?")
    compare(E.firstLine("> card issue, vague: x\n\nreword"), "card issue, vague: x")
    compare(E.firstLine(""), "")
  }
}
