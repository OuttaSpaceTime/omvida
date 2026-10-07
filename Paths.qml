pragma Singleton
import QtQuick
import Quickshell

// Where things are, in one place. bin/omvida exports both: OMVIDA_ROOT is this
// checkout, OMVIDA_STUDY_DIR the study repo (the wiki, its logs, its skills,
// and where Claude Code is opened). The tests point the second at a fixture.
QtObject {
  readonly property string home: Quickshell.env("HOME")
  readonly property string root: Quickshell.env("OMVIDA_ROOT") || String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string studyDir: Quickshell.env("OMVIDA_STUDY_DIR") || home + "/Code/study"
  readonly property string deckBin: root + "/bin/omvida-deck"
  readonly property string wikiBin: root + "/bin/omvida-wiki"
  readonly property string ankiSync: studyDir + "/scripts/anki-sync"
}
