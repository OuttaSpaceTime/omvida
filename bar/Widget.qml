import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Omvida's bar icon: the alpha of the Omvida mark, and beside it the number
// of reviews due, coloured by the deck's pressure verdict the way the panel's
// chip is: the bar's text colour when it is ok, the accent at warn, urgent at
// pause. The number is gone when nothing is due, so the bar is quiet until
// there is work. A notification pill on the alpha's corner was tried first;
// at bar size it crowded the glyph and read as an alert even when the deck
// was fine. Left click opens the progress panel, right click starts a study
// session in Omvida, middle click refreshes.
//
// The figures come from `bin/omvida-overview` in the Omvida checkout, which
// prints flashcard-mcp's overview: the same numbers, from the same code, as
// the app and the /study skill. It runs on a timer (the settings'
// refreshIntervalSec) and whenever the panel opens; it is about a second of
// node, so never per frame.
//
// The panel follows the first-party pattern (omarchy.weather): a Panel.qml
// loaded here, and this widget standing in for it as the bar's popout
// identity, so Tab between panels and `omarchy-shell shell toggle` work.
BarWidget {
  id: root
  moduleName: "omvida.bar"

  property var overview: null
  property string loadError: ""

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string omvidaRoot: Model.expandHome(setting("omvidaRoot", "~/Code/omvida"), home)
  readonly property int refreshMs: Math.max(60, Number(setting("refreshIntervalSec", 600))) * 1000
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string badge: Model.badge(overview)
  // The verdict's colour, as bar/Panel.qml's verdictColor: shown, never
  // recomputed from the count.
  readonly property color verdictColor: {
    var v = overview ? overview.pressure.verdict : "ok"
    if (v === "pause") return Color.urgent
    if (v === "warn") return Color.accent
    return foreground
  }

  function refresh() {
    if (!overviewProc.running) overviewProc.running = true
  }

  // An argv, never a shell string: bar.run takes one, and a path with a space
  // or a `$` in the omvidaRoot setting would be split or expanded by it.
  function launch(args) {
    Quickshell.execDetached([root.omvidaRoot + "/bin/omvida"].concat(args))
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function handlePress(b) {
    if (b === Qt.RightButton) root.launch(["study"])
    else if (b === Qt.MiddleButton) root.refresh()
    else root.togglePanel()
  }
  // The bar's per-slot pointer layer routes clicks through this (ompom.bar).
  function triggerPress(b) { root.handlePress(b) }

  implicitWidth: button.implicitWidth
  implicitHeight: barSize

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: overviewProc
    command: [root.omvidaRoot + "/bin/omvida-overview", "6"]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = Model.parse(text)
        if (o) { root.overview = o; root.loadError = "" }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (String(text).trim() !== "") root.loadError = String(text).trim().split("\n").pop()
    }
  }

  Timer {
    interval: root.refreshMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  IpcHandler {
    target: "omvida.bar"
    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  Item {
    id: button
    anchors.fill: parent
    implicitWidth: row.implicitWidth + Style.space(16)
    implicitHeight: root.barSize

    Row {
      id: row
      anchors.centerIn: parent
      spacing: Style.space(5)

      // Black on transparent, tinted to the bar's text colour, the way
      // ompom.bar tints Omvision's. As tall as the bar's body text: the glyph
      // is cropped tight, so a title-sized box drew it larger than the text.
      Item {
        width: Style.font.body
        height: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
        Image {
          id: markSvg
          anchors.fill: parent
          source: Qt.resolvedUrl("icons/omvida-alpha.svg")
          // Uncached: a plugin reload after the mark changes must draw the new file.
          cache: false
          sourceSize.width: parent.width
          sourceSize.height: parent.height
          smooth: true
          visible: false
        }
        MultiEffect {
          anchors.fill: parent
          source: markSvg
          colorization: 1.0
          colorizationColor: root.foreground
          brightness: 1.0
        }
      }

      Text {
        visible: root.badge !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: root.badge
        color: root.verdictColor
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        font.weight: Font.DemiBold
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onPressed: function(mouse) { root.handlePress(mouse.button) }
    }
  }
}
