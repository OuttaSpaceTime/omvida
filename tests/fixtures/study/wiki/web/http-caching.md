---
title: HTTP Caching
aliases: [cache-control]
tags: [web, http]
created: '2026-05-02'
updated: '2026-05-03'
source_skill: study-walkthrough
flashcard_ids:
- fixturecard0001
- fixturecard0002
---

# HTTP Caching

Browsers reuse a response until it goes stale. See [[security/csrf|CSRF]] for why `[[not-a-link]]` in code is ignored, and [[missing/page]] for a broken link.

## Freshness

`Cache-Control: max-age=60` keeps a response fresh for a minute.

```http
HTTP/1.1 200 OK
Cache-Control: max-age=60, must-revalidate
```

> [Heuristic] Validate with ETag before you reach for max-age.

## Validation

| Header | Sent by |
| --- | --- |
| ETag | server |
| If-None-Match | client |

- [x] read RFC 9111
- [ ] write a card

Jump to [[#Freshness]]. ![[diagram.png]]
