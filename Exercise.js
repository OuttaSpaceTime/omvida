.pragma library

// A code card's parts as lines to draw, and its results as words. Pure, so
// tests/unit pins them. What a result means (pass, wrong, the rating it writes)
// is the deck server's (flashcard-mcp's exercises.ts): this only says it.

// The server's parts, cut at newlines into lines of pieces:
//   { text, segment }      code; `segment` numbers it among all the code, for
//                          its highlighted html (segments() gives the list)
//   { blank, multiline }   a blank
// A multi-line blank takes a line of its own, being a block to write in.
function lines(parts) {
  var out = [[]]
  var segment = 0
  for (let i = 0; i < parts.length; i++) {
    let part = parts[i]
    if (part.text === undefined) {
      if (part.multiline && out[out.length - 1].length > 0) out.push([])
      out[out.length - 1].push({ blank: part.blank, multiline: !!part.multiline })
      if (part.multiline) out.push([])
      continue
    }
    let pieces = part.text.split("\n")
    for (let j = 0; j < pieces.length; j++) {
      if (j > 0) out.push([])
      if (pieces[j] !== "") out[out.length - 1].push({ text: pieces[j], segment: segment++ })
    }
  }
  // Blocks and newlines both end a line, which leaves an empty one after a block.
  return out.filter(function(line, i) {
    return line.length > 0 || (i > 0 && i < out.length - 1 && !isBlock(out[i - 1]))
  })
}

function isBlock(line) { return line.length === 1 && !!line[0].multiline }

// The code runs in `lines`, by segment number, to be highlighted.
function segments(parts) {
  var all = []
  lines(parts).forEach(function(line) {
    line.forEach(function(piece) { if (piece.text !== undefined) all[piece.segment] = piece.text })
  })
  return all
}

// ---- indenting a block ---------------------------------------------------------
// Two spaces, as the cards' Ruby is written. Pure text, no parser: it reads one
// line at a time, enough to be right on the bodies a card asks for, and a line it
// gets wrong costs a backspace. The deck server never reads the indentation.
var INDENT = "  "

function leading(line) { return line.match(/^ */)[0] }

function lastLine(text) { return text.slice(text.lastIndexOf("\n") + 1) }

// The line opens a body: the next line goes one further in.
function opens(line) {
  var code = line.replace(/\s#.*$/, "").trim()
  if (/\bend$/.test(code)) return false   // `def f; 1; end` is whole
  return /^(def|class|module|if|unless|while|until|for|case|begin|else|elsif|when|rescue|ensure)\b/.test(code)
    || /\bdo(\s*\|[^|]*\|)?$/.test(code)
    || /[{(\[](\s*\|[^|]*\|)?$/.test(code)
}

// The line starts by closing one: it belongs one further out than its body.
function closes(line) {
  return /^(end\b|else\b|elsif\b|when\b|rescue\b|ensure\b|[})\]])/.test(line.trim())
}

// What an empty block starts with: where a line after the code before it goes,
// so a method's body is indented from the first key.
function bodyIndent(textBefore) {
  var line = lastLine(textBefore.replace(/\n$/, ""))
  return leading(line) + (opens(line) ? INDENT : "")
}

// One answer per blank to start from: a block's indentation, else nothing.
function startAnswers(parts, count) {
  var out = []
  for (let i = 0; i < count; i++) out.push("")
  parts.forEach(function(part, i) {
    if (part.multiline) out[part.blank] = bodyIndent(i > 0 && parts[i - 1].text ? parts[i - 1].text : "")
  })
  return out
}

// Enter in a block, given the text before the cursor. `insert` is the newline and
// the next line's indentation. `dedent` is how many spaces come off the line being
// left, when it closes a body and still has that body's indentation (the `end`
// typed where Enter had put the cursor); none when it was already moved out by hand.
function enterEdit(before) {
  var line = lastLine(before)
  var dedent = 0
  var above = before.slice(0, Math.max(before.length - line.length - 1, 0))
  if (closes(line) && before.length > line.length) {
    let prev = lastLine(above)
    let wanted = Math.max(leading(prev).length - (opens(prev) ? 0 : INDENT.length), 0)
    dedent = Math.max(leading(line).length - wanted, 0)
  }
  var kept = leading(line).slice(dedent)
  return { dedent: dedent, insert: "\n" + kept + (opens(line) ? INDENT : "") }
}

// How many characters Backspace takes: within a line's indentation, back to the
// last stop, so what Enter put there comes off in one press.
function backspaceCount(before) {
  var line = lastLine(before)
  if (line === "" || line.trim() !== "") return 1
  return ((line.length - 1) % INDENT.length) + 1
}

// The spaces Tab adds at this column, to the next stop.
function tabSpaces(before) {
  return INDENT.slice(lastLine(before).length % INDENT.length)
}

// How many spaces Shift+Tab takes off the start of the line.
function outdentCount(before, after) {
  var line = lastLine(before) + after.split("\n")[0]
  return Math.min(leading(line).length, INDENT.length)
}

function matched(result) {
  return result.cases.filter(function(c) { return c.pass }).length
}

// One line on a result.
function verdict(result) {
  if (!result) return ""
  switch (result.status) {
  case "pass": return "matches"
  case "wrong": return result.cases.length > 1
    ? matched(result) + " of " + result.cases.length + " match"
    : "doesn't match"
  case "error": return "error"
  case "timeout": return "stopped"
  case "unavailable": return "can't run"
  case "incomplete": return "fill in the blanks"
  }
  return ""
}

// What stopped the run before any case: a syntax error, an `exit`. An error
// raised in a case is that case's output, and shown there.
function errorText(result) {
  return result && result.error ? result.error : ""
}

// The run's printed output and warnings. Warnings never fail a card, but stay
// on show, as a real run would have them.
function printed(result) {
  if (!result) return ""
  var out = result.output || ""
  if (result.stderr) out += (out !== "" && !out.endsWith("\n") ? "\n" : "") + result.stderr
  return out.replace(/\n$/, "")
}
