import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The panel under the Omvida icon: a glance at where studying stands, then
// the way in. The count due with the pressure verdict as a small chip; one
// sentence on what clears it; how the deck has matured, as one thin bar;
// retention with the calibration verdict; the next few reviews; and one
// primary action, Study now, beside two icon buttons. Verdicts are the deck's
// own words. The week chart and the section headers it had before were cut:
// the panel is opened for a glance, and Omvida's Home has the rest.
//
// Keys (PanelKeyCatcher): Enter studies now, Esc closes, Tab moves to the
// neighbouring bar panel.
Panel {
  id: root
  moduleName: "omvida.bar"
  ipcTarget: "omvida.bar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var o: hostWidget ? hostWidget.overview : null
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.62)
  readonly property color faint: Qt.rgba(fg.r, fg.g, fg.b, 0.42)
  readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.12)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    if (hostWidget) hostWidget.refresh()
    root.controller.show()
  }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function studyNow() { root.close(); if (hostWidget) hostWidget.launch(["study"]) }

  function verdictColor(v) {
    if (v === "pause" || v === "over-difficult") return Color.urgent
    if (v === "warn" || v === "under-difficult") return Color.accent
    return root.fg
  }

  // The maturity bar in the bar's own colours: the theme gives the shell a
  // foreground and an accent, not a palette, so stages are told apart by
  // strength, new cards in the accent.
  function maturityColor(key) {
    if (key === "new") return Color.accent
    if (key === "learning") return Qt.rgba(fg.r, fg.g, fg.b, 0.3)
    if (key === "familiar") return Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    return fg
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem ? root.anchorItem : root
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(col.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onReturnRequested: root.studyNow()
      onActivateRequested: root.studyNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: col
        width: parent.width
        spacing: Style.space(14)

        // ---- the count, and its verdict ----
        Item {
          width: parent.width
          height: countRow.height
          Row {
            id: countRow
            spacing: Style.space(10)
            Text {
              id: count
              text: root.o ? root.o.pressure.flashcardsDue : "–"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }
            Text {
              anchors.baseline: count.baseline
              text: Model.headline(root.o)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }
          }
          // The verdict as a chip, only when it asks for something: "ok" is
          // the absence of news.
          Rectangle {
            visible: root.o !== null && root.o.pressure.verdict !== "ok"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: verdict.implicitWidth + Style.space(14)
            height: verdict.implicitHeight + Style.space(4)
            color: "transparent"
            border.width: 1
            border.color: verdict.color
            Text {
              id: verdict
              anchors.centerIn: parent
              text: root.o ? root.o.pressure.verdict : ""
              color: root.o ? root.verdictColor(root.o.pressure.verdict) : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
        Text {
          visible: text !== ""
          width: parent.width
          wrapMode: Text.Wrap
          text: root.o ? Model.glanceLine(root.o)
                       : (root.hostWidget && root.hostWidget.loadError !== "" ? root.hostWidget.loadError : "")
          color: root.o ? root.dim : Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // ---- the deck's maturity: one bar, its numbers under it ----
        Column {
          visible: root.o !== null
          width: parent.width
          spacing: Style.space(6)
          Row {
            id: maturityBar
            width: parent.width
            spacing: Style.space(2)
            readonly property var parts: Model.maturityParts(root.o).filter(function(p) { return p.n > 0 })
            Repeater {
              model: maturityBar.parts
              delegate: Rectangle {
                required property var modelData
                width: Math.max(Style.space(2), (maturityBar.width - maturityBar.spacing * (maturityBar.parts.length - 1)) * modelData.f)
                height: Style.space(5)
                color: root.maturityColor(modelData.key)
              }
            }
          }
          Row {
            spacing: Style.space(12)
            Repeater {
              model: Model.maturityParts(root.o)
              delegate: Text {
                required property var modelData
                textFormat: Text.StyledText
                text: "<b>" + modelData.n + "</b> " + modelData.key
                color: root.faint
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
        Text {
          visible: text !== ""
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.StyledText
          text: Model.retentionLine(root.o, root.verdictColor(root.o ? root.o.calibration.verdict : "").toString())
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        // ---- next up ----
        Rectangle { visible: pending.count > 0; width: parent.width; height: 1; color: root.hairline }
        Text {
          visible: pending.count > 0
          text: "NEXT UP"
          color: root.faint
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: Style.space(1)
        }
        Column {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            id: pending
            model: root.o ? root.o.pending.slice(0, 4) : []
            delegate: Text {
              required property var modelData
              width: col.width
              elide: Text.ElideRight
              text: modelData.text
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
          Text {
            readonly property int more: root.o ? root.o.pressure.flashcardsDue - pending.count : 0
            visible: more > 0
            text: "+ " + more + " more"
            color: root.faint
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // ---- the way in: one primary action, two icon buttons ----
        Rectangle { width: parent.width; height: 1; color: root.hairline }
        Row {
          id: actions
          width: parent.width
          spacing: Style.space(8)
          Button {
            width: actions.width - openBtn.width - cardsBtn.width - actions.spacing * 2
            text: "Study now"
            tooltipText: "Enter"
            background: Color.accent
            foreground: Color.background
            onClicked: root.studyNow()
          }
          Button {
            id: openBtn
            iconText: "\u{F03CC}"
            tooltipText: "Open Omvida"
            bordered: true
            onClicked: { root.close(); if (root.hostWidget) root.hostWidget.launch([]) }
          }
          Button {
            id: cardsBtn
            iconText: "\u{F0638}"
            tooltipText: "Browse cards"
            bordered: true
            onClicked: { root.close(); if (root.hostWidget) root.hostWidget.launch(["cards"]) }
          }
        }
      }
    }
  }
}
