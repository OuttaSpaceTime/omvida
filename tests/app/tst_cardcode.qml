import QtQuick

// A <pre> block in a plain card is drawn as code (CardFace's CodeBlock), coloured
// by the wiki service's Pygments, in the language its tags name. Every card is
// rewritten in the fixture deck before the session starts, as Claude Code writes one.
OmvidaTest {
  name: "cardcode"

  readonly property string front: "Why is this not a DRY violation?<br><pre><code>def a(v)\n  check(v, :integer)\nend</code></pre>Say why."

  function setCards(tags) {
    if (study.phase !== "idle" && study.phase !== "done") study.endNow()
    sqlWrite("UPDATE Card SET due = '2020-01-01T00:00:00.000+00:00', tags = '" + tags + "', front = '"
      + front.replace(/'/g, "''") + "' WHERE suspended = 0")
  }

  function test_a_block_is_coloured_by_the_language_a_tag_names() {
    setCards("dry,ruby")
    startSession()
    var code = item("cardCode", 15000)
    tryVerify(function() { return code.html.indexOf("<span class=\"kw\">def</span>") !== -1 }, 5000, "highlighted as Ruby")
    compare(code.code, "def a(v)\n  check(v, :integer)\nend")
    verify(item("cardFront").html.indexOf("<pre") !== -1, "the card's own html is untouched")
  }

  function test_a_block_with_no_language_stays_plain_but_is_still_a_block() {
    study.endNow()
    setCards("dry,web")
    startSession()
    var code = item("cardCode", 15000)
    wait(500)
    verify(code.html.indexOf("<span") === -1, "no colour without a language")
    verify(code.html.indexOf("check(v, :integer)") !== -1, "the code is there")
  }
}
