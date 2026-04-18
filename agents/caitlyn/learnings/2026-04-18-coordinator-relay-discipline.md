---
date: 2026-04-18
role: caitlyn
topic: coordinator patterns — relay discipline, duplicate sessions, TaskList truth
---

# Coordinator relay discipline — when to relay, when to stand down

Managed ~30 tasks / ~15 PRs / ~8 parallel agent sessions across a Phase-1-exit push today. Patterns worth carrying forward.

## Parallel sessions for same task

Saw ~3 cases where two sessions independently picked up the same task and delivered overlapping PRs:
- C2: ekko (#161 verify-only) + ekko-c2 (#165 real hook change). Evelynn ruled which wins; I had to empirically verify the ruling (npm-workspace vs pnpm-workspace check).
- F3 CORS: viktor-i1 (#181) + viktor (#182). Same branch duplication pattern.
- D1 fixes: jayce-d1 for some fixes, jayce for others, on same branch `chore/d1-report-run`.

**Pattern:** Evelynn spawns multiple sessions on the same task (deliberately or inadvertently). Each works in isolation. I see their deliveries through inbox but TaskList doesn't distinguish them.

**Coordinator response:**
- Accept that "one task = multiple sessions" is real. Don't treat it as a bug.
- When two PRs for the same task arrive: compare empirically, report substantive differences to Evelynn for ruling, delegate the close to Yuumi with drafted comment.
- TaskList `owner` field can hold only one name; when sessions split, track the session that delivered the canonical PR.

## Inbox staleness

Messages from teammates frequently arrived referring to state that had already changed ("still blocked on X" when X was fixed 20 min prior). This was bidirectional — me to them, them to me. Causes:
- Session memory doesn't update mid-session; inbox messages are snapshot-in-time
- `gh pr view` and similar bypass caches; `git show origin/<branch>:<path>` does too
- Narrative framing ("we're waiting on Viktor") persists past the event it describes

**Coordinator response:**
- When receiving "still blocked on X" after I know X is fixed: reply with fresh ground-truth (SHA + short diff quote), not with "you're wrong."
- When sending updates: include SHA + explicit "as of <date/time>" framing so the receiver knows the snapshot.
- Stand down faster. Not every stale restate requires a response.

## Board as truth

TaskList on the shared board ran ahead of my session memory multiple times — Evelynn marked tasks completed/in_progress based on signals I didn't see. Initially treated this as drift to correct. Eventually accepted: the board is Evelynn's truth. My job is to honor it, not to enforce my private tracking against it.

**Standing posture:** `TaskList` at session start/pulse is ground truth; I only set `owner`/`status` when I'm directly observing delivery. Don't speculate.

## Relay pattern

- Forward findings from reviewer to implementer with exact SHAs, diff quotes, fix-pattern suggestions, and explicit action asks.
- When relaying reviews with stale content: include ground-truth shell commands the reviewer can run to verify their view.
- Consolidated pings ("6 PRs need your LGTM with table") > drip-fed pings ("PR #X now; PR #Y now; PR #Z now") — saves reviewer context loads.

## Governance escalations

Built a running list of 4 items across the day for Evelynn → Duong escalation:
1. Rule 18 breach (zero-review admin merge)
2. pre-push-tdd.sh scan-delta logic gap (false-blocks cosmetic commits post-xfail-land)
3. GH formal review state vs comment-LGTM (affects rule 18 enforcement)
4. Extend-LGTM-absent-arch-changes reviewer policy (positive, worth formalizing)

Governance items accrue naturally as coordinator — ~4 per high-velocity day. Keep the running list; flag to Evelynn at natural pauses; let her decide timing of Duong escalation.
