import QtQuick
import QtTest
import "../../CardHtml.js" as C

TestCase {
  name: "CardHtml"

  function test_no_block_is_one_prose_piece() {
    compare(C.split("Why <code>nil?</code>?"), [{ kind: "prose", html: "Why <code>nil?</code>?" }])
    compare(C.split(""), [])
    compare(C.split(undefined), [])
  }

  function test_block_between_prose() {
    var out = C.split("What does this print?<br><pre><code>puts 1\nputs 2</code></pre><br>Why?")
    compare(out.length, 3)
    compare(out[0], { kind: "prose", html: "What does this print?" }, "the <br> before a block goes")
    compare(out[1], { kind: "code", text: "puts 1\nputs 2", lang: "" })
    compare(out[2], { kind: "prose", html: "Why?" })
  }

  function test_code_is_decoded_and_untagged() {
    var out = C.split("<pre><code>if a &lt; b &amp;&amp; c &gt; d<br>  x = &quot;y&quot;&#39;<span class=\"k\">z</span></code></pre>")
    compare(out.length, 1)
    compare(out[0].text, "if a < b && c > d\n  x = \"y\"'z")
  }

  function test_blank_lines_around_a_block_go_but_its_indent_stays() {
    compare(C.split("<pre>\n\n  def f\n  end\n\n</pre>")[0].text, "  def f\n  end")
  }

  function test_language_from_the_code_class() {
    compare(C.split("<pre><code class=\"language-ruby\">x</code></pre>")[0].lang, "ruby")
    compare(C.split("<pre><code class=\"hl lang-c++\">x</code></pre>")[0].lang, "c++")
  }

  function test_two_blocks() {
    var out = C.split("<pre>a</pre><pre>b</pre>")
    compare(out.map(function(p) { return p.text }), ["a", "b"])
  }
}
