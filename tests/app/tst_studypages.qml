import QtQuick

// The pages study has touched, in the wiki's side panel: they join as cards are
// rated, stack across sessions, finished or not, stay across a restart, and go
// only when cleared. A file of its own: it rewrites which cards are due, and the
// list is on disk in the sandbox's HOME.
OmvidaTest {
  name: "studypages"

  readonly property string caching: "web/http-caching"
  readonly property string csrf: "security/csrf"
  // A card of each page (the fixture wiki's flashcard_ids).
  readonly property var cardOf: ({ "web/http-caching": "fixturecard0001", "security/csrf": "fixturecard0003" })

  function paths() { return study.fromStudy.pages.map(function(p) { return p.path }) }
  function saved() {
    var t = readFile(home + "/.local/state/omvida/study-pages.json")
    return t === null ? [] : JSON.parse(t).map(function(p) { return p.path })
  }

  // A session of just these cards, the first of them up.
  function sessionOf(ids) {
    sqlWrite("UPDATE Card SET due = '2099-01-01T00:00:00.000+00:00'")
    sqlWrite("UPDATE Card SET due = '2020-01-01T00:00:00.000+00:00' WHERE id IN ('" + ids.join("','") + "')")
    startSession()
  }
  // Rated, and the next card up with the keyboard, if there is a next.
  function rateAndWait(n) {
    rate(n)
    tryVerify(function() { return study.phase !== "submitting" && study.phase !== "loading" }, 8000)
    if (study.phase === "answering") tryVerify(function() { return item("answerField").activeFocus }, 3000)
  }
  function endSession() {
    study.endNow()
    tryCompare(study, "phase", "done", 5000)
  }

  function init() {
    if (study.phase !== "idle" && study.phase !== "done") study.endNow()
    study.fromStudy.clear()
  }

  // Left with a card still to go: nothing here calls finish().
  function test_a_rating_adds_its_page_with_the_session_unfinished() {
    sessionOf([cardOf[caching], cardOf[csrf]])
    var page = study.card.id === cardOf[caching] ? caching : csrf
    compare(study.fromStudy.pages.length, 0, "nothing before a rating")
    rateAndWait(3)
    tryVerify(function() { return paths().indexOf(page) !== -1 }, 5000, "joined on the rating: " + paths())
    compare(paths(), [page])
    verify(study.running, "the session is still going")
    tryVerify(function() { return saved().length === 1 && saved()[0] === page }, 5000, "on disk already")
  }

  function test_sessions_stack_newest_first() {
    sessionOf([cardOf[caching]])
    rateAndWait(3)
    tryVerify(function() { return study.fromStudy.pages.length === 1 }, 5000)
    endSession()
    sessionOf([cardOf[csrf]])
    rateAndWait(3)
    tryVerify(function() { return study.fromStudy.pages.length === 2 }, 5000, "stacked: " + paths())
    compare(paths(), [csrf, caching])
    endSession()
  }

  function test_clearing_one_page_takes_only_that_page_and_it_stays_cleared() {
    sessionOf([cardOf[caching], "fixturecard0002", cardOf[csrf]])
    while (study.phase === "answering") rateAndWait(3)
    tryCompare(study, "phase", "done", 8000)
    tryVerify(function() { return study.fromStudy.pages.length === 2 }, 5000, "both: " + paths())
    var cleared = paths()[0], kept = paths()[1]
    study.fromStudy.drop(cleared)
    compare(paths(), [kept])
    tryVerify(function() { return saved().length === 1 && saved()[0] === kept }, 5000)
    wait(300)
    compare(paths(), [kept], "nothing brings it back on its own")
  }

  // Cleared mid-session, with its card already rated: the session's later ratings
  // and its end leave it off. Only a rating of one of its cards puts it back.
  function test_a_page_cleared_mid_session_returns_only_when_touched_again() {
    sessionOf([cardOf[caching], cardOf[csrf]])
    var first = study.card.id === cardOf[caching] ? caching : csrf
    var second = first === caching ? csrf : caching
    rateAndWait(3)
    tryVerify(function() { return paths().indexOf(first) !== -1 }, 5000)
    study.fromStudy.drop(first)
    tryVerify(function() { return study.phase === "answering" && item("answerField").activeFocus }, 8000)
    rateAndWait(3)
    tryVerify(function() { return paths().indexOf(second) !== -1 }, 5000)
    tryCompare(study, "phase", "done", 8000)
    wait(300)
    compare(paths(), [second], "neither the next rating nor the end brought it back")

    sessionOf([cardOf[first]])
    rateAndWait(3)
    tryVerify(function() { return study.fromStudy.pages.length === 2 }, 5000, "touched again: " + paths())
    compare(paths(), [first, second])
    endSession()
  }

  // A list that could not be read is not written over.
  function test_nothing_is_saved_until_a_load_has_worked() {
    study.fromStudy.set([{ path: csrf, title: "CSRF", lapsed: [] }])
    tryVerify(function() { return saved().length === 1 }, 5000)
    study.fromStudy.loaded = false
    study.fromStudy.pages = []
    study.fromStudy.set([])
    wait(300)
    compare(saved().length, 1, "the file is as it was")
    study.fromStudy.load()
    tryVerify(function() { return study.fromStudy.loaded && study.fromStudy.pages.length === 1 }, 5000)
  }

  // What the next run of the app reads: the same list, off the disk.
  function test_the_list_survives_a_restart() {
    var list = [{ path: csrf, title: "CSRF", lapsed: ["fixturecard0003"] },
                { path: caching, title: "HTTP Caching", lapsed: [] }]
    study.fromStudy.set(list)
    tryVerify(function() { return saved().length === 2 }, 5000)
    study.fromStudy.pages = []
    study.fromStudy.load()
    tryVerify(function() { return study.fromStudy.pages.length === 2 }, 5000)
    compare(JSON.stringify(study.fromStudy.pages), JSON.stringify(list))
  }

  // The panel shows them, and its buttons are what clears them.
  function test_the_panels_buttons_clear_them() {
    study.fromStudy.set([{ path: csrf, title: "CSRF", lapsed: [] }, { path: caching, title: "HTTP Caching", lapsed: [] }])
    app.nav.openPage(caching, "")
    tryCompare(app.nav, "currentScreen", "wiki")
    item("studyPage:" + csrf)
    // ✕ shows on the open page's row without a hover.
    click("studyPageDrop:" + caching)
    tryVerify(function() { return paths().length === 1 && paths()[0] === csrf }, 2000)
    tryVerify(function() { return saved().length === 1 && saved()[0] === csrf }, 5000)
    click("studyPagesClear")
    tryCompare(study.fromStudy.pages, "length", 0)
    tryVerify(function() { return saved().length === 0 }, 5000)
    tryVerify(function() { return findNamed(target, "studyPages") === null }, 2000, "the section goes when empty")
  }

  // Again paints the page red, and the repeat's Good doesn't take it off.
  function test_a_lapse_stays_on_its_page_through_the_repeat() {
    sessionOf([cardOf[csrf]])
    rateAndWait(1)
    tryVerify(function() { return study.fromStudy.pages.length === 1 && study.fromStudy.pages[0].lapsed.length === 1 }, 5000, JSON.stringify(study.fromStudy.pages))
    tryVerify(function() { return study.phase === "answering" || study.phase === "done" }, 8000)
    if (study.phase === "answering") {
      tryVerify(function() { return item("answerField").activeFocus }, 3000)
      rateAndWait(3)
      tryVerify(function() { return study.phase !== "loading" }, 8000)
      wait(300)
      compare(study.fromStudy.pages[0].lapsed, [cardOf[csrf]])
      endSession()
    }
    // A later session getting it right does.
    sessionOf([cardOf[csrf]])
    rateAndWait(3)
    tryVerify(function() { return study.fromStudy.pages[0].lapsed.length === 0 }, 5000, JSON.stringify(study.fromStudy.pages))
    endSession()
  }

  // Taking the Again back takes the red off; the page stays, the card was seen.
  function test_undoing_a_lapse_takes_only_its_tint_off() {
    sessionOf([cardOf[csrf]])
    rateAndWait(1)
    tryVerify(function() { return study.fromStudy.pages.length === 1 && study.fromStudy.pages[0].lapsed.length === 1 }, 5000, JSON.stringify(study.fromStudy.pages))
    tryVerify(function() { return study.atRest }, 8000)
    study.undo()
    tryVerify(function() { return study.fromStudy.pages.length === 1 && study.fromStudy.pages[0].lapsed.length === 0 }, 5000, JSON.stringify(study.fromStudy.pages))
    tryCompare(study, "phase", "revealed", 8000)
    endSession()
  }

  // A card on no page leaves the list as it is.
  function test_a_card_on_no_page_adds_nothing() {
    sessionOf(["fixturecard0004"])
    rateAndWait(3)
    wait(300)
    compare(study.fromStudy.pages.length, 0)
    endSession()
  }
}
