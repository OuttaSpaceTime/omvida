import QtQuick

// A rest day (Easy Days at Minimum, today's weekday set so in the fixture
// deck's Config, as anki-sync would mirror it): Study opens on nothing, Enter
// starts nothing, and A studies ahead, today's share of the week (the deck
// server's study-ahead.ts). The fixture's 3 due reviews and 1 new card make a
// week of 4, so the share is a seventh: 1 review, already due.
OmvidaTest {
  name: "restday"

  // Easy Days in the deck, as anki-sync writes them; the app is not told.
  function setEasyDays(days) {
    var json = JSON.stringify(days)
    sqlWrite("INSERT INTO Config (id, easyDays) VALUES ('default', '" + json + "') ON CONFLICT(id) DO UPDATE SET easyDays = excluded.easyDays")
  }

  function restToday() {
    var days = [1, 1, 1, 1, 1, 1, 1]
    days[(new Date().getDay() + 6) % 7] = 0   // Anki's list is Monday first
    setEasyDays(days)
    app.store.refreshDeck()
    tryVerify(function() { return study.restDay }, timeout, "the overview says rest day")
  }

  function test_a_a_rest_day_opens_on_nothing_and_enter_starts_nothing() {
    restToday()
    app.startStudy()
    compare(study.phase, "idle", "coming to Study starts nothing")
    verify(item("aheadPanel").visible, "the offer is up")
    verify(findNamed(target, "startSessionButton") === null, "no plain session")
    compare(item("aheadHeadline").text, "If you have time: 1 card ahead")
    compare(item("aheadLine").text, "1 review (1 due now)")
    verify(studyView.keyList.some(function(k) { return k.keys === "a" && k.label === "study ahead" }), "the key list names A")

    key(Qt.Key_Return)
    wait(500)
    compare(study.phase, "idle", "Enter starts nothing")
  }

  // The app still thinks it a rest day (an overview from before midnight); the
  // deck server refuses the share, the day is read again, and the retry is a
  // plain session.
  function test_b_a_refused_share_reads_the_day_again_and_retries_plain() {
    restToday()
    app.startStudy()
    setEasyDays([1, 1, 1, 1, 1, 1, 1])
    key(Qt.Key_A)
    tryCompare(study, "phase", "error", 15000)
    tryVerify(function() { return !study.restDay }, timeout, "the day is read again")
    key(Qt.Key_Return)
    tryCompare(study, "phase", "answering", 15000)
    compare(study.info.ahead, false, "a plain session")
    study.endNow()
    tryCompare(study, "phase", "done", 8000)
  }

  function test_c_a_studies_the_share_then_offers_nothing_more() {
    restToday()
    app.startStudy()
    key(Qt.Key_A)
    tryCompare(study, "phase", "answering", 15000)
    compare(study.info.ahead, true, "asked for the share")
    compare(study.info.total, 1)
    study.submit(3)
    tryCompare(study, "phase", "done", 8000)

    tryCompare(item("aheadHeadline"), "text", "Today's share is studied. The rest of the day is off.", timeout)
    verify(findNamed(target, "studyAheadButton") === null, "nothing more to study ahead")
    verify(findNamed(target, "studyAgainButton") === null, "no other session on a rest day")
    key(Qt.Key_Return)
    key(Qt.Key_A)
    wait(500)
    compare(study.phase, "done", "neither Enter nor A starts anything once the share is studied")
  }

  // Coming to Study decides by an overview read today: one from yesterday is
  // read again first, and only then does a study day start a session.
  function test_d_coming_to_study_reads_a_stale_day_first() {
    restToday()
    app.store.overviewDay = "2000-01-01"
    app.startStudy()
    tryVerify(function() { return app.store.overviewCurrent() }, timeout, "read again")
    wait(500)
    compare(study.running, false, "still a rest day: nothing started")

    setEasyDays([1, 1, 1, 1, 1, 1, 1])
    app.store.overviewDay = "2000-01-01"   // the overview still says rest day
    app.startStudy()
    tryCompare(study, "phase", "answering", 15000)
    compare(study.info.ahead, false, "a study day after all: a plain session")
    study.endNow()
  }
}
