#!/usr/bin/env python3
"""A stand-in for the Claude Messages API in the app tests and screenshots: no
network, no cost, the shape flashcard-mcp's grading.ts reads.

    fake-anthropic.py <out-dir> <owner-pid>

Listens on 127.0.0.1 at a free port, written to <out-dir>/fake-api.port, and
exits once <owner-pid> is gone: bin/sandbox starts it and then execs the app
in its own process, so the owner is the app.

Each grade's prompt goes to grades.jsonl as [prompt]. It rates 1 when the
answer has "wrong" in it, 4 for "perfect", else 3; fails with a 400 for
"failme"; waits FAKE_GRADE_DELAY seconds first
(default 0.3), 2 for an answer with "slowly". A grade the client aborts while
it waits (the deck server ending a superseded grade) goes to
grade-aborts.jsonl as [prompt].
"""
import json
import os
import select
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

out, owner = sys.argv[1], int(sys.argv[2])


def record(name, prompt):
    with open(os.path.join(out, name), "a") as f:
        f.write(json.dumps([prompt]) + "\n")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def closed_while_waiting(self, seconds):
        """Waits, and says whether the client hung up meanwhile."""
        end = time.monotonic() + seconds
        while (left := end - time.monotonic()) > 0:
            readable, _, _ = select.select([self.connection], [], [], left)
            if readable:
                try:
                    if self.connection.recv(1, socket.MSG_PEEK) == b"":
                        return True
                except OSError:
                    return True
        return False

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
        if not self.path.startswith("/v1/messages"):
            return self.reply(404, {"type": "error", "error": {"type": "not_found_error", "message": self.path}})
        prompt = body["messages"][0]["content"]
        record("grades.jsonl", prompt)
        answer = prompt.split("<developer_answer>\n", 1)[1].rsplit("\n</developer_answer>", 1)[0]
        delay = 2 if "slowly" in answer else float(os.environ.get("FAKE_GRADE_DELAY", "0.3"))
        if self.closed_while_waiting(delay):
            return record("grade-aborts.jsonl", prompt)
        if "failme" in answer:
            return self.reply(400, {"type": "error", "error": {"type": "invalid_request_error", "message": "Fixture grader failed"}})
        rating, reason = 3, "Fixture grader: right idea, reasonable detail."
        if "wrong" in answer:
            rating, reason = 1, "Fixture grader: that misses the concept. The back says what was needed."
        elif "perfect" in answer:
            rating, reason = 4, "Fixture grader: complete and precise."
        verdict = {"rating": rating, "reason": reason}
        self.reply(200, {
            "id": "msg_fixture", "type": "message", "role": "assistant", "model": body.get("model"),
            "content": [{"type": "text", "text": json.dumps(verdict)}],
            "stop_reason": "end_turn", "stop_sequence": None,
            "usage": {"input_tokens": 900, "output_tokens": 60},
        })


def watch_owner(server):
    # A pidfd turns readable when the process exits: no polling, and no
    # mistaking a recycled pid for the owner.
    try:
        select.select([os.pidfd_open(owner)], [], [])
    except ProcessLookupError:
        pass
    server.shutdown()


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
server.daemon_threads = True
tmp = os.path.join(out, "fake-api.port.tmp")
with open(tmp, "w") as f:
    f.write(str(server.server_address[1]))
os.replace(tmp, os.path.join(out, "fake-api.port"))
threading.Thread(target=watch_owner, args=(server,), daemon=True).start()
server.serve_forever()
