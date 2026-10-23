#!/usr/bin/env python3
"""A JSON-lines backend for tests/app/tst_client.qml, speaking JsonLineClient's
protocol: {"ready": true} once, then each request answered with its own params.
"hang" is never answered and "exit" ends the process (code 3), the two ways a
real backend fails. --slow-start SECONDS waits before the ready line, as the
wiki service does on its first launch."""

import json
import sys
import time

if len(sys.argv) > 2 and sys.argv[1] == "--slow-start":
    time.sleep(float(sys.argv[2]))
print(json.dumps({"ready": True}), flush=True)
for line in sys.stdin:
    req = json.loads(line)
    if req["method"] == "hang":
        continue
    if req["method"] == "exit":
        sys.exit(3)
    print(json.dumps({"id": req["id"], "result": req.get("params")}), flush=True)
