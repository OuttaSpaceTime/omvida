---
title: CSRF
aliases: [xsrf]
tags: [security, web]
created: '2026-05-07'
updated: '2026-05-07'
source_skill: study-walkthrough
flashcard_ids:
- fixturecard0003
---

# CSRF (Cross-Site Request Forgery)

An attacker makes the victim's browser send a state-changing request. Caching is unrelated, see [[web/http-caching#Freshness]].

## Defences

```python
def check(token, session):
    return hmac.compare_digest(token, session.csrf)
```
