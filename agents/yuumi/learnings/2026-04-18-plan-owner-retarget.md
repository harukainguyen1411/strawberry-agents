---
date: 2026-04-18
topic: plan-owner-retarget
agent: yuumi
---

# Plan owner retarget — mechanical rewrite pattern

When a plan's target repo ownership changes, the correct pattern is:

1. Read the full file first to map all occurrences before editing.
2. Use targeted Edit calls (not replace_all) to handle context-sensitive cases — some occurrences need different treatment (e.g. keeping private repo slug untouched while rewriting the public one).
3. After all edits, grep for the old slug to confirm zero remaining instances.
4. Update renumbered step references everywhere they appear (e.g. rollback table step numbers must stay in sync with phase step numbers when a step is deleted).
5. Acceptance criteria and risk register mitigation text often duplicate slug references — easy to miss; always grep at the end.

The `Duongntd/strawberry` (private repo) slug must be preserved throughout — only the public new-repo slug changes. The grep confirmation at the end caught two late-discovered instances (R11 and §4.6 find/replace instruction).
