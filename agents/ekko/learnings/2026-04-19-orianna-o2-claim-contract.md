# Learnings — Orianna O2.1 + O2.2 (Claim Contract + Allowlist)

**Date:** 2026-04-19
**Tasks:** O2.1, O2.2 from `plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md`

## What happened

- The tasks file was in `plans/approved/` (not yet promoted to `in-progress/` by Yuumi) — checked both paths as instructed.
- `agents/orianna/` directory already partially existed from the O1.2 scaffold session. Specifically, `claim-contract.md` was already committed in `3d6be4d` with full content (the O1.2 agent created the full file, not just a stub).
- `allowlist.md` was new — written and committed in `6c30f7c`.
- Both acceptance criteria verified: `contract-version: 1` present; `grep -c '^- ' allowlist.md` = 48 (threshold was 10).

## Key patterns

- When a task says "create file X", always check if a prior session already created it. Read `git log -- <path>` before writing.
- The O1.2 session committed a full `claim-contract.md` rather than a stub. This is good — O2.1 work was effectively done there. O2.2 (allowlist) was the only new deliverable for this session.
- `git add <specific-file>` followed by a commit still produces a clean commit even if the other named file had no delta (no error, no extra noise).
