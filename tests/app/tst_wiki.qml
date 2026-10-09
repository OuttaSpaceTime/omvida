import QtQuick

// Reading the wiki: links, anchors, folders, the panels and a page's cards.
OmvidaTest {
  name: "wiki"

  // Every topic tile on Home is as tall as a full one (name and three
  // pages), whatever it holds. Security has two pages (web fills up to three
  // once test_a_new_page_appears has run), so a tile sized to its own text
  // would have only its padding around the text.
  function test_topic_tiles_share_a_full_tile_height() {
    app.setScreen("home")
    var web = item("topic:web"), security = item("topic:security")
    compare(web.height, security.height)
    var text = security.children[0]
    verify(security.height - text.implicitHeight > text.y * 2,
           "the tile leaves room for a third page: " + security.height + " vs text " + text.implicitHeight)
  }

  // The graph is laid out before it is first shown, not on screen: settling
  // there, it grew and was refitted every frame, and jumped about.
  function test_the_graph_opens_already_laid_out() {
    app.setScreen("graph")
    var view = item("graphView")
    verify(view.layout !== null, "a layout")
    verify(view.layout.alpha < 0.02, "at rest on first show: alpha " + view.layout.alpha)
    compare(view.settling, false)
  }

  // The graph rail opens the graph screen around the page, and its left
  // edge drags it wider.
  function test_the_graph_rail_goes_full_screen_and_resizes() {
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.loadedPath === "web/http-caching" }, 8000)
    wiki.graphOpen = true
    var handle = item("graphRailHandle")
    var rail = handle.parent
    var before = rail.width
    mouseDrag(handle, handle.width / 2, handle.height / 2, -60, 0)
    tryVerify(function() { return rail.width > before }, 2000, "wider: " + rail.width + " from " + before)

    click("graphFullScreen")
    tryCompare(app, "currentScreen", "graph")
    verify(item("graphScreen").local, "around the open page")
  }

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

  function test_a_folder_lists_its_pages() {
    app.openFolder("web")
    tryCompare(app, "wikiFolder", "web")
    compare(item("folderTitle").text, "web")
    click("folderPage:web/http-caching")
    tryCompare(app, "wikiPath", "web/http-caching")
  }

  // No page links Cookies, but it shares the web tag with HTTP Caching, so
  // the graph around HTTP Caching shows it, hung off on a dashed line.
  // Same-Origin Policy shares no tag with Cookies and leaves it out.
  function test_the_local_graph_shows_pages_that_share_a_tag() {
    app.openPage("web/http-caching", "")
    app.openGraph(true)
    var view = item("graphView")
    function ids() { return view.shown.nodes.map(function(n) { return n.id }) }
    tryVerify(function() { return ids().indexOf("web/cookies") >= 0 }, 3000, ids().join())
    compare(view.related("web/http-caching")["web/cookies"], true)
    compare(view.related("web/cookies")["web/http-caching"], true)
    app.openPage("security/same-origin-policy", "")
    app.openGraph(true)
    tryVerify(function() { return ids().indexOf("security/same-origin-policy") >= 0 }, 3000)
    verify(ids().indexOf("web/cookies") < 0, ids().join())
  }

  // Both panels fold to a strip, by their chevron or by `[` and `]` (typed
  // as text: on a German layout `[` is AltGr+8), and the page takes the
  // room. The graph starts folded.
  function test_the_side_panels_fold_away() {
    wiki.graphOpen = false   // the default; an earlier test opened it
    app.openPage("web/http-caching", "")
    tryVerify(function() { return wiki.loadedPath === "web/http-caching" }, 8000)
    item("graphExpand")
    var flick = item("wikiFlick"), before = flick.width

    click("sidePanelCollapse")
    verify(!wiki.sideOpen)
    item("sidePanelExpand")
    verify(flick.width > before, "the page took the panel's room: " + flick.width + " from " + before)
    // The folded strip's glyph stays faint until the pointer is on it.
    var expand = item("sidePanelExpand")
    mouseMove(flick, flick.width / 2, flick.height / 2)
    // A string: a color read into a var is a live reference to the property.
    var quiet = String(expand.tint)
    mouseMove(expand, expand.width / 2, expand.height / 2)
    tryVerify(function() { return String(expand.tint) !== quiet }, 2000, "hover darkens the glyph")
    mouseMove(flick, flick.width / 2, flick.height / 2)
    tryVerify(function() { return String(expand.tint) === quiet }, 2000, "leaving fades it back")
    key("[")
    verify(wiki.sideOpen, "[ opens it again")

    key("]")
    verify(wiki.graphOpen, "] opens the graph")
    item("graphRailHandle")
    click("graphCollapse")
    verify(!wiki.graphOpen)
    click("graphExpand")
    verify(wiki.graphOpen)
    key("]")
    verify(!wiki.graphOpen)
    compare(flick.width, before)
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
