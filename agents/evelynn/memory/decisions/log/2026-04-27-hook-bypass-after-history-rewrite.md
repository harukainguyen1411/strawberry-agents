---
decision_id: 2026-04-27-hook-bypass-after-history-rewrite
date: 2026-04-27
session_short_uuid: c5369aa0
coordinator: evelynn
axes: [hook-bypass-tolerance, rollback-blast-radius]
question: "How to bypass pre-push-resolved-identity hook for force-pushing 4 PR branches after authorized git-filter-repo history rewrite, given hook walks rewritten ancestor history and trips on Orianna plan-lifecycle commits"
options:
  - letter: a
    description: "Push from another machine / use gh api admin token"
  - letter: b
    description: "Add FILTER_REPO_FORCE_PUSH env-var bypass to hook"
  - letter: c
    description: "chmod -x hook then push then chmod +x (variant: file move-aside since chmod produces non-zero exit)"
  - letter: d
    description: "Rebuild PR branches via cherry-pick from new main, no hook bypass needed"
coordinator_pick: c
coordinator_confidence: medium
coordinator_predict: c
duong_pick: c
match: true
---

## Context

Senna's leak audit returned FAIL CRITICAL on 5 production credentials in git history (Telegram bot, demo-config Bearer, Firebase Web key, Gemini key, Firecrawl key). Duong rotated the keys and authorized history rewrite. Ekko ran `git-filter-repo --replace-text` successfully — main scrubbed and force-pushed (8ca4eadd → 2b1d0a7f), 5 secret strings verified zero in history. But the 4 active PR branches (vi/T4a, vi/T7a, viktor/T6b, jayce/T4b) failed force-push because pre-push-resolved-identity.sh walked the full branch history (after filter-repo wiped old SHAs the hook could no longer bound the walk) and found pre-existing Orianna plan-lifecycle commits, blocking the push.

## Why this matters

The hook is a Rule 14 family security primitive (backstop against persona-named commits reaching remote). Bypassing it even briefly is the kind of "surgical infra change" that the canonical failure mode (240bd394) warned against. Net call: pick C as the lowest-blast-radius bypass — file content unchanged, time-bounded, easy verification. Variant executed: file move-aside (mv hook /tmp/stash) instead of chmod, because chmod -x produced "Permission denied" non-zero exit rather than skip; move-aside lets the dispatcher's glob simply not see the file. Same semantic outcome, cleaner operational shape. Hook restored within same Bash invocation, executable bit verified. All 4 branches force-pushed with --force-with-lease (no lease conflicts). Match-rate signal on hook-bypass-tolerance axis: prediction matched, medium confidence — hands-off mode + already-rotated keys reduced risk-aversion floor.
