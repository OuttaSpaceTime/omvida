pragma ComponentBehavior: Bound
import QtQuick

import "Format.js" as Format

// Retention over the last 30 days on the Cards screen: flashcard-mcp's
// calibration verdict, shown verbatim (the figure, the verdict, the rating
// mix), never worked out here.
Column {
  id: root
  objectName: "retentionPanel"
  spacing: Theme.spaceSm

  // The deck overview's calibration, or null while it loads.
  property var calibration: null

  // How many reviews the figure rests on sits at the header's right
  // end, as the filter header carries its count, so the line below
  // is only the figure and its verdict. It used to trail the
  // verdict after a "·", which made that line run past the aside
  // and read as one more clause of the verdict.
  Item {
    width: parent.width
    height: retentionLabel.height
    SectionLabel {
      id: retentionLabel
      text: "Retention · " + (root.calibration ? root.calibration.window_days : 30) + " days"
    }
    UiText {
      objectName: "retentionReviews"
      visible: root.calibration !== null
      anchors.right: parent.right
      anchors.baseline: retentionLabel.baseline
      text: root.calibration ? Format.plural(root.calibration.reviews, "review") : ""
      font.pixelSize: Theme.captionSize; color: Theme.dim
    }
  }
  // The verdict takes what the figure leaves of the column and
  // wraps, should a verdict ever be too long for it. An Item, not
  // a Row: a Row never bounds its children, and is as tall as its
  // tallest child without counting the verdict's baseline offset,
  // so a wrapped verdict would run into the rating mix below.
  Item {
    width: parent.width
    height: Math.max(retentionFigure.height, retentionVerdict.y + retentionVerdict.height)
    UiText {
      id: retentionFigure
      text: Format.pct(root.calibration ? root.calibration.true_retention : null)
      font.pixelSize: Theme.headingSize
      font.bold: true
      color: root.calibration ? Theme.verdictColor(root.calibration.verdict) : Theme.faint
    }
    UiText {
      id: retentionVerdict
      objectName: "retentionVerdict"
      x: retentionFigure.width + Theme.spaceMd
      width: parent.width - x
      wrapMode: Text.Wrap
      anchors.baseline: retentionFigure.baseline
      text: root.calibration ? Format.verdictText(root.calibration) : "loading…"
      font.pixelSize: Theme.bodySmallSize
      color: root.calibration ? Theme.verdictColor(root.calibration.verdict) : Theme.faint
    }
  }
  Flow {
    objectName: "ratingMix"
    visible: root.calibration !== null
    width: parent.width
    spacing: Theme.spaceLg
    Repeater {
      model: root.calibration ? [1, 2, 3, 4] : []
      delegate: UiText {
        id: mixItem
        required property int modelData
        readonly property string name: Format.ratingName(mixItem.modelData).toLowerCase()
        text: root.calibration.rating_mix[mixItem.name] + " " + mixItem.name
        font.pixelSize: Theme.bodySmallSize
        color: Theme.ratingColor(mixItem.modelData)
      }
    }
  }
}
