# 2026-04-25 — "Verify the verify" + post-compact summary is not source of truth

## Triggering incident

Session c1463e58, post-compact second leg. Akali ran RUNWAY QA on PR #32 (missmp/company-os) and returned two F-blocker findings as **chat-text only** (she was blocked from writing the .md report by an internal rule):

- F1: `tools/demo-studio-v3/tool_dispatch.py:127` imports v1 `factory_bridge`, should be v2.
- F2: `tools/demo-studio-v3/main.py:5` does `load_dotenv(".env.local", override=False)` — `.env.local` is baked into the Docker image with `S5_BASE=http://localhost:8090` killing the prod runway.

Across the /compact boundary, those chat-text findings got baked into my own "Files and code sections" summary as if I had verified them. Post-compact, I dispatched Karma quick-lane to plan a fix against them without re-verifying.

Duong asked: *"Did you check Akali's result or did you simply trust her?"*

I tried to verify, but I read the **wrong worktree** (`feat/p1-t13b-demo-ready-panel` HEAD, instead of PR #32's actual head `ab51372` on `feat/demo-studio-v3`). On that wrong tree, the cited lines did not match Akali's claims — so I declared her findings fabricated and escalated a wrong narrative to Evelynn as evidence for a critique of Akali's QA discipline.

When I re-read against the correct tree, both findings were exactly as Akali described. I had to retract the confabulation charge and apologize via Evelynn inbox `20260425-0749-103350.md`.

## What I should have done differently

Two distinct disciplines:

**1. "Verify the verify" reflex.** When I'm about to declare an agent's findings false and escalate that as a structural critique, the verify step itself needs a sanity check that I'm reading the right tree/branch/commit. The cheap shape:

- Get the PR/branch HEAD SHA explicitly: `gh pr view <N> --json headRefOid`.
- Read via `git show <sha>:<path>` or `git -C <worktree> log -1 --format=%H` to confirm the worktree HEAD matches the PR HEAD before reading.
- If they differ, re-read against the right anchor before drawing conclusions.

The cost of this discipline is ~10 seconds per verify. The cost of skipping it today was an unfounded character attack on a teammate plus an escalation to Evelynn that I had to retract.

**2. Post-/compact own-summary is suspect, not authoritative.** My own post-compact summary baked Akali's chat-text findings into "verified facts" complete with file paths and line numbers, even though I had never personally verified them. The deliberation primitive (PR #49) doesn't fire on "internalizing your own summary as truth" — only on tool calls. By dispatch time the false claim was already structural to my reasoning.

The discipline: when an inherited-context fact (anything that came in via the post-compact summary, prior session memory, or another agent's report) is about to drive a state-mutating dispatch, treat it as still-suspect until I have either (a) verified it this session via my own tools, or (b) explicitly noted the inheritance and accepted the risk.

## Generalization

The two failure shapes share a root: discipline-only gates fail under load when the failure mode is "trust an inherited fact." Hooks can't see "I'm trusting an inherited fact"; they only see "I'm calling Agent." Without a hook-backed verify-before-dispatch, the gate is purely prompt and breaks under autonomous-mode pressure.

Sister fixes already raised to Evelynn:
- `20260425-0739` + `20260425-0744` + `20260425-0749` (corrected): Akali post-use verify + scope discipline + Lux/Swain consultation on QA architecture.
- `20260425-0729`: SessionStart-on-compact watcher-arm source-gate (same shape — literal-vs-goal hook directive).

Both target the structural surface, not the discipline surface.

## Operational rules adopted

1. **Before declaring an agent's findings false, confirm `<branch> @ <sha>` matches the PR head.** Use `git show <sha>:<path>` or worktree-pin to anchor.
2. **Treat post-/compact own-summary facts as suspect** when they drive a state-mutating dispatch. Verify this session.
3. **Sister-fix asymmetry**: when one of N structural fixes ships and the others stay queued, re-raise the unshipped ones the next time their failure mode recurs — don't assume "in queue" means "tracked."

## Cross-references

- Triggering session: c1463e58 (this one)
- PR involved: missmp/company-os PR #32 (Wave D RUNWAY ship), PR #119 (the F1+F2 fix)
- Akali run artifacts: `assessments/qa-reports/2026-04-25-runway-{11..14}.png` (4 PNGs from the actual Playwright run — symptoms were real)
- Retraction inbox: `agents/evelynn/inbox/20260425-0749-103350.md`
- Open-threads thread: "Akali-QA reminder hook + inbox direct-write block (2026-04-23)" — line 303 of sona/memory/open-threads.md
