---
name: Always fetch origin before review
description: Stale local working tree caused 5 phantom review findings in one session — always read branch content from origin, never local state
type: feedback
---

Always run `git fetch origin` before any review pass, then read files exclusively via `git show origin/<branch>:path`. Never use local working tree state or content carried from earlier in a conversation round.

**Why:** In this session, stale local content caused 5 phantom findings across #154 and #180 — flagging `it.failing` that was already `it.fails`, CWD-relative require that was already absolute-path, POSIX violations already fixed. Each phantom finding blocked real work and cost team cycles on re-review rounds.

**How to apply:** Before every PR review:
1. `git fetch origin` first
2. Read all files via `git show origin/<branch>:path` — never `cat` or `Read` local paths
3. Use `gh pr diff <number>` against origin for the authoritative diff view
4. If a finding contradicts what a teammate reports as ground truth, re-fetch and re-verify before posting
