pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "Cards.js" as Cards
import "Format.js" as Format
import "Session.js" as Session

// A past session's page, opened from Home's past sessions (app.nav.openSession):
// the summary a session ends on (SessionSummary, `past`), then every card it
// rated, as the Cards screen's tiles, each with its ratings in order, so what
// lapsed and what came back reads card by card.
//
// Built from the deck server's account of the session (Store.sessions,
// every review in its window), since the app keeps no record once a session
// is over. A page rather than a dialog: the list is the point, and a dialog
// gave it a scroller inside a box.
Item {
  id: root
  objectName: "sessionScreen"

  required property App app
  readonly property Store store: app.store
  // Store.sessions holds the newest few; one that has dropped out of them
  // since its page was opened (Alt+← back to it) has nothing to show.
  // Only while shown: the sessions are re-read on every rating in Study,
  // and a hidden page would rebuild its tiles and ask for related pages.
  readonly property var session: root.visible
    ? store.sessions.find(function(s) { return s.id === root.app.nav.sessionId }) || null : null
  readonly property var rec: session ? Session.fromPast(session) : Session.empty()
  readonly property var cards: Session.ratedCards(rec)
  property var related: []
  property string relatedFor: ""

  // The related pages are asked for again when the deck re-reads the
  // sessions, but only cleared for another session, so they don't flicker.
  onRecChanged: {
    var id = root.session ? root.session.id : ""
    if (id !== root.relatedFor) { root.related = []; root.relatedFor = id }
    if (id === "" || root.rec.reviews.length === 0) return
    root.store.wiki.call("related", { studied: Session.studiedCards(root.rec), limit: 3 }, function(err, pages) {
      if (!err && root.relatedFor === id) root.related = pages
    })
  }

  // ---- the window's status line ---------------------------------------------
  readonly property var statusSegments: root.session ? [{ text: Format.sessionWhen(root.session.startTime) }] : []
  // Search, add and back come with every screen (StatusLine).
  readonly property var statusHints: []

  GlideFlickable {
    anchors.fill: parent
    contentHeight: col.implicitHeight + Theme.space3xl * 2
    ScrollBar.vertical: ScrollBar {}

    Column {
      id: col
      x: Theme.pageX(root.width)
      y: Theme.space3xl
      width: Theme.pageWidth(root.width)
      spacing: Theme.sectionGap

      UiText {
        visible: !root.session
        text: "This session is no longer among the recent ones."
        color: Theme.faint
      }

      // Which session, above its figures (the status line says it too, but
      // small, at the bottom).
      SectionLabel {
        visible: !!root.session
        text: root.session ? "Session · " + Format.sessionWhen(root.session.startTime) : ""
      }

      SessionSummary {
        visible: !!root.session
        width: parent.width
        app: root.app
        past: true
        // The deck's accuracy, as Home's row shows it: not recounted here.
        summaryData: root.session ? Object.assign(Session.summary(root.rec), { accuracy: root.session.accuracy }) : null
        // Open notes only, as Home counts them: one resolved since is done.
        noted: root.session ? root.store.notedIds(root.session.noted) : []
        related: root.related
      }

      // The cards as the Cards screen draws them (CardGrid, CardTile), each
      // with the ratings it was given here. A click shows its back in the
      // front's place, and another the front, as a page's cards do
      // (PageCardsDialog).
      Column {
        visible: root.cards.length > 0
        width: parent.width
        spacing: Theme.spaceSm
        SectionLabel { divided: true; text: "Cards" }
        CardGrid {
          id: grid
          width: parent.width
          Repeater {
            model: root.cards
            delegate: CardTile {
              id: tile
              required property var modelData
              property bool revealed: false
              // Gone if deleted since: its front is still known, its back not.
              readonly property var known: root.store.cardsById[tile.modelData.id] || null
              objectName: "sessionCard:" + tile.modelData.id
              width: grid.cellWidth
              height: grid.tileHeight
              card: tile.known
              caption: tile.known ? Cards.tileCaption(tile.known, true, !!root.store.notes[tile.modelData.id]) : "deleted"
              ratings: tile.modelData.ratings
              text: tile.revealed && tile.known ? Format.stripHtml(tile.known.back) : tile.modelData.front
              marked: tile.revealed
              onClicked: if (tile.known) tile.revealed = !tile.revealed
            }
          }
        }
      }
    }
  }
}
