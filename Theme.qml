pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Omvida's token singleton, taken from Omvision's (~/Code/omvision/Theme.qml),
// whose comments carry the history of each rule. Like there, it does not
// import qs.Commons, the shell's module, which a standalone `qs -p` config
// cannot reach. It reads the live omarchy theme, falls back to Flexoki Light,
// and never throws on a missing or malformed theme file.
//
// What is new here: the theme's named hues (red, green, blue...) are read too.
// The wiki needs them for syntax highlighting and topic colours, and the deck
// for its card states. All of them come from the theme rather than a fixed
// palette, so a dark theme gets its own readable versions of each.
QtObject {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string themePath: home + "/.local/state/omarchy/current/theme/colors.toml"

  // ---- Flexoki Light fallback ------------------------------------------------
  readonly property var fallback: ({
    background: "#FFFCF0", foreground: "#100F0F", accent: "#205EA6",
    red: "#AF3029", yellow: "#AD8301", orange: "#BC5215", green: "#66800B",
    cyan: "#24837B", blue: "#205EA6", magenta: "#A02F6F", mode: "light"
  })

  property string mode: fallback.mode
  property color background: fallback.background
  property color foreground: fallback.foreground
  property color accent: fallback.accent
  property color red: fallback.red
  property color yellow: fallback.yellow
  property color orange: fallback.orange
  property color green: fallback.green
  property color cyan: fallback.cyan
  property color blue: fallback.blue
  property color magenta: fallback.magenta

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function blend(fg, bg, a) {
    return Qt.rgba(fg.r * a + bg.r * (1 - a), fg.g * a + bg.g * (1 - a), fg.b * a + bg.b * (1 - a), 1)
  }

  function relativeLuminance(c) {
    function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
  }

  function contrastRatio(a, b) {
    var l1 = relativeLuminance(a), l2 = relativeLuminance(b)
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
  }

  // `base` with as little ink mixed in as still reads at `target` contrast on
  // the paper; the full ink when even that falls short. Secondary text is the
  // paper inked to 7, 5.5 and 4.5 (Omvision's rule: defined by contrast, never
  // by the theme's `muted`, which is unreadable as text on light themes).
  // Coloured text is a theme hue inked to 4.5: hues are tuned for terminals,
  // and some (Flexoki's yellow) sit at 2:1 on a light background.
  function inked(base, target) {
    if (contrastRatio(base, background) >= target) return base
    var lo = 0, hi = 1
    for (var i = 0; i < 12; i++) {
      var mid = (lo + hi) / 2
      if (contrastRatio(blend(foreground, base, mid), background) >= target) hi = mid
      else lo = mid
    }
    return blend(foreground, base, hi)
  }
  function readable(c) { return inked(c, 4.5) }

  readonly property color paper: background
  readonly property color ink: foreground
  readonly property color secondaryInk: inked(background, 7.0)
  readonly property color dim: inked(background, 5.5)
  readonly property color faint: inked(background, 4.5)
  readonly property color hairline: alpha(foreground, 0.14)
  readonly property color border: alpha(foreground, 0.40)
  readonly property color fill: alpha(foreground, 0.04)
  // Opaque: Qt's rich text draws a span's background without alpha.
  readonly property color codeFill: blend(foreground, background, 0.07)
  readonly property color hoverFill: alpha(foreground, 0.08)
  readonly property color selectedFill: alpha(foreground, 0.18)
  readonly property color accentColor: readable(accent)
  readonly property color accentFill: alpha(accent, 0.12)
  readonly property color redText: readable(red)
  readonly property color greenText: readable(green)
  readonly property color orangeText: readable(orange)
  readonly property color scrim: Qt.rgba(0, 0, 0, 0.45)

  // ---- meaning-bearing colours ---------------------------------------------
  // The four ratings, in the order of the keys that give them.
  readonly property var ratingColors: [faint, redText, orangeText, greenText, readable(blue)]
  function ratingColor(n) { return ratingColors[n] || ink }

  // Card states: the viewer's five, from theme hues.
  function stateColor(state) {
    switch (state) {
    case "new": return readable(blue)
    case "learning": return orangeText
    case "review": return greenText
    case "relearning": return redText
    default: return faint
    }
  }

  // Pressure and calibration verdicts.
  function verdictColor(v) {
    if (v === "pause" || v === "over-difficult") return redText
    if (v === "warn" || v === "under-difficult") return orangeText
    if (v === "ok" || v === "calibrated") return greenText
    return dim
  }

  // A topic's colour, from a stable hash of its top-level folder, as the
  // viewer's lib/colors.ts does, but over the theme's hues. Seven hues for a
  // wiki of fourteen topics collided, so each hue also comes in a deeper
  // shade (blended toward the ink), which doubles the palette.
  readonly property var topicHues: [blue, green, orange, magenta, cyan, red, yellow]
  // Cached per topic: the graph asks for every node's colour on every frame,
  // and readable() is a bisection. loadColors() empties it.
  property var topicCache: ({})
  function topicColor(folder) {
    var topic = String(folder || "").split("/")[0] || "wiki"
    var cached = topicCache[topic]
    if (cached !== undefined) return cached
    var hash = 0
    for (var i = 0; i < topic.length; i++) hash = (hash * 31 + topic.charCodeAt(i)) >>> 0
    var n = topicHues.length, k = hash % (n * 2)
    var hue = topicHues[k % n]
    var c = readable(k < n ? hue : blend(foreground, hue, 0.35))
    topicCache[topic] = c
    return c
  }

  // ---- rich text ------------------------------------------------------------
  // The `<style>` every page block and card face is drawn with. The wiki
  // service sends HTML with class names only (backend/omvida_backend/render.py),
  // so a theme switch recolours what is on screen without re-rendering it.
  readonly property string richTextStyle: "<style>"
    + "a{color:" + accentColor + ";text-decoration:none}"
    + "code{font-family:monospace;background-color:" + codeFill + "}"
    + ".broken{color:" + redText + "}"
    + "th{background-color:" + blend(foreground, background, 0.05) + "}"
    + "table{border-color:" + blend(foreground, background, 0.2) + "}"
    + "pre{font-family:monospace}"
    + ".kw{color:" + readable(magenta) + "}"
    + ".ty{color:" + readable(cyan) + "}"
    + ".fn{color:" + readable(blue) + "}"
    + ".bi{color:" + readable(cyan) + "}"
    + ".str{color:" + greenText + "}"
    + ".num{color:" + orangeText + "}"
    + ".cm{color:" + faint + ";font-style:italic}"
    + ".op{color:" + dim + "}"
    + ".var{color:" + readable(blue) + "}"
    + ".tag{color:" + readable(blue) + "}"
    + ".at{color:" + orangeText + "}"
    + ".del{color:" + redText + "}"
    + ".ins{color:" + greenText + "}"
    + ".hd{color:" + accentColor + ";font-weight:bold}"
    + "</style>"

  // ---- type scale (Omvision's) -----------------------------------------------
  readonly property string fontFamily: "monospace"
  readonly property int captionSize: 12
  readonly property int bodySmallSize: 14
  readonly property int bodySize: 15
  readonly property int subtitleSize: 16
  readonly property int titleSize: 17
  readonly property real labelTracking: 1   // small caps labels, SectionLabel
  readonly property int headingSize: 24
  readonly property int displaySize: 32
  // A card's front is what the whole Study screen is for, so it is set at
  // the reading size of Omvision's journal, the largest text in the app.
  readonly property int cardFrontSize: 20
  readonly property int answerSize: 16

  // ---- spacing scale (Omvision's: never type a pixel number) --------------------
  readonly property int spaceXxs: 2
  readonly property int spaceXs: 4
  readonly property int spaceSm: 8
  readonly property int spaceMd: 12
  readonly property int spaceLg: 16
  readonly property int spaceXl: 24
  readonly property int space2xl: 32
  readonly property int space3xl: 48
  readonly property int space4xl: 64

  readonly property int panelPadding: space3xl
  readonly property int sectionGap: space2xl
  readonly property real proseLineHeight: 1.4

  // ---- geometry -----------------------------------------------------------------
  readonly property int radius: 0
  readonly property int controlHeight: 32
  readonly property int smallControlHeight: 24
  readonly property int dialogWidth: 560
  readonly property int hairlineWidth: 1
  readonly property int borderWidth: 1
  readonly property int dialogBorderWidth: 2
  readonly property int selectionBarWidth: 3
  readonly property int tooltipDelay: 400
  readonly property int windowWidth: 1440
  readonly property int windowHeight: 900
  readonly property int windowMinWidth: 720
  readonly property int windowMinHeight: 560
  readonly property int railWidth: 64
  readonly property int railMarkSize: 26
  readonly property int railRowHeight: 40
  readonly property int railIconSize: 20
  readonly property int railBarWidth: 2
  readonly property int topBarHeight: 56
  // The wiki's two side panels: the tree or context on the left, the page's
  // sections and links on the right (the viewer's 280px sidebar).
  readonly property int sidePanelWidth: 280
  readonly property int dotSize: 6
  readonly property int listRowHeight: 32
  readonly property int answerMinHeight: 120
  readonly property int statBarHeight: 8
  readonly property int sparkHeight: 48
  readonly property int sparkBarWidth: 18
  readonly property int cardFaceMinHeight: 220
  readonly property int cardGridCellWidth: 320
  readonly property int paletteWidth: 720
  readonly property int paletteMaxHeight: 560
  readonly property int menuWidth: 220
  readonly property int chipHitSlop: spaceXs

  // The reading column: the viewer's max-w-3xl, in characters of the body
  // font so it follows the type size.
  readonly property int readingColumns: 82
  property FontMetrics bodyMetrics: FontMetrics {
    font.family: root.fontFamily
    font.pixelSize: root.bodySize
  }
  readonly property int pageMeasure: Math.round(bodyMetrics.advanceWidth("0") * readingColumns)

  function pageWidth(areaWidth) {
    return Math.max(0, Math.min(pageMeasure, areaWidth - panelPadding * 2))
  }
  function pageX(areaWidth) {
    return Math.max(panelPadding, Math.round((areaWidth - pageWidth(areaWidth)) / 2))
  }

  // ---- motion ----------------------------------------------------------------------
  readonly property int flipDuration: 260
  readonly property int fadeDuration: 120
  readonly property int toastDuration: 4000
  readonly property int graphTickInterval: 16
  // Over a typing gap, so a word is one search, not one per letter.
  readonly property int searchDebounce: 250
  readonly property int wikiPollInterval: 3000

  // ---- loading the theme ------------------------------------------------------------
  function parseToml(text) {
    var out = {}
    var lines = String(text || "").replace(/\r\n/g, "\n").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].replace(/\s+$/, "").match(/^([A-Za-z0-9_-]+)\s*=\s*"([^"]*)"\s*$/)
      if (m) out[m[1]] = m[2]
    }
    return out
  }

  // Unparseable text keeps the last good theme (a reload mid-switch can find
  // the file half-written); it only means the fallback before any has loaded.
  function loadColors(text) {
    var t = parseToml(text)
    if (!t.background || !t.foreground || !t.accent) return
    background = t.background
    foreground = t.foreground
    accent = t.accent
    var names = ["red", "yellow", "orange", "green", "cyan", "blue", "magenta"]
    for (var i = 0; i < names.length; i++) root[names[i]] = t[names[i]] || fallback[names[i]]
    mode = t.mode || "light"
    topicCache = ({})
  }

  // A theme switch is pushed by the theme-set hook (~/Code/system,
  // dot_config/omarchy/hooks/theme-set.d/omvida), which calls `theme reload`
  // on every running Omvida; the watch covers a theme edited in place.
  // Omvision's Theme.qml explains why both.
  property FileView colorsFile: FileView {
    id: colorsFile
    path: root.themePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadColors(text())
  }

  property IpcHandler themeIpc: IpcHandler {
    target: "theme"
    function reload(): void { colorsFile.reload() }
  }
}
