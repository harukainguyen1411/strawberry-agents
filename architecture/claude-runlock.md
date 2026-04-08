# Claude Runlock Contract

> Cross-plan contract for serial `claude` CLI invocation on Duong's always-on Windows computer. Owned by the Bee plan (`plans/proposed/2026-04-09-sister-research-agent-karma.md`) as of 2026-04-08. Previously scaffolded by the Discord CLI integration plan; ownership transferred when the Discord bot migrated to Gemini and stopped invoking `claude`.

## Purpose

Duong's Max subscription runs a single interactive Claude Code CLI session per machine under his OAuth credentials. Multiple long-lived processes on the same Windows computer may want to invoke `claude -p` for background work. Concurrent invocations risk:

1. **Quota self-DoS** — parallel runs burn the Max rate limit and 429 each other.
2. **OAuth credential contention** — `%USERPROFILE%\.claude\` state is not designed for concurrent writers.
3. **Compliance posture** — Layer B of the Max ToS argument (§5.6 of the Bee plan) relies on "interactive single-job invocations triggered one at a time." Parallel background runs weaken that story.

The runlock enforces strict serial execution across all participating processes on the machine.

## Canonical path

- **Windows native:** `%USERPROFILE%\.claude-runlock\claude.lock`
- **Git Bash view:** `/c/Users/<duong>/.claude-runlock/claude.lock`

The directory `%USERPROFILE%\.claude-runlock\` must exist before any participant runs. It is created by `scripts/windows/init-claude-runlock.ps1` (to be scaffolded alongside the first participant's install). NTFS ACL: Full Control for Duong's user account only.

## Contract

Any process that wants to invoke `claude` (any subcommand, `-p` or interactive) on this Windows computer **must**:

1. **Acquire the lock** before spawning the `claude` subprocess.
2. **Hold the lock** for the entire duration of the subprocess.
3. **Release the lock** after the subprocess exits (success or failure).
4. **Respect stale-lock recovery policy** when the lock file exists but the holder is dead (see below).

Participants MUST NOT:

- Fork concurrent `claude` subprocesses while holding the lock.
- Hold the lock across unrelated work (acquire just-in-time, release promptly).
- Delete the lock file directly without going through the acquisition library's release path, except under stale-lock recovery.

## Acquisition libraries

Two implementations target the same NTFS file:

- **Node processes:** [`proper-lockfile`](https://www.npmjs.com/package/proper-lockfile). Battle-tested, supports stale detection, lockfile-compat mode available for cross-platform targets.
- **POSIX shell helpers (Git Bash / MSYS):** `flock(1)` from the MSYS core-utils package. Operates on the same underlying NTFS file via the MSYS layer.

Both libraries use advisory locking semantics — a non-participating rogue `claude` invocation would bypass the lock. Participation is enforced by convention across all processes in the runlock doc's participant list.

## Timeout policy

- **Acquisition timeout:** 30 minutes. A process waiting on the lock longer than 30 minutes should abort and surface a user-visible error. This is longer than any single `claude` run's hard kill timer (Bee: 25 minutes; pipeline: TBD) so the lock should always clear within the window under normal operation.
- **Hold timeout:** participants SHOULD kill their own `claude` subprocess after a configurable hard timer (Bee uses 25 minutes) and release the lock immediately. Holding the lock beyond 30 minutes is a bug.
- **Retry cadence:** polling every 500ms–2s with light jitter is appropriate. `proper-lockfile` handles this internally.

## Stale-lock recovery

A lock is considered stale if:

1. The lock file exists AND
2. The recorded holder PID is not alive on the machine OR the lock's mtime is older than the hold timeout (30 minutes) by a safety margin of 5 minutes (so 35 minutes total).

Recovery procedure (both libraries handle the first-party cases automatically; this is the manual fallback):

1. Verify the holder PID is not alive (`tasklist /FI "PID eq <pid>"` returns no match).
2. Verify no `claude.exe` / `node.exe` running `claude` is active on the machine for that user.
3. Delete the lock file.
4. Re-attempt acquisition.

Participants SHOULD log every stale-lock recovery event to their own operational log. Frequent recoveries (more than once per day) indicate a participant is crashing mid-run and should be investigated.

## Current participants

As of 2026-04-08:

- **Bee worker** — Windows queue worker for the sister's research agent. NSSM-supervised Node process. Acquires via `proper-lockfile`. See `plans/proposed/2026-04-09-sister-research-agent-karma.md` §5.5 and §5.7.
- **Autonomous delivery pipeline worker** — Windows-side execution half of the agent delivery pipeline. Supervision and lock library TBD in its next revision. See `plans/proposed/2026-04-08-autonomous-delivery-pipeline.md`.

**Not a participant:**

- **Discord bot.** The Discord CLI integration plan (`plans/proposed/2026-04-03-discord-cli-integration.md`) originally scaffolded this doc, but the Discord bot has since been rewritten to use Gemini and never invokes `claude`. It is no longer a participant and is not bound by this contract.

New participants must be added to this list as part of the plan that introduces them.

## Open questions

- **Priority fairness.** Currently first-come-first-served via the acquisition libraries. If Bee's interactive user-visible jobs starve behind a long pipeline run, consider adding a priority hint (e.g. a sidecar `claude.lock.priority` file or a separate high-priority lock that participants check first). Not gating.
- **Observability.** A shared "who holds the lock right now" view would be useful. `proper-lockfile` writes holder metadata; exposing it via a tiny `claude-lock-status` helper script is cheap. Deferred until a second participant lands.
