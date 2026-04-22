# PR #19 — Orianna gate speedups plan fidelity (14/16 tasks)

Date: 2026-04-22
Verdict: APPROVE
Review: posted via strawberry-reviewers (default lane)

## What landed
14 of 16 tasks from `plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md`:
- Rakan's xfail commits for T1/T3/T6/T8 precede each paired impl commit (Rule 12 clean)
- Viktor's impls: T2, T4, T5+T10 (single commit — plan allows), T7, T9, T11.c (with own inline xfail)
- Docs+research: T11, T11.b, T-prompt-1 (attributed to Lux out-of-band)
- Deferred: T-prompt-2, T-prompt-3

## Key technique reinforced
When a PR does NOT touch the Orianna-signed plan file, you can skip the body-hash verification step — the signatures are definitionally unaffected. Check `gh pr diff N --name-only` first; if the plan is absent, Rule 19 concern collapses. Precedent: contrast with PR #12 where the plan was in-diff and body-hash drift was the main gate.

## Subsumption call
When the delegation prompt flags adjacent-plan overlap, READ THE ADJACENT PLAN — don't just trust the prompt's summary. Here, `2026-04-22-orianna-substance-vs-format-rescope.md` rewrites `agents/orianna/prompts/*.md` and bumps `claim-contract.md` to v2, which strictly supersedes T-prompt-2/3's target intent (over-citation reduction). Gave a confident SUBSUME recommendation, not a vague "overlap."

Caveat captured: target-path divergence — T-prompt-2 points at legacy `.claude/_script-only-agents/orianna.md`, rescope uses new `agents/orianna/prompts/` layout. Flagged as a sub-5-min janitorial task for Orianna to decide on next pass, not a blocker.

## Rule 12 verification pattern
Commit-chronology ordering via `gh pr view <N> --json commits` with `authoredDate` stamps is sufficient. No need to fetch individual patches unless you want to confirm xfail-sentinel shape. In this PR the xfail commits were self-attested in their commit bodies ("committed before TN per Rule 12") which was a strong signal. Spot-check one patch only if a commit's self-attestation is vague.
