import QtQuick

// Reading the wiki: links, anchors, folders, the panels and a page's cards.
OmvidaTest {
  name: "wiki"

  function test_open_a_page_and_follow_a_wikilink() {
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.page !== null && wiki.loadedPath === "web/http-caching" }, 8000)
    compare(item("pageTitle").text, "HTTP Caching")
    app.followLink("wiki:security/csrf")
    tryVerify(function() { return wiki.loadedPath === "security/csrf" }, 8000)
    compare(item("pageTitle").text, "CSRF")
    // Back returns to the first page.
    key(Qt.Key_Left, Qt.AltModifier)
    tryCompare(app, "wikiPath", "web/http-caching")
  }

  function test_a_heading_link_scrolls_to_it() {
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.loadedPath === "web/http-caching" }, 8000)
    var flick = item("wikiFlick")
    flick.contentY = 0
    app.followLink("anchor:validation")
    tryVerify(function() { return flick.contentY > 0 }, 3000, "scrolled down to Validation")
  }

  function test_a_moc_link_opens_its_folder() {
    app.followLink("folder:web")
    tryCompare(app, "wikiFolder", "web")
    compare(item("folderTitle").text, "web")
    click("folderPage:web/http-caching")
    tryCompare(app, "wikiPath", "web/http-caching")
  }

  function test_context_panel_lists_sections_and_links() {
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.loadedPath === "web/http-caching" }, 8000)
    click("panelMode:context")
    item("section:freshness")
    item("sibling:web/http-caching")
    click("panelMode:tree")
    click("tree:security")
    click("tree:security/same-origin-policy")
    tryCompare(app, "wikiPath", "security/same-origin-policy")
  }

  function test_page_cards_open_by_id_then_by_tag() {
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.loadedPath === "web/http-caching" }, 8000)
    compare(item("pageCardsButton").label, "2 cards")
    click("pageCardsButton")
    click("pageCardsFlip")
    item("flipCard")
    key(Qt.Key_Escape)
    // Same-origin policy declares no ids, so its cards come by tag.
    app.openPage("security/same-origin-policy", "")
    tryVerify(function() { return wiki.loadedPath === "security/same-origin-policy" }, 8000)
    verify(item("pageCardsButton").label.indexOf("by tag") !== -1)
  }

  // A page written while the app is open shows up without a restart.
  function test_a_new_page_appears() {
    run(["/usr/bin/sh", "-c", "printf '%s\\n' '---' 'title: Fresh Page' 'tags: [web]' 'flashcard_ids: []' '---' '' '# Fresh Page' '' 'New.' > \"$1/wiki/web/fresh-page.md\"", "sh", studyDir])
    tryVerify(function() { return app.store.pagesByPath["web/fresh-page"] !== undefined }, 10000, "the index picked it up")
  }
}
