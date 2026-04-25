# PR #56 fidelity review — resolved-identity enforcement (post-PR#45 pivot)

Date: 2026-04-25
PR: https://github.com/harukainguyen1411/strawberry-agents/pull/56
Plan: `plans/approved/personal/2026-04-25-resolved-identity-enforcement.md`
Verdict: APPROVE (with 3 drift notes)

## Context

This PR is the architectural pivot derived from MY OWN PR #45 review — the NEW-BP-4..12 bypass set I identified. Plan moved primary gate from PreToolUse shell-source scan (PR #45) to pre-commit + pre-push reading post-expansion ground truth.

## Lessons learned

- **Self-derived plans need extra rigor on the fidelity matrix.** When a plan descends from your own findings, the temptation is to anchor on "is the architectural intuition right?" Instead, mechanically walk every NEW-BP-* item against the new gate and verify the test actually exercises the bypass shape — not just the post-resolution observable.
- **NEW-BP-10 (commit-tree) is the only bypass that genuinely demands a different gate.** The other 8 (line-cont, backtick, `$(...)`, eval, `$V`, cat, sh -c, bash -c) all collapse to "set persona config, observable at commit time" once you read `git var`. That collapse is correct architecturally, but it means the test suite shape collapses too: 8 tests become near-duplicates of CTRL-1, with the rename being misleading. Worth flagging as a drift note (DN-2 in the review).
- **Regex word-boundary anchors that require space-or-start are brittle for `<email@domain>` formats.** `(^|[[:space:]])persona(space|$|non-alnum)` does NOT match a persona token wedged inside `<persona@domain>` because `<` is neither start-of-string nor whitespace. Closed in this PR by the `@strawberry.local` catch-all, but a non-strawberry-domain persona email slips both. Filed as DN-3 for follow-up hardening.
- **"Smoke fails closed" is plan-prompt phrasing, not always plan-DoD phrasing.** The dispatch prompt said "smoke fails closed if a hook can't be loaded." Plan §T8 DoD said "output greps OK for each." Implementation accumulates `_smoke_fail` and warns but exits 0. Strictly speaking that's plan-DoD-compliant; flagging as drift (DN-1) honors the prompt without escalating to block.
- **Self-derived plan reviews need to disclose the recursion.** I noted in the review that NEW-BP-10's commit-tree test was the only one where I had to verify closure carefully — being explicit about which claim required real verification (vs. follow-from-design) gives Senna and Duong a clean handoff.

## Review structure that worked

Bypass closure proof as a table — one row per NEW-BP-N with the gate that closes it and the mechanism — makes the load-bearing claim auditable in 30 seconds. Future fidelity reviews of multi-bypass closure PRs should reuse this shape.

## Files cited

- `scripts/hooks/pre-commit-resolved-identity.sh:46-48,53,57,67-81,94-104`
- `scripts/hooks/pre-push-resolved-identity.sh:43-57`
- `scripts/hooks/pretooluse-subagent-identity.sh:1-25`
- `tests/hooks/test_pre_commit_resolved_identity.sh` (full file)
- `tests/hooks/test_pre_push_resolved_identity.sh:171-184` (the genuine commit-tree test)
- `scripts/install-hooks.sh:139-167`
- `architecture/git-identity-enforcement.md` (full file)
