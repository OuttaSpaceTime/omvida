pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

import "WikiTree.js" as WikiTree

// The wiki's left panel, the viewer's two modes:
//   context  where am I (the folder path), what is around me (the folder's
//            pages, the open page's sections under it, subfolders), and where
//            links go (outgoing, linked from)
//   tree     the whole wiki, folders collapsible, the open page's ancestors
//            opened for you
// Over both, while there are any, the pages a finished study session
// pointed to (app.studyPages): its summary lists them, but opening one leaves
// the summary behind, and the user wanted to go from one to the next. Each
// has ✕, and "clear all" drops the lot.
Rectangle {
  id: root

  property var app: null
  property string mode: "context"
  property var openFolders: ({})
  // The open page's H2s, with the anchors its rendered headings carry.
  property var sections: []
  signal sectionPicked(string anchor)
  signal collapseRequested()

  readonly property var index: app ? app.store.wikiIndex : null
  readonly property var meta: app && app.wikiPath !== "" ? app.store.pagesByPath[app.wikiPath] || null : null
  readonly property string folderPath: meta ? meta.folder : (app ? app.wikiFolder : "")

  color: Theme.paper

  // A page in a list: its topic's dot and its title, the open page in the
  // accent on the accent fill. `tint` colours the title otherwise; `reserve`
  // keeps room at the right for a control the row's user adds as a child
  // (it lies over the row's click area, being declared after it).
  component PageRow: Rectangle {
    id: pageRow
    property string path: ""
    property string title: ""
    property bool current: false
    property color tint: Theme.dim
    property real reserve: 0
    readonly property bool hovered: rowArea.containsMouse
    signal activated()
    height: Theme.listRowHeight - Theme.spaceXs
    color: current ? Theme.accentFill : (hovered ? Theme.hoverFill : "transparent")
    MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pageRow.activated() }
    Row {
      x: Theme.spaceLg
      width: parent.width - Theme.spaceLg * 2 - pageRow.reserve
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.spaceSm
      Rectangle { width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2; color: Theme.topicColor(pageRow.path); anchors.verticalCenter: parent.verticalCenter }
      UiText {
        width: parent.width - Theme.dotSize - Theme.spaceSm
        text: pageRow.title
        elide: Text.ElideRight
        font.pixelSize: Theme.bodySmallSize
        color: pageRow.current ? Theme.accentColor : pageRow.tint
      }
    }
  }

  // The tree flattened into rows, honouring which folders are open.
  function treeRows(folder, depth, out) {
    folder.folders.forEach(function(f) {
      out.push({ kind: "folder", path: f.path, title: f.name, depth: depth, count: f.count, open: !!root.openFolders[f.path] })
      if (root.openFolders[f.path]) root.treeRows(f, depth + 1, out)
    })
    folder.pages.forEach(function(p) { out.push({ kind: "page", path: p.path, title: p.title, depth: depth }) })
    return out
  }

  function toggleFolder(path) {
    var o = Object.assign({}, root.openFolders)
    if (o[path]) delete o[path]
    else o[path] = true
    root.openFolders = o
  }

  // Open the ancestors of whatever page is shown.
  onMetaChanged: if (meta && meta.folder !== "") {
    var o = Object.assign({}, root.openFolders), acc = "", opened = false
    meta.folder.split("/").forEach(function(seg) {
      acc = acc ? acc + "/" + seg : seg
      if (!o[acc]) { o[acc] = true; opened = true }
    })
    if (opened) root.openFolders = o   // a new object rebuilds every tree row
  }

  Rectangle { anchors.right: parent.right; width: Theme.hairlineWidth; height: parent.height; color: Theme.hairline }

  Row {
    id: modes
    x: Theme.spaceLg
    y: Theme.spaceLg
    spacing: Theme.spaceXs
    Chip { objectName: "panelMode:context"; label: "Context"; selected: root.mode === "context"; onActivated: root.mode = "context" }
    Chip { objectName: "panelMode:tree"; label: "Tree"; selected: root.mode === "tree"; onActivated: root.mode = "tree" }
  }
  // Folds the panel to a strip at the window's edge (WikiScreen keeps the
  // strip and the `[` key that does the same).
  PlainButton {
    objectName: "sidePanelCollapse"
    anchors.right: parent.right
    anchors.rightMargin: Theme.spaceLg
    anchors.verticalCenter: modes.verticalCenter
    icon: "collapseLeft"
    tip: "Hide the panel  ["
    onActivated: root.collapseRequested()
  }

  GlideFlickable {
    anchors.top: modes.bottom
    anchors.topMargin: Theme.spaceMd
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    contentHeight: panelCol.implicitHeight + Theme.spaceXl
    ScrollBar.vertical: ScrollBar {}

    Column {
      id: panelCol
      width: parent.width

      // ---- from study --------------------------------------------------------
      Column {
        id: studyCol
        objectName: "studyPages"
        visible: root.app !== null && root.app.studyPages.length > 0
        width: parent.width
        spacing: Theme.spaceXs
        Item {
          width: parent.width
          height: Theme.smallControlHeight
          SectionLabel { x: Theme.spaceLg; anchors.verticalCenter: parent.verticalCenter; text: "From study" }
          PlainButton {
            objectName: "studyPagesClear"
            // Its words end on the panel's text edge, as the rows' notes do.
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceLg
            anchors.verticalCenter: parent.verticalCenter
            label: "clear all"
            onActivated: root.app.clearStudyPages()
          }
        }
        Repeater {
          model: root.app ? root.app.studyPages : []
          delegate: PageRow {
            id: studyRow
            required property var modelData
            objectName: "studyPage:" + studyRow.modelData.path
            width: studyCol.width
            path: studyRow.modelData.path
            title: studyRow.modelData.title
            current: root.app.wikiPath === studyRow.modelData.path
            tint: studyRow.modelData.lapsed > 0 ? Theme.redText : Theme.dim
            reserve: drop.width + Theme.spaceSm
            onActivated: root.app.openPage(studyRow.modelData.path, "")
            // Shown on the row's hover (and on the open page's row), so a
            // list of ✕ does not stand beside every title.
            PlainButton {
              id: drop
              objectName: "studyPageDrop:" + studyRow.modelData.path
              anchors.right: parent.right
              anchors.rightMargin: Theme.spaceLg
              anchors.verticalCenter: parent.verticalCenter
              opacity: studyRow.hovered || drop.hovered || studyRow.current ? 1 : 0
              icon: "close"
              tip: "Drop from this list"
              onActivated: root.app.dropStudyPage(studyRow.modelData.path)
            }
          }
        }
        // The rule under the list, with air on both sides.
        Item {
          width: parent.width
          height: Theme.spaceSm * 2 + Theme.hairlineWidth
          Rectangle { x: Theme.spaceLg; y: Theme.spaceSm; width: parent.width - Theme.spaceLg * 2; height: Theme.hairlineWidth; color: Theme.hairline }
        }
      }

      // ---- tree ------------------------------------------------------------
      Column {
        id: treeCol
        visible: root.mode === "tree"
        width: parent.width
        Repeater {
          model: root.mode === "tree" && root.index ? root.treeRows(root.index.tree, 0, []) : []
          delegate: Rectangle {
            id: treeRow
            required property var modelData
            objectName: "tree:" + treeRow.modelData.path
            width: treeCol.width
            height: Theme.listRowHeight - Theme.spaceXs
            readonly property bool current: treeRow.modelData.kind === "page" && root.app.wikiPath === treeRow.modelData.path
            color: current ? Theme.accentFill : (tArea.containsMouse ? Theme.hoverFill : "transparent")
            Row {
              x: Theme.spaceLg + treeRow.modelData.depth * Theme.spaceMd
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - x - Theme.spaceSm
              spacing: Theme.spaceXs
              Glyph {
                icon: treeRow.modelData.kind === "folder" ? (treeRow.modelData.open ? "chevronDown" : "chevronRight") : ""
                width: Theme.bodySmallSize
                font.pixelSize: Theme.bodySmallSize
                color: Theme.faint
                anchors.verticalCenter: parent.verticalCenter
              }
              Rectangle {
                visible: treeRow.modelData.kind === "page"
                width: Theme.dotSize; height: Theme.dotSize; radius: Theme.dotSize / 2
                color: Theme.topicColor(treeRow.modelData.path)
                anchors.verticalCenter: parent.verticalCenter
              }
              UiText {
                width: parent.width - Theme.bodySmallSize * 3
                text: treeRow.modelData.title + (treeRow.modelData.kind === "folder" ? "  " + treeRow.modelData.count : "")
                elide: Text.ElideRight
                font.pixelSize: Theme.bodySmallSize
                color: treeRow.current ? Theme.accentColor : (treeRow.modelData.kind === "folder" ? Theme.secondaryInk : Theme.dim)
                anchors.verticalCenter: parent.verticalCenter
              }
            }
            MouseArea {
              id: tArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: treeRow.modelData.kind === "folder" ? root.toggleFolder(treeRow.modelData.path) : root.app.openPage(treeRow.modelData.path, "")
              onDoubleClicked: if (treeRow.modelData.kind === "folder") root.app.openFolder(treeRow.modelData.path)
            }
          }
        }
      }

      // ---- context -------------------------------------------------------------
      Column {
        id: ctxCol
        visible: root.mode === "context"
        width: parent.width
        spacing: Theme.spaceXs

        readonly property var folder: WikiTree.findFolder(root.index ? root.index.tree : null, root.folderPath)

        SectionLabel { x: Theme.spaceLg; text: "You are here"; topPadding: Theme.spaceSm }
        Column {
          x: Theme.spaceLg
          width: parent.width - Theme.spaceLg * 2
          UiText {
            text: "wiki"
            font.pixelSize: Theme.bodySmallSize
            color: Theme.dim
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.app.openFolder("") }
          }
          Repeater {
            model: root.folderPath === "" ? [] : root.folderPath.split("/")
            delegate: UiText {
              id: crumb
              required property var modelData
              required property int index
              leftPadding: Theme.spaceMd + crumb.index * Theme.spaceMd
              text: "└ " + crumb.modelData
              font.pixelSize: Theme.bodySmallSize
              color: Theme.dim
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.app.openFolder(root.folderPath.split("/").slice(0, crumb.index + 1).join("/"))
              }
            }
          }
          UiText {
            visible: root.meta !== null
            width: parent.width
            elide: Text.ElideRight
            leftPadding: Theme.spaceMd + (root.folderPath === "" ? 0 : root.folderPath.split("/").length) * Theme.spaceMd
            text: "└ " + (root.meta ? root.meta.title : "")
            font.pixelSize: Theme.bodySmallSize
            font.bold: true
          }
        }

        SectionLabel {
          x: Theme.spaceLg
          divided: true
          ruleGap: Theme.spaceMd
          text: root.folderPath === "" ? "Topics" : root.folderPath.split("/").pop()
        }
        Repeater {
          model: ctxCol.folder ? ctxCol.folder.pages : []
          delegate: Column {
            id: siblingItem
            required property var modelData
            width: ctxCol.width
            PageRow {
              objectName: "sibling:" + siblingItem.modelData.path
              width: parent.width
              path: siblingItem.modelData.path
              title: siblingItem.modelData.title
              current: root.app.wikiPath === siblingItem.modelData.path
              onActivated: root.app.openPage(siblingItem.modelData.path, "")
            }
            // The open page's sections, under its own row.
            Repeater {
              model: root.app.wikiPath === siblingItem.modelData.path ? root.sections : []
              delegate: UiText {
                id: sectionItem
                required property var modelData
                objectName: "section:" + sectionItem.modelData.anchor
                x: Theme.spaceLg + Theme.spaceXl
                width: ctxCol.width - x - Theme.spaceSm
                height: Theme.listRowHeight - Theme.spaceSm
                verticalAlignment: Text.AlignVCenter
                text: sectionItem.modelData.text
                elide: Text.ElideRight
                font.pixelSize: Theme.captionSize
                color: secArea.containsMouse ? Theme.ink : Theme.faint
                MouseArea { id: secArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sectionPicked(sectionItem.modelData.anchor) }
              }
            }
          }
        }
        Repeater {
          model: ctxCol.folder ? ctxCol.folder.folders : []
          delegate: ListRow {
            id: subfolderRow
            required property var modelData
            width: ctxCol.width
            inset: Theme.spaceLg
            title: "▸ " + subfolderRow.modelData.name
            note: subfolderRow.modelData.count
            onActivated: root.app.openFolder(subfolderRow.modelData.path)
          }
        }

        SectionLabel { x: Theme.spaceLg; divided: true; ruleGap: Theme.spaceMd; visible: root.meta && root.meta.outbound.length > 0; text: "Outgoing" }
        Repeater {
          model: root.meta ? root.meta.outbound : []
          delegate: ListRow {
            id: outgoingRow
            required property var modelData
            width: ctxCol.width
            inset: Theme.spaceLg
            title: root.app.store.pagesByPath[outgoingRow.modelData] ? root.app.store.pagesByPath[outgoingRow.modelData].title : outgoingRow.modelData
            note: outgoingRow.modelData.split("/")[0]
            onActivated: root.app.openPage(outgoingRow.modelData, "")
          }
        }
        SectionLabel { x: Theme.spaceLg; divided: true; ruleGap: Theme.spaceMd; visible: root.meta && root.meta.inbound.length > 0; text: "Linked from" }
        Repeater {
          model: root.meta ? root.meta.inbound : []
          delegate: ListRow {
            id: linkedFromRow
            required property var modelData
            width: ctxCol.width
            inset: Theme.spaceLg
            title: root.app.store.pagesByPath[linkedFromRow.modelData] ? root.app.store.pagesByPath[linkedFromRow.modelData].title : linkedFromRow.modelData
            note: linkedFromRow.modelData.split("/")[0]
            onActivated: root.app.openPage(linkedFromRow.modelData, "")
          }
        }
      }
    }
  }
}
