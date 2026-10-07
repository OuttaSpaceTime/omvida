import QtQuick

// A block's small caps label ("LAST STUDIED"), the viewer's SectionLabel.
//
// `divided` puts a hairline above it, the Glance overlay's section rule: the
// sections of a screen are parted by one quiet line and a caption rather than
// by boxes. The rule spans the label's container, less the label's own inset
// on both sides, so a label set in from a side panel's edge (x: spaceLg) gets a
// rule set in by as much. `ruleGap` is room above the rule, for a column whose
// own spacing is too tight to part two sections (the wiki's side panel).
UiText {
  id: root

  property bool divided: false
  property int ruleGap: 0

  font.pixelSize: Theme.captionSize
  font.capitalization: Font.AllUppercase
  font.letterSpacing: Theme.labelTracking
  color: Theme.faint
  topPadding: divided ? ruleGap + Theme.spaceLg : 0
  bottomPadding: divided ? Theme.spaceXs : 0

  Rectangle {
    visible: root.divided
    y: root.ruleGap
    width: (root.parent ? root.parent.width : 0) - root.x * 2
    height: Theme.hairlineWidth
    color: Theme.hairline
  }
}
