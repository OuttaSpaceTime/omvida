.pragma library
.import "Format.js" as Format

// Commands that hand a topic to Claude Code. Pure argv builders, so the
// prompts are pinned in tests/unit and the app only runs what comes back.
//
// Interactive work (discussing a card, writing cards or a wiki page, fixing a
// leech) opens Claude Code in kitty, in the study repo, where the skills, the
// flashcard MCP server and AGENTS.md live. The app never edits cards or pages
// itself: the skills own those rules (content format, duplicate checks, the
// wiki-write protocol), and a second implementation would drift.
//
// The question box is the one place Claude runs headless (askArgv): an
// answer streams into the app, and "continue in Claude" resumes the same
// session in kitty.

// `studyDir` is where Claude runs; `title` names the kitty window.
function kittyArgv(studyDir, title, claudeArgs) {
  return ["kitty", "--directory", studyDir, "--title", title, "--class", "omvida-claude", "claude"].concat(claudeArgs)
}

function cardBlock(card) {
  return "Card id: " + card.id + "\nDeck: " + card.deck
    + "\nFront:\n" + Format.htmlToText(card.front)
    + "\nBack:\n" + Format.htmlToText(card.back)
}

// Discuss: /study's Socratic mode on one card, outside the session. The
// rating stays with the app (the developer rates when back), so Claude must
// not submit a review of its own.
function discussPrompt(card, answer, suggestion) {
  var lines = [
    "I'm studying in the Omvida app and want to discuss this flashcard. Use the /study skill's Socratic mode "
    + "(\"Fast Feedback by Default, Socratic on Request\"): decompose with small concrete questions, don't hand me the answer. "
    + "Don't rate the card or call submit_review: Omvida records my rating. If the card itself has a quality problem, say so and offer to fix it with update_card.",
    "",
    cardBlock(card),
    "",
    "My answer:",
    answer && answer.trim() !== "" ? answer.trim() : "(I didn't type one)"
  ]
  if (suggestion) {
    lines.push("", "Suggested rating: " + Format.ratingName(suggestion.rating) + " (" + suggestion.rating + "). " + suggestion.reason)
  }
  return lines.join("\n")
}

function discussArgv(studyDir, card, answer, suggestion) {
  return kittyArgv(studyDir, "Omvida · Discuss", [discussPrompt(card, answer, suggestion)])
}

// A skill on a topic: `/study-flashcard` (Add -> Flashcards: suggest fronts,
// pick, create), `/study-walkthrough --write` (Add -> Wiki entry), or
// `/study-walkthrough` (go deeper). `context` is where it came from: a wiki
// page or a card.
function skillArgv(studyDir, title, skill, topic, context) {
  var arg = skill + " " + topic.trim()
  if (context) arg += "\n\nContext: " + context
  return kittyArgv(studyDir, title, [arg])
}

// A leech: rewrite (default), or split. /study's leech table, for one card.
function leechPrompt(card, lapses, how) {
  var ask = how === "split"
    ? "Split it: draft the focused cards, create each with create_card and inheritFrom: \"" + card.id + "\" so they keep its schedule, then delete_card the original."
    : "Rewrite it grounded (a concrete scenario front, per /study's staging rule) and save it with update_card, which clears the leech flag and resets its lapses."
  return "This flashcard is a leech: " + lapses + " lapses, so the card is fighting me, not the concept. " + ask
    + " Follow /study-flashcard's card content format and size rules. Show me the draft before writing it.\n\n" + cardBlock(card)
}

function leechArgv(studyDir, card, lapses, how) {
  return kittyArgv(studyDir, "Omvida · Fix leech", [leechPrompt(card, lapses, how)])
}

// Fix a card the grader flagged.
function fixCardArgv(studyDir, card, quality) {
  var p = "The grader flagged this flashcard: " + quality.issue.replace(/_/g, " ") + ". " + (quality.detail || "")
    + "\nPropose a fix (update_card to tighten it, or a split with inheritFrom), following /study-flashcard's format and size rules. Show me the draft before writing it.\n\n"
    + cardBlock(card)
  return kittyArgv(studyDir, "Omvida · Fix card", [p])
}

// Resume an Ask session interactively.
function resumeArgv(studyDir, sessionId) {
  return kittyArgv(studyDir, "Omvida · Ask", ["--resume", sessionId])
}

// The tools a headless Ask may use without a prompt: read-only lookups, and
// appending its Query entry to today's log. Nothing else: no Bash, no edits
// outside logs/.
var ASK_TOOLS = [
  "Read", "Glob", "Grep",
  "mcp__qmd__query", "mcp__qmd__search", "mcp__qmd__get",
  "mcp__flashcard-mcp__search_cards", "mcp__flashcard-mcp__get_card",
  "WebSearch", "WebFetch",
  "Edit(logs/**)", "Write(logs/**)"
]

var ASK_SYSTEM = "You are answering a question typed into Omvida, a study app, as a one-shot run. "
  + "Follow the Query Protocol in AGENTS.md, adapted to a run with no follow-up turn: "
  + "1) Start with the answer from memory, concise, in markdown. Do not call any tool before this first answer. "
  + "2) Then do the lookups yourself rather than in a subagent: mcp__qmd__query (rerank false) and mcp__flashcard-mcp__search_cards with the question, and verify the answer against the web (WebSearch, then WebFetch on the most authoritative result when there is a specific claim to check). "
  + "3) Append the `## Query N (HH:MM)` entry to today's logs/<MM>/<YYYY-MM-DD>.md as AGENTS.md describes. "
  + "4) End with a section headed `**Saved knowledge**`: wiki pages as [[folder/slug]], card ids, and the web check verdict (confirms, contradicts, refines or inconclusive) with the URL. If the web or the wiki contradicts your first answer, say so plainly there and give the correction. "
  + "Never narrate tool calls, and never print file contents or JSON."

function askArgv(question) {
  return [
    "claude", "-p",
    "--output-format", "stream-json", "--verbose", "--include-partial-messages",
    "--model", "sonnet",
    "--append-system-prompt", ASK_SYSTEM,
    "--allowedTools", ASK_TOOLS.join(","),
    question
  ]
}

// One stream-json line -> { text?, sessionId?, done?, error? }. Text comes as
// partial deltas; tool use is ignored (the Query Protocol says not to narrate
// it). Unknown lines yield {}.
function parseAskLine(line) {
  var ev
  try { ev = JSON.parse(line) } catch (e) { return {} }
  if (!ev || typeof ev !== "object") return {}
  if (ev.type === "system" && ev.subtype === "init") return { sessionId: ev.session_id }
  if (ev.type === "stream_event" && ev.event && ev.event.type === "content_block_delta"
      && ev.event.delta && ev.event.delta.type === "text_delta") {
    return { text: ev.event.delta.text }
  }
  // A new assistant text block after tool calls: start it on a fresh paragraph.
  if (ev.type === "stream_event" && ev.event && ev.event.type === "content_block_start"
      && ev.event.content_block && ev.event.content_block.type === "text") {
    return { blockStart: true }
  }
  if (ev.type === "stream_event" && ev.event && ev.event.type === "content_block_start"
      && ev.event.content_block && ev.event.content_block.type === "tool_use") {
    return { tool: ev.event.content_block.name }
  }
  if (ev.type === "result") {
    return ev.is_error ? { done: true, error: String(ev.result || ev.subtype || "failed") } : { done: true, sessionId: ev.session_id }
  }
  return {}
}

// What a tool call is doing, in a few words, for the Ask panel's status line.
function toolLabel(name) {
  if (!name) return ""
  if (name.indexOf("qmd") !== -1) return "searching the wiki"
  if (name.indexOf("flashcard") !== -1) return "searching the cards"
  if (name === "WebSearch" || name === "WebFetch") return "checking the web"
  if (name === "Edit" || name === "Write") return "logging the query"
  return "looking things up"
}
