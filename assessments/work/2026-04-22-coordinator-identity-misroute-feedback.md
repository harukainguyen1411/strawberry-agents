# Feedback: coordinator-identity misroute on post-compact resume

**Date:** 2026-04-22
**Surface:** End-of-session close on session `0cf7b28e` (demo-studio-v3 chat rendering work)
**Severity:** Medium — caught by Duong mid-close; no data loss, but wrote 7 artifacts to the wrong agent tree before revert.

## What happened

At session close (`/end-session`), I self-identified as **Evelynn** and began executing the personal-concern close protocol. I wrote:

- `agents/evelynn/transcripts/2026-04-21-0cf7b28e.md` (transcript from prior Step 2)
- Journal append to `agents/evelynn/journal/cli-2026-04-21.md`
- `agents/evelynn/memory/last-sessions/0cf7b28e.md` (handoff shard)
- `agents/evelynn/memory/sessions/0cf7b28e.md` (session shard)
- `agents/evelynn/memory/open-threads.md` (updated)
- `agents/evelynn/memory/last-sessions/INDEX.md` (regenerated)
- `agents/evelynn/learnings/2026-04-22-fastapi-dependant-graph-mock-contamination.md`

All seven were under `agents/evelynn/**`. **The session's actual work concern was entirely work** — `demo-studio-v3` under `~/Documents/Work/mmp/workspace/company-os/tools/` — so the correct coordinator was **Sona**, not Evelynn.

Duong caught the error: *"what, you're sona not evelynn"*. Unstaged, deleted the new files, reverted the edits, re-ran the cleaner targeting `sona`, and redoing the close under the correct coordinator.

## Root cause

**The compaction summary locked in the wrong identity, and I didn't re-derive it from first principles on resume.**

Decomposed:

1. **Pre-compact session identity was already Evelynn** (or was ambiguous and drifted to Evelynn). The repo-root `CLAUDE.md` says: *"No greeting given → you are Evelynn by default (personal concern is the historical default of this repo)."* Whatever started the pre-compact session — likely an autonomous cron fire like `<<autonomous-loop>>` or a prompt without an explicit "Hey Sona" greeting — hit the Evelynn default.

2. **The actual work drifted to work-concern** mid-session. Duong's standing overnight cron directive points at `http://localhost:8080` for `demo-studio-v3`, which lives in the work tree. The session did work-concern work under an Evelynn coordinator header for some time. The drift went uncorrected.

3. **Compaction preserved the identity tag**. The summary narrative referred to me throughout as Evelynn and pre-loaded the Evelynn CLAUDE.md. The post-compact resume inherited Evelynn without re-validating against the concern indicators (working directory = `~/Documents/Work/mmp/workspace/`, branch = `feat/demo-studio-v3`, subject matter = work-repo code).

4. **The `/end-session` skill takes the agent name as an argument** and doesn't itself verify that the argument matches the session's concern. When Duong or the resuming model types `/end-session evelynn`, the skill trusts the label.

5. **I didn't catch it** because I read the compaction summary and walked directly into the Evelynn skill protocol without a concern-check.

## Why this is a class of bug, not a one-off

The same failure mode will recur whenever:

- A session starts without an explicit coordinator greeting (→ defaults to Evelynn)
- The work performed is actually work-concern (happens frequently when Duong's cron directives target work repos)
- A `/compact` happens before `/end-session`
- Post-compact resume takes the cached identity without re-deriving

Any two of those four is enough to hit this. All four fired today.

## Contributing factors

- **"No greeting → Evelynn default"** is a blunt rule. It was fine when the repo only ran personal-concern work; now that both concerns share this repo and Sona has her own tree, the default should be "detect concern from context and refuse if ambiguous" — not "assume Evelynn."
- **Concern ≠ coordinator identity, but is coupled to it.** The repo-root CLAUDE.md treats the split correctly in principle (personal → Evelynn, work → Sona) but there's no programmatic check that binds them. An Evelynn session doing work-concern work is a structural violation that no hook catches.
- **Compaction is identity-sticky.** The Lissandra pre-compact-save skill preserves whatever identity the session held, including wrong identities.
- **The `/end-session` skill argument is trusted, not verified.** It never asks "does this agent name match the work you just did?"

## What a fix should do

Rough ideas, not a plan:

1. **Concern detection at session start** — not just coordinator name. If the first few user messages or cron fires target a work-concern path (working directory heuristics: `~/Documents/Work/mmp/workspace/` in tool paths, branch names matching work patterns, file reads of `tools/demo-studio-v3/**`, etc.), the session should bind `concern: work` and route to Sona regardless of greeting state.
2. **Concern-coordinator consistency hook** — at `/end-session` time (and ideally sooner), assert that the declared coordinator's concern matches the session's actual work surface. Fail closed if they disagree.
3. **Post-compact identity re-validation** — the first action after `/compact` resumes should be a concern-re-check against the last ~5 tool calls or working-directory signals. Treat the compaction summary's identity as a hint, not a binding.
4. **`/end-session` skill argument verification** — the skill should refuse to close as `evelynn` if the session's dominant concern was work, and vice versa.
5. **Default escalation, not silent fallback** — if no greeting and no concern signal, the session should ask before picking a coordinator. "Default to Evelynn" is worse than "ask."

## How this one got fixed this turn

- User correction at `/end-session` step 8 (Learnings)
- Unstaged all Evelynn paths: `git reset HEAD agents/evelynn/`
- Deleted new files, `git checkout HEAD --` reverted modified files (journal append + open-threads.md + INDEX.md)
- Re-ran cleaner targeting Sona: `agents/sona/transcripts/2026-04-21-0cf7b28e.md`
- Continuing the close under `agents/sona/**`

## What I want my next self to hold

Concern-check is the first action on any resume, compacted or fresh. Read the last user message and the first few tool paths. If they point at `~/Documents/Work/mmp/workspace/`, I'm Sona. If they point at `~/Documents/Personal/`, I'm Evelynn. If ambiguous, I ask. The compaction summary's identity tag is advisory only.
