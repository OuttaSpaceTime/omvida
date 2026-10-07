pragma ComponentBehavior: Bound
import QtQuick

import "Format.js" as Format
import "WikiTree.js" as WikiTree

// A folder as a page: its pages and subfolders. "" is the whole wiki, shown
// as its topics.
Column {
  id: root

  property var app: null
  property string folderPath: ""
  spacing: Theme.spaceLg

  readonly property var folder: WikiTree.findFolder(app && app.store.wikiIndex ? app.store.wikiIndex.tree : null, folderPath)

  UiText {
    objectName: "folderTitle"
    text: root.folderPath === "" ? "Wiki" : root.folderPath.split("/").pop()
    font.pixelSize: Theme.displaySize
    font.bold: true
    color: root.folderPath === "" ? Theme.ink : Theme.topicColor(root.folderPath)
  }
  UiText {
    text: root.folder ? Format.plural(root.folder.count, "page")
                        + (root.folder.folders.length ? " · " + Format.plural(root.folder.folders.length, "folder") : "") : ""
    font.pixelSize: Theme.bodySmallSize
    color: Theme.dim
  }

  Column {
    width: parent.width
    visible: root.folder && root.folder.folders.length > 0
    spacing: Theme.spaceXs
    SectionLabel { divided: true; text: root.folderPath === "" ? "Topics" : "Folders" }
    Repeater {
      model: root.folder ? root.folder.folders : []
      delegate: ListRow {
        id: folderRow
        required property var modelData
        objectName: "folder:" + folderRow.modelData.path
        width: root.width
        title: folderRow.modelData.name
        topic: folderRow.modelData.path
        note: Format.plural(folderRow.modelData.count, "page")
        onActivated: root.app.openFolder(folderRow.modelData.path)
      }
    }
  }

  Column {
    width: parent.width
    visible: root.folder && root.folder.pages.length > 0
    spacing: Theme.spaceXs
    SectionLabel { divided: true; text: "Pages" }
    Repeater {
      model: root.folder ? root.folder.pages : []
      delegate: ListRow {
        id: pageRow
        required property var modelData
        objectName: "folderPage:" + pageRow.modelData.path
        width: root.width
        title: pageRow.modelData.title
        note: root.app.store.pagesByPath[pageRow.modelData.path] ? root.app.store.pagesByPath[pageRow.modelData.path].updated : ""
        onActivated: root.app.openPage(pageRow.modelData.path, "")
      }
    }
  }
}
