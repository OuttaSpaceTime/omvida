import QtQuick

// Screen keys work from every screen, the study answer box included, and
// never type into it.
OmvidaTest {
  name: "shortcuts"

  function test_ctrl_digits_switch_screens() {
    key(Qt.Key_3, Qt.ControlModifier); tryCompare(app, "currentScreen", "wiki")
    key(Qt.Key_4, Qt.ControlModifier); tryCompare(app, "currentScreen", "cards")
    key(Qt.Key_5, Qt.ControlModifier); tryCompare(app, "currentScreen", "graph")
    key(Qt.Key_1, Qt.ControlModifier); tryCompare(app, "currentScreen", "home")
  }

  function test_out_of_the_answer_box_and_back() {
    key(Qt.Key_2, Qt.ControlModifier)
    tryCompare(study, "phase", "answering", 15000)
    var field = item("answerField")
    tryVerify(function() { return field.activeFocus }, 3000)
    type("half an answer")
    key(Qt.Key_3, Qt.ControlModifier)
    tryCompare(app, "currentScreen", "wiki")
    compare(field.text, "half an answer", "nothing typed by the shortcut")
    type("x")
    compare(field.text, "half an answer", "the hidden answer box lost the keyboard")
    key(Qt.Key_2, Qt.ControlModifier)
    tryVerify(function() { return field.activeFocus }, 3000, "back on Study, the answer box has it again")
    compare(field.text, "half an answer", "the answer survived the trip")
  }

  function test_slash_opens_search_outside_study() {
    key(Qt.Key_1, Qt.ControlModifier)
    key(Qt.Key_Slash)
    tryVerify(function() { return searchPalette.opened })
    key(Qt.Key_Escape)
    tryVerify(function() { return !searchPalette.opened })
  }
}
