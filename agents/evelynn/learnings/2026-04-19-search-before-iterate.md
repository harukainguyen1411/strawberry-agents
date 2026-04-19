---
agent: evelynn
date: 2026-04-19
topic: search-before-iterate
---

# Search before iterating on platform-level mysteries

## What happened

Three separate times this session, I burned turns iterating on a platform-level issue before searching:

1. **Branch-protection UI bypass** — three API knob changes (`pull_request` → `always`; `User` → `RepositoryRole`; then finally search revealed the underlying GitHub bug).
2. **PR #46 E2E failures** — Vi's first run investigated repeatedly against a changing branch before I killed her and respawned with a tight scope.
3. **Heartbeat existence** — I ran the heartbeat script at every startup for months without asking "who reads this?" until Duong did tonight.

## The pattern

When a system surface is opaque — platform UI, third-party API, tool internals — I default to "try the next knob" because each knob-change is cheap in isolation. It's expensive in aggregate because the total cost of N iterations without understanding is often higher than one deliberate investigation.

## The rule

**On platform/tool mysteries (where I'm not the author of the code I'm interacting with): search first, iterate second.**

Triggers for search:
- API return contradicts observed UI behavior (platform bug suspected).
- "Should work" doesn't work and the next obvious knob didn't help.
- About to spend >1 turn on a knob change.

What to search:
- Official docs for the specific surface.
- GitHub community discussions / Stack Overflow for the exact error phrase.
- Recent issues on the project repo.

## Why I drift

Iterating feels like action. Searching feels like stalling. But action on the wrong surface is a stall dressed in motion.

## Corollary

Same principle inverted for code I own: iterate fast, search rarely. The asymmetry is about authorship — I know my own code's failure modes, I don't know GitHub's.
