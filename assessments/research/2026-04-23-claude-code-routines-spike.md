# Research spike — Claude Code Routines availability and behavior

**Date:** 2026-04-23
**Author:** Ekko (research only, read-only against codebase)
**Concern:** personal
**Session:** Ekko subagent — research only, no codebase writes
**Spike budget:** 30 min
**Dependent plans:** `plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md`, `plans/proposed/personal/2026-04-21-agent-feedback-system.md`

---

## TL;DR

Claude Code Routines **exists and is real**. It launched into **research preview on 2026-04-14** and is available today on all paid Claude plans (Pro, Max, Team, Enterprise) with Claude Code on the web enabled. The core mechanic the two dependent plans rely on — cloud-hosted, scheduled, autonomous sessions against a GitHub repo — is confirmed and functional. However, research preview status means the API surface may change, and several capability gaps discovered during this spike are material to the plans' design.

---

## Q1 — Does Routines currently exist?

**Yes.** Routines shipped into research preview on 2026-04-14. Source: official Claude Code documentation at `code.claude.com/docs/en/routines` and the Anthropic Threads announcement. As of 2026-04-23 it is **research preview, not GA**. Anthropic's stated roadmap is to expand webhook support and graduate to GA, but no timeline is given. The research preview is:

- Available to all paid plans (Pro, Max, Team, Enterprise) with Claude Code on the web enabled
- Subject to behavior, limits, and API surface changes without notice
- Functional enough for production-equivalent use by early adopters

The plan's assumption (§1) that "Claude Code shipped Routines" is correct. The plan cites a "2026 Claude Code blog post introducing the feature" — this matches reality (April 14, 2026 announcement).

---

## Q2 — What is the invocation mechanism?

Three trigger types, combinable on a single routine:

1. **Schedule** — recurring cron cadence. Created via the web UI at `claude.ai/code/routines` or via `/schedule` in the CLI. Preset frequencies: hourly, daily, weekdays, weekly. Custom cron expressions via `/schedule update` in the CLI after creation. **Minimum interval: 1 hour.** Times are entered in local timezone and converted automatically.

2. **API** — dedicated HTTP POST endpoint per routine. Bearer token auth. Optional `text` field for run-specific context (freeform string). Returns session ID + URL. Available from web UI only (CLI cannot create/revoke tokens). Ships under experimental beta header `experimental-cc-routine-2026-04-01`.

3. **GitHub event** — webhook on PR or release events. Requires Claude GitHub App installed on the target repo. Web UI only.

The plans assume `/schedule` as the primary setup mechanism — this is correct; `/schedule` in the CLI walks through creation conversationally and covers scheduled triggers.

**Material gap for the audit-routine plan:** The minimum schedule interval is **1 hour**. A daily schedule (07:00 Asia/Bangkok) is fine. The plan's §D9 mentions "retries within the same Routine at 08:00 and 09:00" — this is achievable by adding separate schedule triggers to the same routine (multiple triggers are supported on one routine).

---

## Q3 — What capabilities does a scheduled session have?

Each run is a **full Claude Code cloud session** running on an Anthropic-managed VM. Confirmed capabilities:

| Capability | Available | Notes |
|---|---|---|
| `CLAUDE.md` from repo | Yes | Read from fresh clone |
| `.claude/settings.json` hooks | Yes | Read from fresh clone (including pre-commit hooks, etc.) |
| `.claude/agents/*.md` | Yes | Available — subagents via Agent tool work |
| `.claude/skills/` | Yes | Available |
| `Bash` tool | Yes | Full shell access, read-only or write |
| `Read`, `Edit`, `Write`, `Glob`, `Grep` | Yes | Standard Claude Code tools |
| `Agent` tool (dispatching subagents) | Yes | Confirmed — subagents work the same as local |
| `WebFetch`, `WebSearch` | Yes (with network access level "Trusted" or "Full") | Trusted allows GitHub, package registries, cloud APIs, Anthropic docs |
| `git` CLI | Yes | Pre-installed |
| `gh` CLI | **No (not pre-installed)** — must be installed via setup script + GH_TOKEN env var | Important gap for plans that use `gh` commands |
| MCP connectors | Yes — configured per routine, all connected connectors included by default | Managed via `claude.ai/settings/connectors` |
| Local files on Duong's machine | **No** | Fresh clone of repo; no access to local filesystem, local secrets, local .env files |
| User-level `~/.claude/CLAUDE.md` | **No** | Not available — only repo-level CLAUDE.md |
| Static secrets / credentials | **No dedicated store** — must go in environment variables (visible to anyone who can edit that environment) | No gitignored `secrets/` directory exists in the cloud VM |
| `tools/decrypt.sh` + age keys | **Functionally blocked** — `secrets/age-key.txt` is gitignored and will not be in the clone | Age-encrypted secrets are not usable in cloud sessions |
| Interactive auth (AWS SSO, etc.) | No | Not supported |

The routine runs **autonomously** — no permission-mode picker, no approval prompts.

**Pre-commit hooks run in cloud sessions** because `.claude/settings.json` and `scripts/hooks/` are part of the repo clone. This is a significant implication: if the audit routine commits a findings tracker update, the full pre-commit hook suite runs (unit tests, secret scanning, commit-prefix check, plan authoring freeze, etc.). The plan (§2.1) says commits use `chore:` prefix and only write to `assessments/audits/` and `agents/evelynn/inbox/` — both are non-`apps/**` paths, so `chore:` is correct. But the unit test hook runs for changed packages, and the secret-scanning hook runs. This needs verification during implementation.

**Branch push restriction:** By default, routines can only push to branches prefixed with `claude/`. To push directly to `main` (as the plan requires), **"Allow unrestricted branch pushes"** must be enabled for the `strawberry-agents` repo in the routine configuration. This is a configuration step not mentioned in either plan.

---

## Q4 — What is the cost model?

Routines draw down **subscription usage identically to interactive sessions** — no separate billing, no per-invocation fee beyond what normal Claude Code web usage costs. Daily run caps by plan tier:

| Plan | Daily routine run cap |
|---|---|
| Pro | 5 runs/day |
| Max | 15 runs/day |
| Team/Enterprise | 25 runs/day |

One daily audit routine = 1 run/day. Leaves 4 remaining on Pro, 14 on Max. The plan's §D1 claim ("Pro: 5/day, Max: 15/day, Team/Enterprise: 25/day") matches official documentation exactly.

When the daily cap or subscription usage limit is hit, organizations with extra usage enabled continue on metered overage; without extra usage, additional runs are rejected until the window resets.

The audit routine's estimated 25-33 min of subagent work per day is well within typical session budgets. The token cost is identical to running equivalent interactive sessions — no surprise there.

---

## Q5 — Is there a way to pass dynamic input?

**Yes, via the API trigger's `text` field.** When firing via API POST, a freeform `text` string is passed alongside the routine's saved prompt.

**For scheduled triggers: no native dynamic input.** The prompt is static. However, the session itself can read dynamic state:

- The repo is freshly cloned at run time — so anything committed to the repo is current (e.g., a findings tracker at `audits/findings-tracker.json`).
- The session can run `date`, read commit logs, call `gh api` (if installed via setup script), and use `WebFetch`/`WebSearch`.
- The `CLAUDE_CODE_REMOTE_SESSION_ID` env var is available.

The audit-routine plan's design accounts for this correctly: it reads the findings tracker from the cloned repo and diffs against it. No dynamic input injection is needed. The plan's assumption of "repo-state as dynamic input" is sound.

---

## Q6 — Failure modes

**Official documentation is sparse on failure handling.** From the docs and secondary research:

- **No automatic retry** — a failed run does not automatically re-run. There is no built-in retry policy at the Routines level.
- **No built-in alerting** — Routines do not send notifications on failure. The user must poll `claude.ai/code/routines` or build alerting into the routine's prompt via MCP connectors (e.g., Slack connector posts a failure message).
- **Visibility:** Each run creates a session visible at `claude.ai/code`. The session transcript shows what happened. There is no email/push notification.
- **Setup script failure:** If the environment setup script exits non-zero, the session fails to start. The doc explicitly notes this: "If the script exits non-zero, the session fails to start."
- **Resource limits:** 4 vCPU, 16 GB RAM, 30 GB disk. Sessions that exceed these may be terminated.
- **Rate limit / daily cap exhaustion:** Additional runs are rejected (not queued) until the window resets.
- **No catch-up for missed scheduled runs:** If a run is skipped (e.g., due to cap exhaustion), it does not run retroactively.

**Implication for the audit-routine plan:** The plan's §D9 mentions backup slots at 08:00 and 09:00 implemented as "retries within the same Routine." This is achievable by adding two additional schedule triggers to the same routine (08:00 and 09:00), but the routine itself has no awareness that 07:00 succeeded — it will run at all three times regardless. The plan's idempotency check ("already ran today" → no-op) mitigates this, but the plan needs to be explicit that idempotency detection happens via the tracker file, not via Routines-native state.

---

## Q7 — Concurrency

- Multiple routines **can run simultaneously** — each run creates its own independent session on Anthropic-managed infrastructure.
- **No locking mechanism is provided by Routines itself** — concurrent runs of the same routine (e.g., if all three schedule triggers fire in close succession or during a restart) will each operate independently.
- Both plans depend on writing to shared files in the repo (`audits/findings-tracker.json`, `agents/evelynn/inbox/`, `feedback/`). **Concurrent routine sessions will race on git push.** The audit-routine plan does not address this race. If two runs finish simultaneously and both attempt to push, the second push will fail (non-fast-forward). The plan needs an explicit conflict-resolution strategy (e.g., pull-rebase before push within the session, or accept push failure as a tolerable no-op for a given run).

---

## Critical gaps not addressed by the plans

1. **`gh` CLI not pre-installed** — the audit-routine plan's §D1 lists `Bash (read-only + git + gh for release-notes fetches)` as a tool. `gh` must be explicitly installed in the environment setup script with a `GH_TOKEN` env var. This is a configuration step that needs a dedicated task.

2. **`secrets/` directory absent in cloud** — the repo's `secrets/` dir is gitignored and will not be cloned. Any step that relies on decrypted secrets (e.g., tools that need PATs) cannot run in a cloud routine without storing credentials in environment variables (which carry different security semantics).

3. **Branch push restriction** — "Allow unrestricted branch pushes" must be explicitly enabled for `strawberry-agents` in the routine config to push to `main`. Without this, the commit+push step the audit routine relies on will fail.

4. **Pre-commit hooks run in cloud** — the full hook suite runs on every routine commit. The audit routine's commits to `assessments/audits/` and `agents/evelynn/inbox/` must be vetted against all active hooks (secret scan, commit-prefix, plan authoring freeze). Low risk but must be confirmed in Phase 1 implementation.

5. **User `~/.claude/CLAUDE.md` not available** — Duong's global Claude preferences file does not transfer to cloud sessions. Only the repo-level `CLAUDE.md` is available. This is fine for the audit use case (repo-level CLAUDE.md is the source of truth) but worth noting.

6. **No concurrency guard** — multiple schedule triggers on the same routine can produce concurrent runs. Needs a pull-before-push or idempotency guard in the session prompt.

---

## Recommendation

### GO / PIVOT / NO-GO

**GO with modifications** for `2026-04-21-daily-agent-repo-audit-routine.md`.

The core substrate assumption is correct: Routines exists, is available on Duong's plan tier, runs full Claude Code sessions with `Agent` tool support, reads from the repo clone, can commit and push. The feature is research preview but stable enough for a personal-use tool.

Required modifications before Orianna approval:

1. **Add task:** configure environment setup script with `gh` CLI install + `GH_TOKEN` env var.
2. **Add task:** enable "Allow unrestricted branch pushes" for `strawberry-agents` in routine config.
3. **Clarify §D9:** the 08:00/09:00 backup slots are additional schedule triggers, not Routines-native retries. Add explicit note that idempotency detection is via `audits/findings-tracker.json` date-key, not Routines state.
4. **Add §D10 (or amend §D9):** add pull-before-push step in the session prompt to guard against concurrent-run push conflicts.
5. **Note in §D1:** confirm pre-commit hook compatibility with audit output commits during Phase 1.

**DEFERRED (requires separate decision)** for `2026-04-21-agent-feedback-system.md`.

The feedback plan's Routines dependency is indirect — it piggybacks on the audit routine's infrastructure for its weekly consolidation (§D7). The feedback plan cannot be promoted until the audit-routine plan is at in-progress or later. The Routines substrate is sound; the feedback plan's own gaps (schema, `/agent-feedback` skill, `sync-shared-rules.sh` integration) are independent of Routines availability and should be assessed separately once the audit-routine plan is unblocked.

### Suggested next step

Promote `2026-04-21-daily-agent-repo-audit-routine.md` through the Orianna gate with the five modifications above incorporated into the plan body. The feedback plan remains DEFERRED pending audit-routine progress.

---

## Sources consulted

- [Run prompts on a schedule — Claude Code Docs](https://code.claude.com/docs/en/scheduled-tasks)
- [Automate work with routines — Claude Code Docs](https://code.claude.com/docs/en/routines)
- [Use Claude Code on the web — Claude Code Docs](https://code.claude.com/docs/en/claude-code-on-the-web)
- [Claude Code Adds Cloud Routines for Scheduled AI Tasks — Winbuzzer](https://winbuzzer.com/2026/04/16/anthropic-claude-code-routines-scheduled-ai-automation-xcxwbn/)
- [Anthropic adds routines to redesigned Claude Code — 9to5Mac](https://9to5mac.com/2026/04/14/anthropic-adds-repeatable-routines-feature-to-claude-code-heres-how-it-works/)
- [Automate work with routines — Claude Code Docs (secondary)](https://code.claude.com/docs/en/routines)
