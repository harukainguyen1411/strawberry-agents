# 2026-04-22 — PR 18 & PR 20 paired plan-fidelity review

## PRs
- PR #18 (Viktor) — `inbox-watch-v3` — inbox watcher v3.1 Monitor-driven.
  Plan: `plans/in-progress/personal/2026-04-20-strawberry-inbox-channel.md`.
- PR #20 (Talon) — `feat/orianna-staged-scope` — `STAGED_SCOPE` env-var for
  `orianna-sign.sh`. Plan: `plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md`.

Both approved.

## Key findings / learnings

### Multi-task plans can legitimately map to one impl commit
Inbox plan explicitly slots IW.1–IW.5 into "commit slot 2 (impl)". Don't flag
a 5-task plan with only 2 commits as missing tasks — re-read the plan's commit
slotting section first. Verified by file-to-task map: every IW.* task's Files
section touched in the PR.

### Opt-in env-var semantics are easy to verify via byte-identical else-branch
For PR #20 T2, the `if [ -n "${STAGED_SCOPE:-}" ]` branch contained the new
pathspec logic, and the else branch reproduced the prior `git commit -m "$COMMIT_MSG"`
call *byte-for-byte*. That's the canonical shape for "no behavior change when
unset" — when the else is a copy-paste of pre-patch HEAD, reviewer trust is
maximal.

### Dormant wiring is acceptable IF plan premise is documented
PR #20 T3's export of `STAGED_SCOPE` in `plan-promote.sh` does not actually
flow into any `orianna-sign.sh` invocation today — `plan-promote.sh` only
*prints instructions*. The plan §Context claim "plan-promote.sh is the primary
caller of orianna-sign.sh" is stale. But the impl honors the plan's literal
T3 DoD ("noise remains staged post-promote"), and the wiring is defensive for
future shape-B integration. Senna flagged the same drift independently —
valuable cross-reviewer triangulation. Treat as drift-note, not block.

### Body-hash check is the highest-signal signature gate
Ran `scripts/orianna-hash-body.sh <plan>` on both plans; compared to
`orianna_signature_approved`. Both matched. When a PR touches no plan file,
this check costs one shell invocation and definitively rules out silent plan
drift. Always run it on PRs that carry an ADR anchor.

### Em-dash byte verification
PR #18 watcher emits `\xe2\x80\x94` (U+2014) in `printf` — matches ADR
line-format contract "em-dash — not hyphen". Visual inspection alone is
insufficient; grep for the byte sequence or hex-dump the output.

## Process notes
- `scripts/reviewer-auth.sh gh api user --jq .login` preflight returned
  `strawberry-reviewers` — default lane correct for Lucian (no `--lane` flag).
- Both PRs had green TDD-gate checks (xfail-first + regression) — Rule 12/13 clean.
- Author `duongntd99`, reviewer `strawberry-reviewers` — Rule 18 clean.
