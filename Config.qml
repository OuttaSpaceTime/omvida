pragma Singleton
import QtQuick

// How often and how long: the app's timing and data limits, apart from
// Theme.qml, which is only how things look (colours, type, spacing, motion).
// They sat in Theme at first, as the one singleton there was, and a poll
// interval read as a design token there. Each is a judgement about the
// backends or the user's pace, not about drawing.
QtObject {
  // ---- the backends (Store.qml, JsonLineClient.qml) --------------------------------
  // The wiki's stamp is the mtime and size of every page, cheap; the deck's
  // is three aggregate queries, so it can run more often.
  readonly property int wikiPollInterval: 3000
  readonly property int deckPollInterval: 2000
  // The deckChanged IPC comes once per card Claude writes: a batch of new
  // cards is one reload, not one each.
  readonly property int deckPushDebounce: 300
  // How long a request may go unanswered before its caller gets an error
  // (JsonLineClient.qml): a backstop for a backend that hangs, counted from
  // when the line is written, so a slow first start does not count. Past
  // the backends' own deadlines, which say better what went wrong: a grade
  // (flashcard-mcp's GRADE_TIMEOUT_MS) and a deep qmd search
  // (omvida_backend/search.py) each give up at 60s.
  readonly property int requestTimeout: 90000

  // ---- the user's pace ----------------------------------------------------------------
  // Over a typing gap, so a word is one search, not one per letter.
  readonly property int searchDebounce: 250
  // A code card runs at a pause in the typing. A run costs about 60 ms and no
  // API call, so this only has to skip the half-typed words between.
  readonly property int codeRunDebounce: 300
  // The failed checks before a code card offers to give up, so a retrieval is
  // tried first. Execute Program waits for several; one here, as a card comes
  // around again anyway, and no answer at all counts as a try.
  readonly property int codeGiveUpAfter: 1

  // ---- deadlines ------------------------------------------------------------------------
  // The Anki sync must never hold a session hostage (AnkiSync.qml).
  readonly property int ankiSyncTimeout: 45000
  // Quitting waits this long at most for a pending session log entry: it
  // must never hang on the wiki service (App.qml).
  readonly property int quitDeadline: 2000
  // ... and this long at most for running Ctrl+Q card checks (CardCheck.qml),
  // with the window already gone: a check is a Sonnet session that may be
  // splitting a card, and one killed halfway leaves the parts and the
  // original both in the deck.
  readonly property int cardCheckQuitDeadline: 180000

  // Ctrl+Q card checks running at once (CardCheck.qml).
  readonly property int cardCheckLimit: 2

  // ---- data limits ----------------------------------------------------------------------
  // Home's past sessions: the newest few (Store.loadSessions).
  readonly property int homeSessions: 5
}
