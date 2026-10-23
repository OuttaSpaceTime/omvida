import Quickshell

// Omvida: the study wiki and its flashcards, as a Quickshell app beside
// Omvision. Launched with bin/omvida (single instance; see there).
//
// Only the ShellRoot: the app is App.qml, a type of its own, so the screens
// can declare what they are handed (`required property App app`). A
// ShellRoot must be a config's root file and so can never be such a type.
ShellRoot {
  // A test, screenshot or sandbox run never reloads itself when a file
  // changes. Quickshell's reload replaces the whole object tree while a test
  // is still running inside it, and Qt aborts ("destroyed while one of its
  // QML signal handlers is in progress"): editing during bin/check crashed
  // test instances, and Quickshell restarted them offscreen. Your own Omvida
  // still reloads on save.
  settings.watchFiles: (Quickshell.env("OMVIDA_TEST") || Quickshell.env("OMVIDA_SHOT_DIR") || Quickshell.env("OMVIDA_SANDBOX") || "") === ""

  App {}
}
