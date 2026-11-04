pragma ComponentBehavior: Bound
import QtQuick

import "StudyPages.js" as StudyPages

// The wiki pages study has touched, for the wiki's side panel, stacked across
// sessions and app restarts until cleared, one by one or all: nothing else
// takes a page off. [{ path, title, lapsed }], StudyPages.js has the rules, and
// the wiki service the file (study_pages.py). A logic object: StudySession says
// which card was rated, and it holds no phases.
//
// A page joins when one of its cards is rated, not when the session ends: a
// session left unfinished, or an app closed mid-way, has been studied all the
// same. They were the summary's related pages at first, added by finish() and
// held in memory, so a session that was never finished left nothing, each left
// at most its top three, and closing the app lost the lot.
//
// Asked for the rated card alone, not for the whole session so far: a page
// cleared mid-session stays cleared until another of its cards is rated, where
// asking for the session would bring it straight back. An undone rating leaves
// its page, as the card was looked at, and takes back only its red tint.
QtObject {
  id: root

  required property JsonLineClient wikiService
  // Whether this card was failed in this session (StudySession has the ratings).
  required property var lapsedHere
  signal saveFailed(string text)

  property var pages: []
  // A list never read must not be written: an index still being built can fail
  // the first load, and the next rating would then save an empty list over the
  // file. So nothing is saved until a load has worked, and a rating tries again.
  property bool loaded: false

  function load(then) {
    root.wikiService.call("studyPages", {}, function(err, list) {
      if (err) return
      root.pages = list
      root.loaded = true
      if (then) then()
    })
  }
  Component.onCompleted: load()

  // Every change goes through here and is saved as it happens, there being no
  // moment that is sure to come later. An assignment to `pages` is memory only,
  // which is what loading wants, and bin/shot -R's studypages.
  function set(list) {
    if (!root.loaded || list === root.pages) return
    root.pages = list
    root.wikiService.call("saveStudyPages", { pages: list }, function(err) {
      if (err) root.saveFailed(err)
    })
  }

  // lapsedHere is read when the answer comes, so a rating undone while it was on
  // its way doesn't leave its tint behind.
  function touch(cardId) {
    if (!root.loaded) {
      root.load(function() { root.touch(cardId) })
      return
    }
    root.wikiService.call("pagesOfCard", { cardId: cardId }, function(err, found) {
      if (err || found.length === 0) return
      root.set(StudyPages.touched(root.pages, found, cardId, root.lapsedHere(cardId)))
    })
  }

  function ratingUndone(cardId) {
    if (!root.lapsedHere(cardId)) root.set(StudyPages.unlapsed(root.pages, cardId))
  }

  function drop(path) { root.set(StudyPages.dropped(root.pages, path)) }
  function clear() { root.set([]) }
}
