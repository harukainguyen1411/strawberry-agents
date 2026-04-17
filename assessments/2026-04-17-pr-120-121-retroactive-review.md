---
date: 2026-04-17
author: jhin
task: retroactive-review
prs: [120, 121]
---

# Retroactive Review — PR #120 (Jayce P1.0) + PR #121 (Viktor P1.1)

## Overall verdict

PR #121 is **not complete**. Three caller sites for `scripts/deploy.sh` that existed in the repo at merge time were not updated. Two of them are **blockers** for P1.1b because they live in active agent inboxes and one live plan exit criterion; one is a nit. PR #120's audit table is also missing two of those same callers (the Evelynn inbox messages), which is the root cause.

---

## PR #120 — Jayce audit: caller coverage gaps

PR #120 enumerated five caller sites for `scripts/deploy.sh`:

| Listed in #120 | Status |
|---|---|
| `architecture/infrastructure.md:66` | Correct |
| `assessments/2026-04-08-protocol-leftover-audit.md:69` | Correct |
| `plans/implemented/2026-04-09-protocol-migration-detailed.md:884` | Correct |
| `agents/_retired/pyke/inbox/20260403-2320-evelynn-info.md:9` | Correct |
| `agents/_retired/pyke/inbox/20260403-2311-evelynn-info.md:9` | Correct |

**Missing from #120's table — two callers not listed:**

1. `agents/evelynn/inbox/20260403-2311-pyke-info.md:12` — Pyke's completion report to Evelynn, lists `scripts/deploy.sh` as a script it created. Not retired/archived — lives under `agents/evelynn/inbox/`.
2. `agents/evelynn/inbox/20260403-2318-pyke-info.md:33` — Pyke's follow-up to Evelynn: "Once the app code lands, `scripts/deploy.sh` will bring everything up." Same inbox, not retired.

These two are historical inbox messages, not executable callers — they will never run the script. Severity: **nit** for the audit document itself.

---

## PR #121 — Viktor rename: completeness check

Viktor's diff touched three things:
1. `scripts/deploy.sh` → `scripts/deploy-discord-relay-vps.sh` (git rename, 100% content preserved)
2. `architecture/infrastructure.md:66` — updated to new name
3. `scripts/composite-deploy.sh` line 2 — deprecation comment added

**What was correctly updated:** `architecture/infrastructure.md` — the one live doc reference cited in the P1.0 audit.

**What was NOT updated:**

### Blocker 1 — `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md:62`

```
- **Files touched:** `scripts/deploy.sh` (move), `scripts/composite-deploy.sh` (delete or leave), any caller files the audit identified.
```

Line 62 of the active in-progress plan still references the old `scripts/deploy.sh` path (as the file being moved). P1.1b's definition of done at line 65 also says:

```
- The old `scripts/deploy.sh` is renamed (or retained with a temporary wrapper-warning) per P1.0's disposition.
```

And line 67: `scripts/deploy.sh` path is free for the new dispatcher (P1.2).

The plan itself uses `scripts/deploy.sh` in dozens of places as the **new** canonical dispatcher (lines 43, 203, 206, 207, 219, etc.) — that is intentional, those are forward references to the P1.11-built file. But lines 62 and 65 refer to the *old* file being renamed, which is now stale. This is **cosmetic only** — no execution risk.

### Blocker 2 — `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md:236`

```
- Old `scripts/deploy.sh` (if renamed) is listed under its new name.
```

This is P1.13's exit criterion (script-inventory doc refresh). It still says "if renamed" — but the rename has already happened. The criterion is now stale. Not a runtime blocker but a P1.13 executor will have ambiguous instructions.

### Blocker 3 (actual blocker) — `agents/evelynn/inbox/20260403-2311-pyke-info.md:12` and `agents/evelynn/inbox/20260403-2318-pyke-info.md:33`

These two files were not listed in #120's audit and therefore not updated in #121. They reference `scripts/deploy.sh` by name. They are **not executable** — no CI or script reads from `agents/evelynn/inbox/`. Severity: **nit**, not a runtime blocker.

---

## Severity summary

| Finding | File:line | Severity | Impact on P1.1b |
|---|---|---|---|
| #120 missed `agents/evelynn/inbox/20260403-2311-pyke-info.md:12` | `agents/evelynn/inbox/20260403-2311-pyke-info.md:12` | Nit | None — non-executable inbox |
| #120 missed `agents/evelynn/inbox/20260403-2318-pyke-info.md:33` | `agents/evelynn/inbox/20260403-2318-pyke-info.md:33` | Nit | None — non-executable inbox |
| #121 did not update `plans/in-progress/…-deployment-pipeline-tasks.md:62` | `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md:62` | Nit | Stale plan description, no execution path |
| #121 did not update `plans/in-progress/…-deployment-pipeline-tasks.md:65` | `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md:65` | Nit | Stale plan DoD wording |
| #121 did not update `plans/in-progress/…-deployment-pipeline-tasks.md:236` | `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md:236` | Nit | P1.13 exit criterion says "if renamed" — rename already done; ambiguous |

**No blockers.** Nothing in P1.1b's execution path is broken. The path `scripts/deploy.sh` is free. `architecture/infrastructure.md` is correct. `scripts/composite-deploy.sh` has its deprecation comment. CI workflows (`release.yml`, `preview.yml`) were correctly left untouched.

The five stale references are all in non-executable plan docs or archived inbox messages. P1.1b can proceed. Viktor or a cleanup pass should tighten the P1.13 exit criterion wording.

---

## What P1.1b should do before starting

Nothing — the namespace is clean. `scripts/deploy.sh` path is free.

## Optional follow-up (not blocking P1.1b)

Update `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md` lines 62, 65, and 236 to reflect that the rename is already complete, not hypothetical.
