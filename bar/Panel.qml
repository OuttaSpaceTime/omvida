import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The panel under the Omvida icon: where studying stands, and what is
// waiting. The hero is the review count with the pressure verdict; under it
// the calibration verdict, the last seven days, how the deck has matured, the
// oldest pending reviews, and the way into Omvida.
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
        spacing: Style.space(12)

        // ---- hero ----
        Row {
          spacing: Style.space(10)
          Text {
            text: root.o ? root.o.pressure.flashcardsDue : "–"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
              text: Model.headline(root.o)
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }
            Text {
              text: root.o ? "pressure " + root.o.pressure.verdict : (root.hostWidget && root.hostWidget.loadError !== "" ? root.hostWidget.loadError : "")
              color: root.o ? root.verdictColor(root.o.pressure.verdict) : Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
        Text {
          visible: text !== ""
          width: parent.width
          wrapMode: Text.Wrap
          text: Model.clearance(root.o)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // ---- progress ----
        PanelSectionHeader { text: "Progress"; foreground: root.fg; fontFamily: root.fontFamily }
        Text {
          text: "Calibration: " + Model.calibration(root.o)
          color: root.o ? root.verdictColor(root.o.calibration.verdict) : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          text: Model.today(root.o)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Row {
          spacing: Style.space(4)
          Repeater {
            model: root.o ? root.o.week : []
            delegate: Column {
              id: dayCol
              required property var modelData
              required property int index
              spacing: Style.space(2)
              Item {
                width: Style.space(16)
                height: Style.space(32)
                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: parent.height * dayCol.modelData.reviews / Model.weekPeak(root.o)
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, dayCol.index === 6 ? 0.85 : 0.4)
                }
                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: parent.height * dayCol.modelData.again / Model.weekPeak(root.o)
                  color: Color.urgent
                }
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Model.weekday(dayCol.modelData.day)
                color: dayCol.index === 6 ? root.fg : root.faint
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
        Column {
          width: parent.width
          spacing: Style.space(4)
          Row {
            width: parent.width
            Repeater {
              model: Model.maturityParts(root.o)
              delegate: Rectangle {
                required property var modelData
                required property int index
                width: col.width * modelData.f
                height: Style.space(6)
                color: index === 3 ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2 + index * 0.2)
              }
            }
          }
          Text {
            text: Model.maturityParts(root.o).map(function(p) { return p.n + " " + p.key }).join("  ")
            color: root.faint
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // ---- pending ----
        PanelSectionHeader {
          visible: root.o && root.o.pending.length > 0
          text: "Pending"
          foreground: root.fg
          fontFamily: root.fontFamily
        }
        Repeater {
          model: root.o ? root.o.pending : []
          delegate: Text {
            required property var modelData
            width: col.width
            elide: Text.ElideRight
            text: "· " + modelData.text
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        // ---- actions ----
        Row {
          spacing: Style.space(8)
          Button {
            text: "Study now"
            onClicked: root.studyNow()
          }
          Button {
            text: "Open Omvida"
            onClicked: { root.close(); if (root.hostWidget) root.hostWidget.launch([]) }
          }
          Button {
            text: "Cards"
            onClicked: { root.close(); if (root.hostWidget) root.hostWidget.launch(["cards"]) }
          }
        }
      }
    }
  }
}
