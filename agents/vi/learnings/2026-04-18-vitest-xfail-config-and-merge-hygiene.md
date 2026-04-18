---
date: 2026-04-18
topic: vitest xfail config defect + pre-push merge hygiene
---

# Vitest xfail exclude defect + merge hygiene

## Defect: never exclude xfail files from vitest config

Adding `exclude: ["**/*.xfail.test.ts"]` to vitest.config.ts silently skips all
xfail-marked tests. This makes tdd-gate.yml a no-op — it sees no xfail markers,
so CLAUDE.md rule 12 (xfail-first) is unenforceable.

**Correct pattern:** xfail files must be included in the test run. `it.failing`
tests execute and Vitest records them as expected-failures. No exclude needed.

## Hygiene: merge origin/main before pushing

Branches cut from a stale base accumulate plan-file drift that shows up as
unrelated adds/deletes in the PR diff. Run before every push:
```
git fetch origin && git merge origin/main
git diff origin/main --stat   # verify only intended files changed
```
Not rebase — merge (rule 11).
