.pragma library

// Markdown editing in the card note dialog (NoteDialog.qml): the source is
// what is typed, as in any markdown editor, with the two things that make
// typing it bearable: Enter carries a list on, and Ctrl+B / Ctrl+I put the
// markers around the selection. Pure, so tests/unit pins them.
//
// Each returns an edit, { from, to, insert }: replace [from, to) with
// `insert`, which the dialog applies with the editor's own remove() and
// insert() so Ctrl+Z still undoes it (setting the whole text would clear the
// undo history). `text` is the result, for the tests; `start` and `end` are
// where the selection (or the cursor, start === end) goes afterwards.
//
// A rich-text editor (Qt's TextEdit in MarkdownText format) was the other way,
// and rejected: it shows the markup only as formatting, so a stray `*` or a
// list marker cannot be seen or fixed by hand, and Qt writes the markdown
// back in its own dialect. The dialog renders a preview under the source
// instead.

var LIST = /^(\s*)([-*+]|(\d+)([.)]))(\s+)(\[[ xX]\]\s+)?/

function edit(text, from, to, insert, start, end) {
  return { from: from, to: to, insert: insert, start: start, end: end,
           text: text.slice(0, from) + insert + text.slice(to) }
}

// Enter at `pos`: on a list item, the next line starts with the same marker
// (the next number, an empty checkbox). On an item with nothing after its
// marker, Enter ends the list instead, clearing the marker, as editors do.
// null when the line is no list item: the editor then types a plain newline.
function continueList(text, pos) {
  var start = text.lastIndexOf("\n", pos - 1) + 1
  var line = text.slice(start, pos)
  var m = LIST.exec(line)
  if (!m) return null
  var rest = text.slice(pos, nextBreak(text, pos))
  if (line.slice(m[0].length).trim() === "" && rest.trim() === "") return edit(text, start, pos, "", start, start)
  var marker = m[3] !== undefined ? (parseInt(m[3], 10) + 1) + m[4] : m[2]
  var insert = "\n" + m[1] + marker + m[5] + (m[6] ? "[ ] " : "")
  return edit(text, pos, pos, insert, pos + insert.length, pos + insert.length)
}

function nextBreak(text, pos) {
  var i = text.indexOf("\n", pos)
  return i === -1 ? text.length : i
}

// Ctrl+B (`**`) or Ctrl+I (`*`) over [start, end): wraps the selection, or
// unwraps it when the markers are already just outside it. With nothing
// selected it leaves the cursor between a new pair. The selection afterwards
// holds the same words.
function wrap(text, start, end, mark) {
  var n = mark.length
  var before = text.slice(Math.max(0, start - n), start), after = text.slice(end, end + n)
  // `*` must not unwrap one star of a `**`.
  var inBold = n === 1 && (text.charAt(start - 2) === "*" || text.charAt(end + 1) === "*")
  var inner = text.slice(start, end)
  if (start !== end && before === mark && after === mark && !inBold)
    return edit(text, start - n, end + n, inner, start - n, end - n)
  return edit(text, start, end, mark + inner + mark, start + n, end + n)
}

// A note's first line without its markdown, for a one-line mention (the
// Cards stage, Home's sessions). A single `_` stays: it is far more often in
// a name (with_lock) than italics.
function firstLine(body) {
  var line = String(body || "").trim().split("\n")[0] || ""
  return line.replace(LIST, "").replace(/^#+\s*/, "").replace(/^>\s*/, "").replace(/\*|__|`/g, "").trim()
}
