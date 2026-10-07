#!/usr/bin/env python3
"""Fill an empty deck database (flashcard-mcp's schema) with the fixture cards.

    tests/fixtures/seed_deck.py <master.db>

Run by tests/fixtures/make-deck.sh after `prisma db push` has created the
tables. Datetimes are ISO text with +00:00, the format flashcard-mcp writes
today. The card ids match the fixture wiki's flashcard_ids, so related pages
and per-page cards line up. Nothing here comes from the real deck.

Due now: three review cards (pressure ok). One new card. A suspended card.
A week of review history, so the overview has something to draw.
"""

import sqlite3
import sys
from datetime import UTC, datetime, timedelta

now = datetime.now(UTC)


def iso(d):
    return d.isoformat(timespec="milliseconds")


db = sqlite3.connect(sys.argv[1])
db.execute("INSERT INTO Deck (id, name, createdAt) VALUES ('deckweb', 'Web', ?)", (iso(now - timedelta(days=60)),))

cards = [
    # id, front, back, tags, state, due offset (days), stability, interval, lapses, suspended
    ("fixturecard0001", "What does <code>Cache-Control: max-age=60</code> tell a browser?",
     "The response is fresh for 60 seconds and can be reused without asking the server.", "http,web", 2, -1, 5.0, 5, 0, 0),
    ("fixturecard0002", "Which request header carries an ETag back to the server?",
     "<code>If-None-Match</code>. The server answers 304 if the ETag still matches.", "http,web", 2, -2, 4.0, 4, 1, 0),
    ("fixturecard0003", "A form on evil.com posts to bank.com/transfer. Why does the request carry the victim's session?",
     "The browser attaches bank.com's cookies to every request to bank.com, whichever page sent it.", "security,web", 2, -1, 6.0, 6, 0, 0),
    ("fixturecard0004", "What three parts make up an origin?",
     "Scheme, host and port.", "security", 0, 0, 0.0, 0, 0, 0),
    ("fixturecard0005", "What does HSTS stop?",
     "Downgrade to plain HTTP: the browser only uses HTTPS for the host.", "security", 2, 9, 20.0, 20, 0, 1),
]
for cid, front, back, tags, state, due, stab, ivl, lapses, susp in cards:
    last = None if state == 0 else iso(now - timedelta(days=ivl))
    db.execute(
        "INSERT INTO Card (id, deckId, front, back, tags, type, due, stability, difficulty, reps, lapses, state,"
        " lastReview, interval, suspended, createdAt, updatedAt) VALUES (?,?,?,?,?,'guided',?,?,?,?,?,?,?,?,?,?,?)",
        (cid, "deckweb", front, back, tags, iso(now + timedelta(days=due) - timedelta(minutes=5)), stab, 5.0,
         0 if state == 0 else 3, lapses, state, last, ivl, susp, iso(now - timedelta(days=30)), iso(now - timedelta(days=30))),
    )

reviews = [("fixturecard0001", 3, 6), ("fixturecard0002", 1, 4), ("fixturecard0002", 3, 4), ("fixturecard0003", 3, 2), ("fixturecard0005", 4, 1)]
for i, (cid, rating, days_ago) in enumerate(reviews):
    db.execute(
        "INSERT INTO Review (id, cardId, rating, stability, difficulty, elapsedDays, reviewedAt) VALUES (?,?,?,?,?,?,?)",
        (f"fixturereview{i:04d}", cid, rating, 3.0, 5.0, 2.0, iso(now - timedelta(days=days_ago, hours=1))),
    )
db.commit()
