# Orianna Signing Latency

**Date:** 2026-04-21
**Reporter:** Sona
**Context:** 4-ADR signing pass for `plans/proposed/work/` (managed-agent-dashboard-tab, managed-agent-lifecycle, s1-s2-service-boundary, session-state-encapsulation). Dashboard-tab took ~15 min / 4 commits to flip to `approved`; remaining three projected ~45 min total.

## Why signing is slow

Three compounding costs per sign attempt:

1. **Full fact-check per attempt.** `orianna-sign.sh` invokes Orianna with the complete plan-check prompt. Orianna reads the plan, extracts every load-bearing claim, greps the repo for each anchor, resolves paths through the claim contract (concern-as-root for `work` — walks the workspace monorepo at `~/Documents/Work/mmp/workspace/`), composes findings. A 600-line ADR with dozens of path tokens is **~90–180s** per pass.

2. **Multiple iterations per ADR.** Dashboard-tab took 4 commits (71fd8a5, 0929a4b, b31ecae, e09e245) before clean sign. Each iteration = read fact-check report → reason about fix category (requalify / DEFER / suppress) → compose fix → commit → re-sign. Typical work-ADR has:
   - Legacy `tools/demo-studio-v3/` references that need `company-os/` requalification
   - URL-shaped tokens in backticks (`platform.claude.com/docs/...`) needing suppressors
   - Open questions (§10/§11) with `?` markers needing LOCKED/DEFERRED
   - Cross-ADR plan references that live in workspace but sign against strawberry-agents

3. **Commit ceremony per fix.** Pre-commit hooks (secret scan, structure check, package tests), pre-push hooks, signature trailer generation. Each iteration is a full cycle.

**Result:** 3 ADRs × ~3 iterations × ~2 min Orianna + fix composition ≈ 18–30 min floor for a clean batch.

## Speedup options

### (a) Batch-fix pre-pass — near-term, cheap

One agent sweeps all pending ADRs for known finding categories (legacy `tools/` paths, URL-tokens, unresolved `?` markers) in a single pass **before** the first sign attempt. Cuts iterations per ADR from ~3 to ~1. Would have saved 15+ min on this pass if dispatched first.

**Trigger:** whenever >1 ADR is queued for signing, prepend a batch-fix step.

### (b) Pre-lint at author time — authoring-side

Planners (Azir, Swain, Karma) run `check_plan_structure` + a lightweight claim-contract pre-scan before handing off. First sign attempt is then usually clean or near-clean. Requires a pre-hand-off script in the planner definitions' task templates.

**Trigger:** next planner-definition refresh (Lux/Syndra task).

### (c) Orianna prompt tuning — larger investment

Reduce over-citation (Orianna sometimes flags tokens that are clearly prose like "`main.py`" mid-sentence). Batch anchor lookups so each grep pass can handle multiple anchors at once. Possibly cache the claim-contract resolution across iterations of the same plan. Requires editing `.claude/_script-only-agents/orianna.md` and its plan-check prompt.

**Trigger:** if batch-fix (a) and pre-lint (b) don't bring median sign-time under 5 min per ADR.

### (d) Auto-requalify for `concern: work` — mechanical

Before Orianna runs, a shell pre-pass inside `orianna-sign.sh` rewrites bare `tools/demo-studio-v3/` → `company-os/tools/demo-studio-v3/` (and similar known-safe workspace prefixes) in the plan itself, or feeds a rewritten copy into Orianna. Deterministic, no semantic risk for well-known prefixes. Requires a whitelist of auto-requalify rules.

**Trigger:** if this pattern repeats across more ADRs.

## Governance concern (separate from latency)

`<!-- orianna: ok -->` suppression markers are unpoliced — no reason enforcement, no count cap, no audit trail beyond commit history. Already noted in `agents/sona/learnings/2026-04-20-orianna-suppression-gap.md`. Speedup (a) will likely add more suppressors; worth pairing with a suppression-audit plan.

## My recommendation

Ship (a) as a one-off skill or script (e.g. `scripts/orianna-pre-fix-work-adr.sh`) that does the three mechanical rewrites before any sign attempt. Medium-term, fold (b) into the next planner-agent refresh so new plans arrive cleaner. Park (c) and (d) until the volume of signings justifies the investment.
