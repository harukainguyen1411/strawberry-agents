# Agent Team Mode — Runbook

**Last verified:** 2026-04-27 (Claude Code v2.1.119)
**Verified by:** Evelynn session `c5369aa0` — empirical end-to-end (in-process probe + PR #93 merge via Ekko teammate, merge commit `81094737`).

This runbook captures the working shape for spawning real Claude Code teammates (TeamCreate + Agent dispatch) in this repo, and the failure modes that cost a session of debugging to identify.

---

## TL;DR — the working dispatch shape

```
TeamCreate({ team_name: "<team>", agent_type: "team-lead", description: "..." })

Agent({
  subagent_type: "<Capitalized>",   // e.g. "Ekko", "Yuumi", "Viktor"
  team_name: "<team>",              // matches TeamCreate name
  name: "<lowercase-handle>",       // REQUIRED — without this, falls back to bg one-shot
  description: "...",
  prompt: "[concern: personal] ...",
  run_in_background: true            // REQUIRED — teammates spawn in background
})
```

**Tell-tale that you got a real teammate:** the spawn response shows `agent_id: <name>@<team>` (e.g. `ekko@pr93-ship`). If it returns a hex ID, you got a plain background subagent, NOT a teammate.

**Verify membership:** `Read ~/.claude/teams/<team>/config.json` — your handle should appear in `members[]` with `backendType: "in-process"` (or `"tmux"` if tmux is installed and `teammateMode` is `"tmux"`).

---

## Policy (mandatory for coordinators)

From 2026-04-27 onward, coordinators (Evelynn, Sona) MUST use the Agent Team feature (`TeamCreate` + Agent dispatch with `team_name`) instead of one-shot background subagents for any work that may iterate.

- **Spawn into a team, not as a one-shot.** Each new piece of work gets a `TeamCreate` with a descriptive `team_name`; agents are dispatched into that team and stay alive between turns.
- **A task is "FULLY done" only when the entire build → review → re-review loop has converged green.** If a reviewer requests changes, the build agent's task is NOT done — another change-and-re-review turn must occur on the same teammate before shutdown. Same for QA: a FAIL verdict means the implementer's task is not done; re-dispatch them in-team for the fix.
- **On full completion, shut down explicitly.** Send `{type: "shutdown_request"}` via `SendMessage` to each teammate, then `TeamDelete` to remove the team. Do not leave idle teammates lingering across unrelated work.
- **Never declare "done" on partial loop state.** "Code shipped, awaiting review" is not done. "Reviewer LGTM but Akali pending" is not done. "Akali FAIL, fix dispatched" is not done. Done = green-on-all-gates AND merged AND no follow-on rework outstanding.
- **Fallback exception list.** Ad-hoc one-shot Agent dispatches remain acceptable only for read-only excavation (Skarner), errands (Yuumi), single-pass status probes, and Lissandra/Orianna script-style invocations — work that genuinely cannot iterate.
- **Fallback requires a justification trail.** Every fall back to bg one-shot dispatch (outside the exception list above) requires a decision-log entry — invoke the `decision-capture` skill (`.claude/skills/decision-capture/SKILL.md`) or follow the entry shape in `architecture/coordinator-decision-feedback.md`. The entry lives at `agents/<coordinator>/memory/decisions/log/<date>-<slug>.md` and must document (i) which team-mode failure mode fired, (ii) what the fallback dispatch was, (iii) whether a follow-up plan or learning is needed.
- **Escape hatch when team mode itself is broken.** If `TeamCreate` errors or teammate spawn returns a hex agentId / missing `members[]` / no `<teammate-message>` reply, fall back to bg one-shot AND log a decision-log entry titled `team-mode-unavailable-<reason>`. No special flag or sentinel file needed.

---

## Settings — what controls backend selection

`~/.claude/settings.json`:

| Key | Value | Effect |
|---|---|---|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` | Required env to enable the team feature at all. |
| `teammateMode` | `"auto"` | Auto-detect: tmux split-pane if parent CLI is inside a tmux session AND tmux is installed; otherwise in-process. **Recommended.** |
| `teammateMode` | `"tmux"` | Force tmux backend. Fails (`"Failed to create swarm session: Unknown error"`) if tmux is uninstalled. |
| `teammateMode` | `"it2"` | **Aspirational only** — documented at `code.claude.com/docs/en/agent-teams` but not shipped in v2.1.119. Do not use. |

**Current repo state (2026-04-27, post-reinstall):** tmux 3.6a is installed at `/opt/homebrew/bin/tmux`, `teammateMode: "auto"`. Teammates still route in-process because the parent CLI is not launched from inside a tmux session — `auto` only selects tmux when the parent is already inside one. To exercise the tmux backend, launch `claude` from inside `tmux new -s claude`.

---

## In-process vs tmux backend

**In-process** (current default):
- `backendType: "in-process"`, `tmuxPaneId: "in-process"` (sentinel)
- Teammate runs as a co-process under the lead's CLI
- View teammate output: **Shift+Down** in the lead's terminal cycles through teammates
- No external multiplexer dependency, no socket fragility
- ✅ Validated end-to-end on 2026-04-27 (Yuumi probe + Ekko PR #93 merge)

**Tmux** (if `teammateMode: "tmux"` and tmux is installed):
- `backendType: "tmux"`, `tmuxPaneId: "%N"` (real pane id like `%0`, `%1`)
- Each teammate gets its own tmux pane on a custom socket: `tmux -L claude-swarm-<pid>`
- ⚠️ **Not visible via plain `tmux ls`** — uses non-default socket. To inspect: `tmux -L claude-swarm-<pid> ls`
- ⚠️ **Fragile**: tmux server can vanish silently → all teammates die → `isActive` flag stays stale → `TeamDelete` refuses until config.json is hand-patched

**Recommendation:** prefer in-process unless we have a concrete reason to switch back.

---

## Failure modes (and their tells)

### Failure 1: Missing `name` field → not a real teammate

**Symptom:** spawn returns hex agentId like `c4a3f...`, agent does NOT appear in `members[]` of `~/.claude/teams/<team>/config.json`. Agent runs as a plain background subagent with no team membership, no SendMessage routing, no shared TaskList participation.

**Cause:** Agent dispatch omitted the `name` parameter.

**Fix:** Always include `name: "<lowercase-handle>"`. The field is treated as optional by the Agent tool schema but is REQUIRED for teammate semantics.

**Cost when missed:** Session `c5369aa0` (2026-04-27) lost ~2hrs to repeatedly dispatching Viktor/Ekko without `name`, none of which became teammates.

### Failure 2: Foreground dispatch (`run_in_background: false`)

**Symptom:** PreToolUse hook (`#rule-background-subagents`) blocks the dispatch with `sys.exit(2)`. Even if the hook were bypassed, foreground would be wrong shape — teammates spawn in background.

**Fix:** Always set `run_in_background: true`. This is the universal teammate dispatch shape — there is no foreground teammate path.

### Failure 3: tmux substrate failure (only relevant if `teammateMode: "tmux"`)

**Symptoms (any of):**
- Teammate dies silently mid-task; no SendMessage reply
- `TeamDelete` refuses with "team still has active members"
- `tmux ls` shows nothing (looking at wrong socket — see in-process vs tmux above)
- New `TeamCreate` returns `"Failed to create swarm session: Unknown error"`

**Fix (escape hatch):**
1. Hand-patch `~/.claude/teams/<team>/config.json` — set every member's `isActive: false`
2. `TeamDelete` will now succeed
3. Either reinstall tmux (`brew install tmux`) or flip `teammateMode` to `"auto"` and re-test

**Better fix:** stay on in-process backend (current default).

### Failure 4: Lead can only manage one team at a time

**Symptom:** `TeamCreate` returns `Already leading team "<other>". A leader can only manage one team at a time.`

**Fix:** `TeamDelete` first, then create the new team. The lead session is bound to one team at a time.

---

## Communication primitives

| Tool | Purpose |
|---|---|
| `SendMessage({to: "<name>", message: "..."})` | Send to teammate by name (NEVER by agentId/UUID) |
| `SendMessage({to: "<name>", message: {type: "shutdown_request", reason: "..."}})` | Graceful teammate termination |
| `TaskCreate / TaskUpdate / TaskList` | Shared task list at `~/.claude/tasks/<team>/` — every teammate can read/claim/complete tasks |

**Inbound messages from teammates** are delivered automatically as `<teammate-message>` blocks in the lead's conversation. Do NOT poll an inbox; do NOT scrape the team config file looking for messages.

**Idle notifications** are normal — every teammate goes idle after each turn. Idle ≠ done; just send another message to wake them up.

---

## End-to-end recipe (the path verified on 2026-04-27)

1. Confirm settings:
   ```bash
   cat ~/.claude/settings.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('teams:', d['env'].get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS')); print('mode:', d.get('teammateMode'))"
   ```
   Expect `teams: 1`, `mode: auto`.

2. `TeamCreate({team_name: "my-team", agent_type: "team-lead", description: "..."})`

3. Spawn teammate(s) via `Agent` with `team_name` + `name` + `run_in_background: true` (see TL;DR above).

4. Verify membership: `Read ~/.claude/teams/my-team/config.json` — confirm `members[]` contains your teammate with `backendType: "in-process"`.

5. Coordinate via `SendMessage` (and `TaskUpdate` if using shared tasks).

6. Teardown when done: `SendMessage({to: "<name>", message: {type: "shutdown_request"}})` for each teammate, then `TeamDelete()`.

---

## Operational hygiene

- **Shut down idle teammates promptly when their work is done.** Do not let teammates linger across unrelated work — they consume context window and quietly accumulate stale state. Per the loop-convergence rule in `## Policy` above, "done" means green-on-all-gates AND merged AND no follow-on rework outstanding; once true, send `{type: "shutdown_request"}` to each teammate then `TeamDelete`.
- **One team per coordinator session.** A lead can only manage one team at a time (per `## Failure modes` Failure 4). Tear down the previous team fully before `TeamCreate` for a new piece of work.
- **Don't reuse teammates across unrelated work.** A teammate's context is shaped by its initial dispatch prompt. When the work topic shifts, shut them down and dispatch a fresh teammate rather than retasking — the fresh teammate gets a clean prompt aligned to the new work.

## Cross-references

- Repo rule `#rule-background-subagents` (CLAUDE.md) — universal background-only dispatch invariant. Teammates already comply by spawning in background.
- `architecture/agent-network-v1/communication.md` — broader inter-agent messaging (inbox, etc.) for non-team flows.
- Sona inbox FYIs (archived `agents/evelynn/inbox/archive/2026-04/`):
  - `20260427-0234-43-team-feature-tmux-fragility.md` — tmux fragility runbook origin
  - `20260427-0306-37-team-dispatch-shape-reply.md` — definitive teammate dispatch shape
- Session shard `agents/evelynn/memory/last-sessions/c5369aa0.md` — the investigation arc that produced this runbook.

---

## Open questions / known gaps

- **In-process scaling under load.** Verified with 1 teammate (Yuumi probe) and 1 teammate doing real work (Ekko merging PR #93). Not yet stressed with multiple concurrent heavy teammates (Senna+Viktor+Vi parallel). If we hit issues, options are: reinstall tmux + accept fragility, or file Anthropic issue for real iTerm2 backend.
- **Plan-author teammates with `default_isolation: worktree`.** Karma plan vanished on 2026-04-27 because the planner's worktree was reaped before merge-back. Unrelated to team mode per se, but worth a separate runbook on opus-planner artifact safety.
- **Lead session restart.** Behavior of teammates when lead `/compact`s or restarts is not yet characterized. Treat teammates as ephemeral; do not assume cross-session persistence.
