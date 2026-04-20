# Plan claims decay while the plan sits in `proposed/`

**Context:** Applied Orianna's fact-check findings to `plans/proposed/2026-04-20-agent-pair-taxonomy.md`. Block finding: §Context referenced `plans/proposed/2026-04-20-orianna-gated-plan-lifecycle.md` — but that plan had been promoted to `plans/approved/` between the taxonomy ADR's draft and Orianna's re-check.

**The pattern.** A plan in `proposed/` captures the current state of the surrounding repo at authoring time. Every file-path reference, every `.claude/agents/*.md` `effort:` value cited in the narrative, every "exists untracked today" observation is a point-in-time claim. If the plan sits in `proposed/` while the surrounding repo moves (another plan gets promoted; an agent-def gets edited; an untracked file gets tracked), the plan's claims decay. The author cannot catch this decay from inside the plan — their context is the plan's snapshot of the world at writing time.

**Why it matters.** Claim decay is a silent failure mode. The plan still reads as internally consistent, and the decisions are unaffected — but downstream implementers following the stale claims will run different commands (`git add` for an untracked file vs `git add` for a tracked+modified one; `cd plans/proposed/` vs `cd plans/approved/` to read a referenced ADR). Orianna catches this via `test -e` anchors on every path reference; that's the only reliable guard.

**Practical consequence for plan authors.**

1. When citing the current `effort:` or `model:` values of existing agents in motivation/context text, assume those values may be stale by the time Orianna re-checks. Prefer citing the *proposed* tier in the matrix and calling out the current value as "today: high" rather than "Opus-high (current)" — the former invites fact-check, the latter looks settled.
2. When one ADR references another ADR's path, expect the referenced ADR may promote. Write the reference as a stable pointer (title + role) not a path when possible. When a path must be cited, accept that the Orianna re-check will catch the drift.
3. Every *implicit* rescope in the matrix — where a matrix tier differs from the current agent-def's `effort:` without a §D3-style explicit callout — is a fact-check landmine. If the matrix says agent X is Opus-medium and the current file is Opus-high, `§D3` must document the retiering explicitly or the fact-check warn on the mismatch.

**Meta-lesson.** The plan-promote lifecycle is also a fact-check lifecycle. A plan that lives in `proposed/` longer than a day or two should be re-checked against repo state before promotion, not just at authoring time. The warn findings in Orianna's reports are not cosmetic — they pre-empt downstream implementer confusion.
