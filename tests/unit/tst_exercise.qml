import QtQuick
import QtTest
import "../../Exercise.js" as E

TestCase {
  name: "Exercise"

  function test_lines_cut_at_newlines_and_number_the_code() {
    compare(E.lines([{ text: "a = 1\nb = " }, { blank: 0, multiline: false }, { text: "\nc" }]), [
      [{ text: "a = 1", segment: 0 }],
      [{ text: "b = ", segment: 1 }, { blank: 0, multiline: false }],
      [{ text: "c", segment: 2 }]
    ])
  }

  function test_a_blank_line_of_code_stays() {
    compare(E.lines([{ text: "a\n\nb" }]).length, 3)
    compare(E.lines([{ text: "a\n\nb" }])[1], [])
  }

  function test_a_multiline_blank_takes_a_line_of_its_own() {
    compare(E.lines([{ text: "def f\n" }, { blank: 0, multiline: true }, { text: "end" }]), [
      [{ text: "def f", segment: 0 }],
      [{ blank: 0, multiline: true }],
      [{ text: "end", segment: 1 }]
    ])
  }

  function test_segments_are_the_code_by_number() {
    compare(E.segments([{ text: "x = " }, { blank: 0, multiline: false }, { text: " + 1\ny" }]), ["x = ", " + 1", "y"])
  }

  function test_verdict_says_the_result() {
    compare(E.verdict(null), "")
    compare(E.verdict({ status: "pass", cases: [{ pass: true }] }), "matches")
    compare(E.verdict({ status: "wrong", cases: [{ pass: false }] }), "doesn't match")
    compare(E.verdict({ status: "wrong", cases: [{ pass: true }, { pass: false }, { pass: false }] }), "1 of 3 match")
    compare(E.verdict({ status: "error", cases: [] }), "error")
    compare(E.verdict({ status: "timeout", cases: [] }), "stopped")
    compare(E.verdict({ status: "incomplete", cases: [] }), "fill in the blanks")
  }

  function test_the_error_above_the_cases_is_what_stopped_them() {
    compare(E.errorText(null), "")
    compare(E.errorText({ error: "syntax", cases: [] }), "syntax")
    compare(E.errorText({ error: null, cases: [{ error: "raised" }] }), "", "a case shows its own")
  }

  function test_printed_keeps_warnings_on_show() {
    compare(E.printed(null), "")
    compare(E.printed({ output: "hi\n", stderr: "" }), "hi")
    compare(E.printed({ output: "hi\n", stderr: "careful\n" }), "hi\ncareful")
    compare(E.printed({ output: "hi", stderr: "careful" }), "hi\ncareful")
  }

  // ---- what waits for a check -------------------------------------------------
  function test_a_run_stopped_before_any_case_is_stopped_early() {
    verify(E.stoppedEarly({ status: "error", error: "main.rb:4: syntax errors found", cases: [] }))
  }

  function test_an_error_in_a_case_and_the_runner_failing_are_not() {
    verify(!E.stoppedEarly({ status: "error", error: null, cases: [{ error: "NoMethodError" }] }))
    verify(!E.stoppedEarly({ status: "timeout", error: "stopped after 5s", cases: [] }))
    verify(!E.stoppedEarly({ status: "unavailable", error: "no ruby", cases: [] }))
    verify(!E.stoppedEarly({ status: "pass", error: null, cases: [] }))
    verify(!E.stoppedEarly(null))
  }

  // ---- indenting a block --------------------------------------------------------
  function test_a_block_starts_at_the_body_of_what_comes_before_it() {
    compare(E.bodyIndent("def double(n)\n"), "  ")
    compare(E.bodyIndent("class A\n  def b\n"), "    ")
    compare(E.bodyIndent("x = 1\n"), "", "no body to be in")
    compare(E.bodyIndent(""), "")
  }

  function test_each_blank_gets_a_start_of_its_own() {
    compare(E.startAnswers([{ text: "def f\n" }, { blank: 0, multiline: true }, { text: "end" }], 1), ["  "])
    compare(E.startAnswers([{ text: "a." }, { blank: 0, multiline: false }, { text: " b" }], 1), [""], "an inline blank starts empty")
    compare(E.startAnswers([{ text: "x" }], 2), ["", ""], "a prediction has no blanks in its parts")
  }

  function test_enter_keeps_the_lines_indentation() {
    compare(E.enterEdit("  x = 1"), { dedent: 0, insert: "\n  " })
    compare(E.enterEdit("x = 1"), { dedent: 0, insert: "\n" })
    compare(E.enterEdit(""), { dedent: 0, insert: "\n" })
  }

  function test_enter_goes_one_further_after_a_line_that_opens_something() {
    ["  list.each do", "  list.each do |x|", "  list.each { |x|", "  if x", "  x = [", "  foo(", "  case y", "  def z"].forEach(function(line) {
      compare(E.enterEdit(line).insert, "\n    ", line)
    })
  }

  function test_a_whole_line_opens_nothing() {
    ["  list.each { |x| x }", "  def f; 1; end", "  x = [1]", "  if_true", "  undo", "  x # do"].forEach(function(line) {
      compare(E.enterEdit(line).insert, "\n  ", line)
    })
  }

  function test_a_closing_line_comes_back_out() {
    compare(E.enterEdit("  list.each do\n    x\n    end"), { dedent: 2, insert: "\n  " })
    compare(E.enterEdit("  a = [\n    1\n    ]"), { dedent: 2, insert: "\n  " })
    compare(E.enterEdit("  if x\n    y\n    else"), { dedent: 2, insert: "\n    " }, "and else opens the next part")
    compare(E.enterEdit("  loop do\n    end"), { dedent: 2, insert: "\n  " }, "an empty body")
  }

  function test_a_closing_line_moved_out_by_hand_stays() {
    compare(E.enterEdit("  list.each do\n    x\n  end"), { dedent: 0, insert: "\n  " })
    compare(E.enterEdit("end"), { dedent: 0, insert: "\n" }, "with nothing above it")
    compare(E.enterEdit("  end"), { dedent: 0, insert: "\n  " }, "with nothing above to go by")
  }

  function test_endpoint_is_no_end() {
    compare(E.enterEdit("  a\n  endpoint"), { dedent: 0, insert: "\n  " })
  }

  function test_backspace_takes_an_indent_whole() {
    compare(E.backspaceCount("x\n    "), 2)
    compare(E.backspaceCount("x\n   "), 1, "back to the stop")
    compare(E.backspaceCount("  "), 2)
    compare(E.backspaceCount(" "), 1)
    compare(E.backspaceCount(""), 1)
    compare(E.backspaceCount("  x"), 1, "past the indentation it is one letter")
    compare(E.backspaceCount("x\n"), 1, "the newline")
  }

  function test_tab_goes_to_the_next_stop() {
    compare(E.tabSpaces(""), "  ")
    compare(E.tabSpaces(" "), " ")
    compare(E.tabSpaces("  "), "  ")
    compare(E.tabSpaces("x\n"), "  ")
  }

  function test_shift_tab_takes_at_most_one_indent() {
    compare(E.outdentCount("    x", ""), 2)
    compare(E.outdentCount("a\n ", "b\nc"), 1)
    compare(E.outdentCount("x", ""), 0)
  }
}
