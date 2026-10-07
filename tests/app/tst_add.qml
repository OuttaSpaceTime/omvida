import QtQuick

// Add → Flashcards / Wiki entry opens Claude Code in kitty with the skill.
OmvidaTest {
  name: "add"

  function test_add_flashcards_from_a_page() {
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.loadedPath === "web/http-caching" }, 8000)
    key(Qt.Key_N, Qt.ControlModifier)
    click("add:flashcard")
    var field = item("topicField")
    compare(field.text, "HTTP Caching", "the topic starts as the open page")
    var before = kittyCalls().length
    key(Qt.Key_Return)
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    var argv = kittyCalls()[before]
    compare(argv.slice(0, 2), ["--directory", studyDir])
    compare(argv.slice(-1)[0], "/study-flashcard HTTP Caching\n\nContext: wiki page [[web/http-caching]]")
  }

  function test_add_a_wiki_entry_with_a_typed_topic() {
    app.setScreen("home")
    click("addButton")
    click("add:wiki")
    var field = item("topicField")
    field.text = ""
    type("Content Security Policy")
    var before = kittyCalls().length
    click("topicSubmit")
    tryVerify(function() { return kittyCalls().length === before + 1 }, 3000)
    compare(kittyCalls()[before].slice(-1)[0], "/study-walkthrough --write Content Security Policy")
  }
}
