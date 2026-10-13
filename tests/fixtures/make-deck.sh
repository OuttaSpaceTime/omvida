#!/usr/bin/env bash
# Builds the fixture deck: an empty database with flashcard-mcp's own schema
# (its `db-sync`, the prisma db push every flashcard-mcp start does, so it can
# never drift from the real one, and stamped so the deck server's start finds
# it in sync), then the fixture cards (seed_deck.py).
#
#   tests/fixtures/make-deck.sh <out.db>
#
# bin/test builds it once per run and copies it for each app test; bin/shot
# does the same. The real deck (prisma/master.db) is never opened.
set -euo pipefail
out="${1:?out.db}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="$(env -u OMVIDA_STUDY_DIR "$here/../../bin/flashcard-mcp-dir")"
rm -f "$out"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
(cd "$dir" && NODE_NO_WARNINGS=1 DATABASE_URL="file:$out" "$dir/node_modules/.bin/tsx" src/cli/index.ts db-sync >/dev/null 2>&1) \
  || { echo "make-deck: flashcard-mcp db-sync failed" >&2; exit 1; }
python3 "$here/seed_deck.py" "$out"
