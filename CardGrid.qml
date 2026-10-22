import QtQuick

// A grid of CardTiles, the Cards screen's and a page's: up to
// cardTileMaxColumns tiles of at least cardTileMinWidth a row, every tile
// `cellWidth` wide and `tileHeight` tall. The caller puts a Repeater of
// CardTiles in it and sizes each from those two.
//
// The height is a full tile's (its caption and cardTileLines lines of text),
// so the grid is one of equal cards rather than a ragged wall, measured off
// one unseen full tile here rather than a hidden copy in every tile, which
// would have been some 700 more texts on the Cards screen. A positioner
// skips an invisible child, so the probe takes no cell.
Grid {
  id: root

  readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns
  readonly property real tileHeight: probe.implicitHeight

  columnSpacing: Theme.spaceXl
  rowSpacing: Theme.spaceSm
  columns: Math.max(1, Math.min(Theme.cardTileMaxColumns, Math.floor((width + columnSpacing) / (Theme.cardTileMinWidth + columnSpacing))))

  CardTile { id: probe; full: true; visible: false; width: root.cellWidth }
}
