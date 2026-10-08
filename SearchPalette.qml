pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import "Format.js" as Format
import "Launch.js" as Launch

// Search, and asking. One box (Ctrl+K or /):
//   - pages whose title, alias or path match, as you type (no backend)
//   - the wiki's text through qmd's keyword search (~0.2s, AGENTS.md Search)
//   - the deck's cards through flashcard-mcp's search
//   - "Ask Claude": the question goes to `claude -p` in the study repo under
//     the Query Protocol (answer from memory first, then the wiki, the cards
//     and a web check, then the log entry), streamed in here. "Continue in
//     Claude" resumes that session in kitty.
// ↑/↓ choose, Enter opens, Ctrl+Enter asks, Esc closes.
//
// Those keys are named once, in a line of hints along the palette's foot, the
// way the window's status line names the screens' keys (the user's chosen
// "keyboard, no buttons in the way" style). They used to be spread over a
// note on the Ask row, the empty state's sentence and a Back button; each
// hint is clickable and runs what its key does.
Item {
  id: root

  property var app: null
  property var deck: null
  property var wikiService: null

  property bool opened: false
  property string query: ""
  property var pageHits: []
  property var textHits: []
  property var cardHits: []
  property int selected: 0
  property int searchSeq: 0
  property bool deep: false
  property string searchError: ""

  // ---- asking ----
  property bool asking: false
  property string askQuestion: ""
  property string askText: ""
  property string askStatus: ""
  property string askSession: ""
  property bool askDone: false
  property string askError: ""
  property var askBlocks: null   // the finished answer, rendered like a page

  visible: opened
  z: 40

  readonly property var rows: {
    var out = []
    pageHits.forEach(function(p) { out.push({ kind: "page", path: p.path, title: p.title, note: p.folder }) })
    textHits.forEach(function(t) {
      if (pageHits.some(function(p) { return p.path === t.path })) return
      out.push({ kind: "text", path: t.path, title: t.title, note: t.snippet })
    })
    cardHits.forEach(function(c) { out.push({ kind: "card", card: c, title: Format.stripHtml(c.front), note: c.deck }) })
    if (query.trim() !== "") out.push({ kind: "ask", title: "Ask Claude: " + query.trim(), note: "" })
    return out
  }

  function open(text) {
    root.opened = true
    root.asking = false
    field.text = text
    root.query = text
    root.selected = 0
    root.search()
    field.forceActiveFocus()
    field.selectAll()
  }

  function backToSearch() {
    if (!root.askDone) return
    root.asking = false
    field.forceActiveFocus()
  }

  // The foot line's hints, for what the palette is doing now. A hint with no
  // run() is only a reminder (↑↓ has nothing to click).
  readonly property var hints: root.asking
    ? (root.askDone ? [{ keys: "⌫", label: "back to search", run: root.backToSearch }] : [])
        .concat([{ keys: "esc", label: "close", run: root.close }])
    : [{ keys: "↑↓", label: "choose" },
       { keys: "↵", label: "open", run: function() { root.activate(root.selected) } },
       { keys: "⌃↵", label: "ask Claude", run: root.ask },
       { keys: "esc", label: "close", run: root.close }]

  function close() {
    root.opened = false
    if (askProc.running) askProc.running = false
    if (root.app) root.app.focusScreen()
  }

  // Every word must appear in the title, an alias or the path; titles that
  // start with the query rank first.
  function matchPages(q) {
    if (!root.app || !root.app.store.wikiIndex) return []
    var words = q.toLowerCase().split(/\s+/).filter(function(w) { return w !== "" })
    if (words.length === 0) return []
    var scored = []
    root.app.store.wikiIndex.pages.forEach(function(p) {
      var title = p.title.toLowerCase(), hay = (title + " " + p.aliases.join(" ") + " " + p.path).toLowerCase()
      if (!words.every(function(w) { return hay.indexOf(w) !== -1 })) return
      var s = title.indexOf(q.toLowerCase()) === 0 ? 0 : (title.indexOf(words[0]) !== -1 ? 1 : 2)
      scored.push({ s: s, p: p })
    })
    scored.sort(function(a, b) { return a.s - b.s || (a.p.title < b.p.title ? -1 : 1) })
    return scored.slice(0, 6).map(function(x) { return x.p })
  }

  function search() {
    var q = root.query.trim()
    root.pageHits = root.matchPages(q)
    root.selected = 0
    debounce.restart()
  }

  function runBackendSearch() {
    var q = root.query.trim()
    var seq = ++root.searchSeq
    root.searchError = ""
    if (q === "") { root.textHits = []; root.cardHits = []; return }
    wikiService.call("search", { query: q, mode: root.deep ? "deep" : "fast", limit: 6 }, function(err, res) {
      if (seq !== root.searchSeq) return
      if (err) { root.searchError = err; return }
      root.textHits = res.results
      if (res.error) root.searchError = res.error
    })
    deck.call("searchCards", { query: q, limit: 5 }, function(err, cards) {
      if (seq !== root.searchSeq || err) return
      root.cardHits = cards
    })
  }

  Timer { id: debounce; interval: Theme.searchDebounce; onTriggered: root.runBackendSearch() }

  function activate(i) {
    var r = root.rows[i]
    if (!r) return
    if (r.kind === "page" || r.kind === "text") root.app.openPage(r.path, "")
    else if (r.kind === "ask") root.ask()
    else if (r.kind === "card") {
      var item = resultsRep.itemAt(i)
      if (item) item.revealed = !item.revealed
    }
  }

  // ---- ask -------------------------------------------------------------------------
  function ask() {
    var q = root.query.trim()
    if (q === "") return
    root.asking = true
    root.askQuestion = q
    root.askText = ""
    root.askStatus = "thinking"
    root.askSession = ""
    root.askDone = false
    root.askError = ""
    root.askBlocks = null
    askProc.command = Launch.askArgv(q)
    askProc.running = true
    keyHolder.forceActiveFocus()
  }

  // While it streams the answer is shown as markdown; once complete it goes
  // through the wiki service's renderer, so its [[links]] resolve the way a
  // page's do and it takes the theme's colours.
  function finishAsk() {
    if (root.askDone) return
    root.askDone = true
    root.askStatus = ""
    if (root.askText === "") return
    wikiService.call("markdown", { text: root.askText }, function(err, res) { if (!err) root.askBlocks = res.blocks })
  }

  Process {
    id: askProc
    workingDirectory: Paths.studyDir
    stdout: SplitParser {
      onRead: function(line) {
        var ev = Launch.parseAskLine(line)
        if (ev.sessionId) root.askSession = ev.sessionId
        if (ev.blockStart && root.askText !== "" && !/\n\n$/.test(root.askText)) root.askText += "\n\n"
        if (ev.text) { root.askText += ev.text; root.askStatus = "" }
        if (ev.tool) root.askStatus = Launch.toolLabel(ev.tool)
        if (ev.done) { root.finishAsk(); if (ev.error) root.askError = ev.error }
      }
    }
    stderr: SplitParser { onRead: function(line) { if (line.trim() !== "") root.askError = line } }
    onExited: function(code) {
      root.finishAsk()
      if (code !== 0 && root.askError === "") root.askError = "claude exited " + code
    }
  }

  // ---- layout ------------------------------------------------------------------------
  Rectangle {
    anchors.fill: parent
    color: Theme.scrim
    MouseArea { anchors.fill: parent; onClicked: root.close() }
  }

  Rectangle {
    id: panel
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.space3xl
    width: Math.min(Theme.paletteWidth, root.width - Theme.spaceXl * 2)
    // Searching, it is as tall as its results; asking, as tall as it may be,
    // since the answer grows while it streams.
    height: Math.min(root.height - Theme.space3xl * 2,
                     root.asking ? Theme.paletteMaxHeight + Theme.space3xl * 2
                                 : Math.min(Theme.paletteMaxHeight, field.height + modeRow.height + results.implicitHeight + Theme.space2xl + Theme.spaceSm)
                                   + foot.height)
    color: Theme.paper
    // A 1px line, as the Glance overlay's frame: the scrim already parts the
    // palette from the window, so a heavier edge only added weight.
    border.color: Theme.border
    border.width: Theme.borderWidth
    MouseArea { anchors.fill: parent }

    // ---- searching ----
    Item {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: foot.top
      visible: !root.asking

      TextField {
        id: field
        objectName: "searchField"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceMd
        placeholderText: "Search pages, the wiki's text and the cards, or ask a question"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.subtitleSize
        color: Theme.ink
        placeholderTextColor: Theme.faint
        background: Rectangle { color: "transparent" }
        // Deep search is asked for per query (the chip), never left running per keystroke.
        onTextChanged: { root.query = text; root.deep = false; root.search() }
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
          else if (event.key === Qt.Key_Down) { root.selected = Math.min(root.rows.length - 1, root.selected + 1); event.accepted = true }
          else if (event.key === Qt.Key_Up) { root.selected = Math.max(0, root.selected - 1); event.accepted = true }
          else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) { root.ask(); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activate(root.selected); event.accepted = true }
        }
      }
      Rectangle { id: rule; anchors.top: field.bottom; anchors.topMargin: Theme.spaceXs; width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }

      // Pulled left by a chip's inset, so "Keyword" starts on the field's
      // text edge.
      Row {
        id: modeRow
        anchors.top: rule.bottom
        anchors.topMargin: Theme.spaceMd
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceMd - Theme.spaceSm  // a hint's inset
        spacing: Theme.spaceXs
        Chip { label: "Keyword"; selected: !root.deep; onActivated: { root.deep = false; root.runBackendSearch() } }
        Chip { objectName: "deepSearch"; label: "Deep (~6s)"; selected: root.deep; onActivated: { root.deep = true; root.runBackendSearch() } }
        UiText {
          visible: root.searchError !== ""
          text: root.searchError
          font.pixelSize: Theme.captionSize; color: Theme.redText
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      GlideFlickable {
        anchors.top: modeRow.bottom
        anchors.topMargin: Theme.spaceSm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceSm
        contentHeight: results.implicitHeight
        ScrollBar.vertical: ScrollBar {}

        Column {
          id: results
          width: parent.width
          Repeater {
            id: resultsRep
            model: root.rows
            delegate: Rectangle {
              id: rowItem
              required property var modelData
              required property int index
              property bool revealed: false
              objectName: "result:" + rowItem.modelData.kind + ":" + rowItem.index
              width: results.width
              height: rc.implicitHeight + Theme.spaceSm * 2
              color: rowItem.index === root.selected ? Theme.accentFill : (ra.containsMouse ? Theme.hoverFill : "transparent")
              Row {
                id: rc
                x: Theme.spaceMd
                y: Theme.spaceSm
                width: parent.width - Theme.spaceMd * 2
                spacing: Theme.spaceMd
                Glyph {
                  icon: rowItem.modelData.kind === "page" ? "page" : rowItem.modelData.kind === "text" ? "search" : rowItem.modelData.kind === "card" ? "cards" : "ask"
                  color: rowItem.modelData.kind === "ask" ? Theme.accentColor : Theme.faint
                  font.pixelSize: Theme.bodySize
                }
                Column {
                  width: parent.width - Theme.bodySize - Theme.spaceMd
                  spacing: Theme.spaceXxs
                  UiText {
                    width: parent.width
                    text: rowItem.modelData.title
                    elide: Text.ElideRight
                    color: rowItem.modelData.kind === "ask" ? Theme.accentColor : Theme.ink
                  }
                  UiText {
                    visible: rowItem.modelData.note !== ""
                    width: parent.width
                    text: rowItem.modelData.note
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.captionSize
                    color: Theme.faint
                  }
                  CardFace {
                    visible: rowItem.modelData.kind === "card" && rowItem.revealed
                    width: parent.width
                    html: rowItem.modelData.kind === "card" ? rowItem.modelData.card.back : ""
                    size: Theme.bodySmallSize
                    color: Theme.secondaryInk
                  }
                }
              }
              MouseArea {
                id: ra
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.selected = rowItem.index; root.activate(rowItem.index) }
              }
            }
          }
          UiText {
            visible: root.rows.length === 0 && root.query.trim() !== ""
            x: Theme.spaceMd
            topPadding: Theme.spaceMd
            text: "Nothing found."
            font.pixelSize: Theme.bodySmallSize
            color: Theme.faint
          }
        }
      }
    }

    // ---- asking ----
    Item {
      id: askView
      objectName: "askView"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: foot.top
      anchors.margins: Theme.spaceXl
      visible: root.asking

      Item {
        id: keyHolder
        Keys.onEscapePressed: root.close()
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Backspace && root.askDone) { root.backToSearch(); event.accepted = true }
        }
      }

      UiText {
        id: qText
        width: parent.width
        wrapMode: Text.Wrap
        text: root.askQuestion
        font.pixelSize: Theme.titleSize
        font.bold: true
      }
      UiText {
        id: statusText
        anchors.top: qText.bottom
        anchors.topMargin: Theme.spaceSm
        text: root.askError !== "" ? root.askError : (root.askStatus !== "" ? root.askStatus + "…" : (root.askDone ? "done · logged to today's study log" : ""))
        font.pixelSize: Theme.captionSize
        color: root.askError !== "" ? Theme.redText : Theme.faint
      }

      GlideFlickable {
        id: answerFlick
        anchors.top: statusText.bottom
        anchors.topMargin: Theme.spaceMd
        anchors.bottom: askButtons.top
        anchors.bottomMargin: Theme.spaceMd
        width: parent.width
        contentHeight: root.askBlocks !== null ? answerBlocks.implicitHeight : answerText.implicitHeight
        ScrollBar.vertical: ScrollBar {}
        PageView {
          id: answerBlocks
          objectName: "askAnswerBlocks"
          visible: root.askBlocks !== null
          width: answerFlick.width - Theme.spaceMd
          app: root.app
          blocks: root.askBlocks || []
        }
        // While it streams: the markdown as it arrives.
        UiText {
          id: answerText
          objectName: "askAnswer"
          visible: root.askBlocks === null
          width: answerFlick.width - Theme.spaceMd
          textFormat: Text.MarkdownText
          text: root.askText
          wrapMode: Text.Wrap
          linkColor: Theme.accentColor
          lineHeight: Theme.proseLineHeight
          onLinkActivated: function(link) { root.app.followLink(link) }
          HoverHandler { cursorShape: answerText.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
      }

      // One filled action, the way on (the Glance footer), with Copy and
      // Stop as quiet text beside it. Back to search is the foot's ⌫ hint.
      Row {
        id: askButtons
        anchors.bottom: parent.bottom
        spacing: Theme.spaceSm
        ActionButton {
          objectName: "askContinue"
          filled: true
          enabled: root.askSession !== "" && root.askDone
          icon: "discuss"
          label: "Continue in Claude"
          onActivated: { root.app.launch(Launch.resumeArgv(Paths.studyDir, root.askSession), "Opened Claude Code"); root.close() }
        }
        ActionButton {
          quiet: true
          label: "Copy"
          icon: "copy"
          enabled: root.askText !== ""
          onActivated: Quickshell.clipboardText = root.askText
        }
        ActionButton {
          visible: !root.askDone
          quiet: true
          label: "Stop"
          onActivated: askProc.running = false
        }
      }
    }

    // ---- the foot: the keys, as the window's status line names them ----------------
    Item {
      id: foot
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Theme.borderWidth
      height: Theme.controlHeight
      Rectangle { width: parent.width; height: Theme.hairlineWidth; color: Theme.hairline }
      Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceMd - Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: root.hints
          // The status line's hint, so a key reads the same in both places.
          delegate: PlainButton {
            id: hintItem
            required property var modelData
            objectName: "paletteHint:" + hintItem.modelData.label
            size: Theme.captionSize
            keys: hintItem.modelData.keys
            label: hintItem.modelData.label
            interactive: typeof hintItem.modelData.run === "function"
            onActivated: hintItem.modelData.run()
          }
        }
      }
    }
  }
}
