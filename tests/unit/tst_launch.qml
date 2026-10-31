import QtQuick
import QtTest
import "../../Launch.js" as L

TestCase {
  name: "Launch"

  readonly property var card: ({ id: "c1", deck: "Web", front: "What does <code>max-age</code> do?", back: "Keeps it fresh<br>for N seconds" })

  function test_discuss_opens_claude_in_kitty_in_the_study_repo() {
    var argv = L.discussArgv("/s", card, "it caches", { rating: 2, reason: "Missing the unit." })
    compare(argv.slice(0, 8), ["kitty", "--directory", "/s", "--title", "Omvida · Discuss", "--class", "omvida-claude", "claude"])
    var prompt = argv[8]
    verify(prompt.indexOf("Socratic mode") !== -1)
    verify(prompt.indexOf("Don't rate the card or call submit_review") !== -1)
    verify(prompt.indexOf("Front:\nWhat does max-age do?") !== -1)
    verify(prompt.indexOf("Back:\nKeeps it fresh\nfor N seconds") !== -1)
    verify(prompt.indexOf("My answer:\nit caches") !== -1)
    verify(prompt.indexOf("Suggested rating: Hard (2). Missing the unit.") !== -1)
  }

  function test_add_commands_call_the_skills() {
    compare(L.skillArgv("/s", "t", "/study-flashcard", " HTTP caching ", "")[8], "/study-flashcard HTTP caching")
    compare(L.skillArgv("/s", "t", "/study-walkthrough --write", "ETags", "wiki page web/http-caching")[8], "/study-walkthrough --write ETags\n\nContext: wiki page web/http-caching")
  }

  function test_explore_opens_the_url_as_a_web_app() {
    compare(L.exploreArgv("https://claude.ai/artifact/abc"), ["omarchy-launch-webapp", "https://claude.ai/artifact/abc"])
  }

  function test_leech_prompts() {
    verify(L.leechArgv("/s", card, 6, "rewrite")[8].indexOf("update_card") !== -1)
    verify(L.leechArgv("/s", card, 6, "split")[8].indexOf("inheritFrom: \"c1\"") !== -1)
  }

  function test_ask_is_headless_with_only_lookups_and_the_log() {
    var argv = L.askArgv("What is HSTS?")
    compare(argv[0], "claude")
    verify(argv.indexOf("-p") !== -1)
    var tools = argv[argv.indexOf("--allowedTools") + 1].split(",")
    verify(tools.indexOf("Bash") === -1)
    verify(tools.indexOf("Write(logs/**)") !== -1)
    verify(tools.indexOf("Edit") === -1)
    compare(argv.slice(0, 3), ["claude", "-p", "What is HSTS?"], "the prompt before --allowedTools, which would take it as a tool")
  }

  function test_parse_ask_stream() {
    compare(L.parseAskLine('{"type":"system","subtype":"init","session_id":"s1"}'), { sessionId: "s1" })
    compare(L.parseAskLine('{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hi"}}}'), { text: "Hi" })
    compare(L.parseAskLine('{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":""}}}'), {})
    compare(L.parseAskLine('{"type":"stream_event","event":{"type":"content_block_start","content_block":{"type":"tool_use","name":"mcp__qmd__query"}}}'), { tool: "mcp__qmd__query" })
    compare(L.parseAskLine('{"type":"result","subtype":"success","is_error":false,"session_id":"s1"}'), { done: true, sessionId: "s1" })
    compare(L.parseAskLine('{"type":"result","is_error":true,"result":"boom"}'), { done: true, error: "boom" })
    compare(L.parseAskLine("not json"), {})
    compare(L.toolLabel("mcp__qmd__query"), "searching the wiki")
  }

  // Ctrl+Q: the study repo's skill, headless, with the card writes it may
  // make and no shell; its last line is the result.
  function test_card_check_runs_the_skill_headless() {
    var argv = L.cardCheckArgv("c1")
    compare(argv.slice(0, 3), ["claude", "-p", "/study-card-check c1"])
    compare(argv[argv.indexOf("--model") + 1], "sonnet")
    var tools = argv[argv.indexOf("--allowedTools") + 1].split(",")
    verify(tools.indexOf("mcp__flashcard-mcp__update_card") !== -1)
    verify(tools.indexOf("mcp__flashcard-mcp__create_card") !== -1)
    verify(tools.indexOf("Bash") === -1)
    verify(tools.indexOf("mcp__flashcard-mcp__submit_review") === -1)
  }

  function test_parse_card_check() {
    compare(L.parseCardCheck('{"type":"result","subtype":"success","is_error":false,"result":"Looked at it.\\n\\nNo change: precise."}'), { ok: true, text: "No change: precise." })
    compare(L.parseCardCheck('{"type":"result","subtype":"error_max_turns","is_error":true,"result":"Unchanged: ran out"}'), { ok: false, text: "Unchanged: ran out" })
    compare(L.parseCardCheck('{"type":"result","subtype":"success","is_error":false,"result":""}'), { ok: false, text: "" })
    compare(L.parseCardCheck(""), { ok: false, text: "" })
  }

  // Fix noted cards: one session, through the study repo's skill, which
  // reads the notes itself; the app names only the cards.
  function test_fix_notes_hands_the_cards_to_the_skill() {
    compare(L.fixNotesArgv("/s", ["c1", "c2"]), ["kitty", "--directory", "/s", "--title", "Omvida · Fix noted cards",
                                                 "--class", "omvida-claude", "claude", "/study-fix-notes c1 c2"])
    compare(L.fixNotesArgv("/s", null).slice(-1), ["/study-fix-notes"], "every open note")
    compare(L.fixNotesArgv("/s", []).slice(-1), ["/study-fix-notes"])
  }
}
