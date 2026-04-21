# Orianna Signing — Follow-up Speedups (session 2)

**Date:** 2026-04-21
**Reporter:** Sona
**Context:** Companion to `feedback/2026-04-21-orianna-signing-latency.md` (commit `be98f9b`). This session (~4 ADRs × 2 phases × ~3 iterations ≈ 30+ signing commits) surfaced four process failure modes the first feedback doc didn't capture. All four are mechanical; none require Orianna prompt changes.

---

## 1. Pre-commit body-hash guard: catch signature invalidation at the edit, not at promotion

### Today's failure

Yuumi inlined Tasks into three signed ADRs in good faith (commits `26bfe59`, `25adbe6`, `1fbbec8`). Each edit silently invalidated the `orianna_signature_approved` block that was already in frontmatter. Nothing blocked the commits. The invalidation was only discovered when Yuumi dispatched the promotion Ekko, who ran `scripts/plan-promote.sh` and hit `orianna-verify-signature.sh` failing the carry-forward check. Recovery: move each ADR back to `proposed/`, flip frontmatter `status:`, re-sign at `approved`, re-promote. Two Ekko dispatches, ~50 min wall time, and a new Ekko learning at `agents/ekko/learnings/2026-04-21-orianna-re-sign-after-body-edit.md`.

### What the toolchain has today

`orianna-sign.sh` embeds a body-hash in the signature block. `orianna-verify-signature.sh` recomputes it and refuses to promote on mismatch. **The detection exists — it just fires at promotion time, after the invalidating commit has already been merged and other commits may have stacked on top.**

### Proposal

Add `scripts/hooks/orianna-body-hash-guard.sh` to the pre-commit chain. For every plan file in the staged diff carrying any `orianna_signature_*` block, recompute the body hash and compare it against the stored hash. On mismatch:

```
✘ Plan body edited after signing:
    plans/approved/work/<slug>.md
    stored hash:   8f50da6…
    computed hash: a1b2c3d…

Body edits invalidate the Orianna signature. To recover:
  1. git mv plans/approved/work/<plan>.md plans/proposed/work/
  2. Set `status: proposed` in frontmatter
  3. Commit ("chore: revert <slug> to proposed for re-sign after body edit")
  4. scripts/orianna-sign.sh <plan> approved
  5. scripts/plan-promote.sh <plan>

Escape hatch for mid-re-sign flow: the body+signature commit shape
(see follow-up #2) carries a trailer that allows coexistence.
```

### Why it works

Shifts the failure from "found during promotion after three unrelated commits piled on" to "blocked at the moment of the mistake." Recovery procedure becomes self-documenting because the error message IS the runbook. Cost on the happy path is sub-millisecond: SHA recompute per staged plan file.

### Caveats

Depends on the body-hash function in `orianna-verify-signature.sh` being reproducible (canonical whitespace, stripped signature block, stable YAML key order). If it isn't, this proposal first requires stabilizing that.

---

## 2. Signed-fix commit shape: collapse body-fix + signature into one atomic commit

### Today's failure

`pre-commit-orianna-signature-guard.sh` forces every signature commit to touch only the signature line. Correct in intent: prevents someone sneaking body edits into a signature commit. The cost is that the iteration loop today is:

```
iteration N:
  1. orianna-sign.sh <plan> <phase>     ← findings, exit non-zero
  2. edit plan (suppressors, requalify, LOCK/DEFER)
  3. git commit "chore: orianna fixes for <slug> <phase>"   ← body-only
  4. orianna-sign.sh <plan> <phase>     ← re-run, clean
  5. git commit "chore: orianna signature for <slug>-<phase>"   ← sig-only
```

Two commits per successful iteration. Three iterations per ADR per phase = 6 commits. Today's run: up to ~36 signing commits across MAD/MAL/BD/SE × approved + in_progress. Each commit fires pre-commit hooks (secret scan, structure check, package tests), commit-msg validators, pre-push hooks. That's where the drag compounds on top of Orianna's own ~90–180s per fact-check pass.

### Proposal

Let the signature guard accept a second commit shape:

```
Allowed shapes for commits touching orianna_signature_<phase>:
  A. Signature-only — current behaviour.
  B. Signed-fix — body changes AND signature block change, IF:
     - the commit carries a `Signed-Fix: <phase>` trailer
     - the computed body-hash AFTER the commit's diff is applied equals
       the hash embedded in the new signature block
     - the only file touched is the plan itself
```

`orianna-sign.sh` adopts shape B when it applies fixes itself (e.g. when the (a) batch-fix pre-pass or (d) auto-requalify from the first feedback doc are in play) — it writes body fixes AND the new signature in one commit with the `Signed-Fix:` trailer.

### What this enables

One commit per successful iteration instead of two. Half the hook runs, half the commit ceremony. Stacks cleanly with (a) batch-fix pre-pass and (d) auto-requalify from the first feedback: those options produce deterministic fixes, and this proposal lets them land atomically with the signature.

### Why the invariant still holds

The guard's original goal — prevent sneaked-in body edits from coexisting with a signature — is preserved. Under shape A the rule is structural (no other changed lines); under shape B it's cryptographic (hash must match). Cryptographic enforcement is strictly stronger: today's rule doesn't catch a one-character edit in a suppressor comment because line-delta is trivial; the hash-match rule catches it.

### Caveats

- Shares the reproducibility dependency with proposal #1.
- Doesn't shorten iterations whose first fix unmasks a second finding — those still take multiple Orianna runs. But each run is now one commit instead of two.
- The `Signed-Fix:` trailer is a soft audit signal; the hash check is the real enforcement. Trailer exists so humans can grep log history to separate fix-and-sign commits from pure sig commits.

---

## 3. Stale `.git/index.lock` recovery wastes a full agent dispatch

### Today's failure

Ekko #2 (a247066d…) hit a stale `.git/index.lock` mid-operation while re-signing MAL+SE. It halted with a prompt asking Sona to manually clear the lock. Sona cleared and had to dispatch a fresh Ekko (ab3333fa…) with a "resume from where the previous Ekko died" prompt, which had to reason about a partially-moved SE file, uncommitted plan-fact-check artifacts, and the incomplete MAL work. That's a full round-trip that produced no new signed state — the replacement Ekko spent its first ~1 min of context just mapping the interrupted state before it could act.

### Proposal

`orianna-sign.sh` (and `plan-promote.sh`) detect a stale `.git/index.lock` at start of run and auto-clear it with a loud audit line when:

1. The lock file's mtime is older than 60s, AND
2. No git process currently holds it (`lsof .git/index.lock` empty).

Audit format:

```
⚠ Stale .git/index.lock detected (age: 247s, no holder). Auto-clearing.
  If this is unexpected, check prior agent transcript at /tmp/claude-501/.../tasks/<id>.output
```

### Why it's safe

Within these scripts, the agent running them is the only writer. A lock older than 60s with no holder is definitionally stale — no concurrent git operation will be interrupted by clearing it. The audit line ensures it's diagnosable after the fact.

### Caveats

Scope this to Orianna's own scripts; don't make it a global git wrapper. If Duong is running a parallel git operation manually, we don't want to clobber it — but Orianna scripts only ever run under dispatched agents, so the scope is naturally bounded.

---

## 4. Sibling `-tasks.md` pattern vs §D3 one-plan-one-file: pick one and enforce early

### Today's failure

Kayn + Aphelios decomposed MAD/MAL/BD into sibling `-tasks.md` files (e.g. `plans/approved/work/2026-04-20-managed-agent-dashboard-tab-tasks.md`) because that's how earlier ADRs were shaped. Plan lifecycle §D3 ("one plan, one file") forbids that shape: tasks must live inlined under a `## Tasks` heading in the ADR body. Orianna's `in_progress` gate enforces §D3 and blocked all three ADRs simultaneously. Recovery: Yuumi inlined tasks + deleted siblings (commits `26bfe59` / `25adbe6` / `1fbbec8`), which in turn invalidated the approved signatures (failure mode #1 above), which triggered the revert-to-proposed recovery loop.

Cascade: a shape mismatch at authoring time → a body edit at repair time → a signature invalidation → a full re-sign cycle. All three task files existing in `approved/` was the root cause.

### Proposal

Pick one canonical shape and enforce it at plan-structure-check time, which runs as pre-handoff on the planner (Kayn/Aphelios/Azir/Swain) rather than at Orianna sign time.

**Option A (preferred).** Planners always inline. `scripts/check_plan_structure.py` errors if a `-tasks.md` sibling exists in the same directory as an ADR.

**Option B.** §D3 grants sibling `-tasks.md` as a recognized shape. Orianna's `in_progress` gate is updated to accept it. Planners stay as-is.

Either is cheaper than today's drift. Option A is preferred because it keeps the plan-as-one-file invariant clean for tooling (grep, plan-promote, fact-check) and the signature hash calculation.

Enforcement point: `scripts/check_plan_structure.py` runs pre-commit AND in the planner agent's task-close step. Either layer catches the mismatch before the plan reaches Orianna.

### Caveats

Migration: existing sibling-shaped tasks files in `plans/approved/` and `plans/in-progress/` (there shouldn't be any after today's cleanup, but audit via `find plans -name '*-tasks.md'`). Either inline them or re-approve as-is depending on the chosen option.

---

## Rollup

Four fixes, all mechanical, all independent. Severity and cost:

| # | Proposal | Today's cost | Fix cost | Fires when |
|---|----------|--------------|----------|------------|
| 1 | Body-hash pre-commit guard | ~50 min × one incident/session | Small shell script + hook wiring | Anyone edits a signed plan body |
| 2 | Signed-fix commit shape | ~5–15s × 30+ commits = 3–8 min/session | Guard hook update + orianna-sign.sh contract change | Every sign iteration |
| 3 | Stale lock auto-recovery | Full agent dispatch round-trip when it fires | 5-line detection block in the scripts | Rare, but each occurrence is expensive |
| 4 | Sibling-tasks vs §D3 | Root cause that triggered #1 today | Update check_plan_structure + planner agent task-close | Each new ADR decomposition |

Stacked with the first feedback doc's option (a) batch-fix pre-pass and option (d) auto-requalify, this brings sign iterations from ~2–3 down to ~1 and commits per iteration from 2 down to 1 — a 4–6× wall-time reduction at the ceiling, without touching Orianna's prompt.

My call: ship #4 first (prevents today's root-cause recurring), then #3 (tiny, cheap, kills an occasional killer), then #1 and #2 together (they share the body-hash dependency and are worth designing as a pair).
