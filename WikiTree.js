.pragma library

// Lookups in the wiki tree the wiki service sends (wiki.py build_tree):
// folders { name, path, count, folders, pages }, `count` being every page
// under the folder.

// The folder at `path` ("" is the root), or null.
function findFolder(tree, path) {
  if (!tree) return null
  if (tree.path === path) return tree
  for (var i = 0; i < tree.folders.length; i++) {
    var f = findFolder(tree.folders[i], path)
    if (f) return f
  }
  return null
}

// Every page under a folder, at any depth.
function collectPages(folder) {
  var out = folder.pages.slice()
  folder.folders.forEach(function(f) { out = out.concat(collectPages(f)) })
  return out
}
