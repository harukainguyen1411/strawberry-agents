---
title: Windows Autonomous Isolation — Mac/Windows Split Enforcement
status: implemented
owner: pyke
created: 2026-04-09
---

# Windows Autonomous Isolation

## Context

Duong runs Strawberry on two machines:

- **Mac (interactive):** Evelynn sessions, planning, coordination, full agent roster. Session closing protocol commits transcripts, memory, journal, and learnings to main.
- **Windows (autonomous):** Coder-worker polls labeled GitHub issues, executes implementation, opens PRs on `bot/issue-{number}` branches. Runs unattended. Must NOT commit session logs, transcripts, journal entries, or memory updates to main — doing so would conflict with Mac sessions writing to the same shared agent state.

## 1. What the coder-worker inherits from Strawberry protocol

The following conventions carry over unchanged:

- **Commit prefix:** `chore:` / `ops:` — enforced by the pre-push hook on main. (Note: `worker.ts` line 43 currently uses `fix:` prefix — this is a bug; see Section 5.)
- **Agent roster awareness:** The system prompt can reference agent names and roles for context, but the worker never invokes other agents.
- **CLAUDE.md rules:** The repo-root CLAUDE.md is loaded by Claude Code automatically. The coder-worker's `system-prompt.md` layered on top provides the hard scope constraints.
- **Same agent definitions in `.claude/agents/`:** These exist on disk but are irrelevant to the headless `claude -p` invocation — it uses the system prompt, not agent definitions. No action needed.
- **No-secrets-in-code rule:** Already enforced in system prompt rule 6 and gitleaks pre-commit hook.
- **Allowed tools whitelist:** Already restricted to `Edit,Write,Read,Glob,Grep,LS` — no Bash, no git, no network.

## 2. What gets suppressed and how to enforce it

### Already suppressed (no changes needed)

| Artifact | Why it is already safe |
|---|---|
| Session transcripts | `claude -p` is headless; no interactive session exists; no transcript JSONL is generated |
| `/end-session` closing protocol | Not invokable — `claude -p` has no slash commands; the skill is not in `allowedTools` |
| Agent memory writes (`agents/*/memory/`) | System prompt forbids writes to `agents/`; `allowedTools` has no Bash; Claude cannot run git |
| Journal entries | Same as memory — `agents/*/journal/` is off-limits per system prompt |
| Learnings commits | Same enforcement path |

### Gaps to close

| Gap | Risk | Fix |
|---|---|---|
| **G1: `git add .` in `commitAndPush`** | If Claude somehow writes a file outside `apps/myapps/` (e.g., a `.claude/` settings file or agent state), `git add .` would stage it. | Change `git add .` to `git add apps/myapps/` in `git.ts:commitAndPush`. This is the single most important hardening change. |
| **G2: `git checkout` instead of worktree** | `createBranch` uses `git checkout -B` which mutates the shared working tree. If Mac happens to be mid-operation on the same clone, this corrupts state. | In practice the Windows box has its own clone, so this is safe. But document the invariant: **Mac and Windows must never share the same git clone directory.** |
| **G3: No `.claude/` settings isolation** | Claude Code may write to `.claude/settings.json` or similar files in the repo root during a `-p` invocation. These could be staged by `git add .`. | Fix G1 (scoped `git add`) eliminates this. Additionally, add `.claude/` to a `.gitignore` entry if not already present, or rely on the scoped add. |
| **G4: Commit message uses `fix:` prefix** | `worker.ts` line 43 uses `fix:` which violates the `chore:`/`ops:` convention and would be rejected by the pre-push hook on main (though the worker pushes to `bot/` branches, not main, so the hook may not fire). | Change to `chore:` for consistency. |

## 3. Git surface isolation

### Branch discipline

The coder-worker creates branches named `bot/issue-{number}` and pushes only to those branches. It never pushes to main. This is enforced by:

1. **Code-level:** `commitAndPush` pushes to the named branch, never `main`.
2. **Branch protection:** Main requires PR review — even if the bot tried to push directly, GitHub would reject it (assuming `harukainguyen1411` is not a bypass actor).
3. **Label lifecycle:** The `ready` -> `bot-in-progress` -> `bot-pr-opened` label flow means the worker only touches issues explicitly labeled for it.

### Audit log isolation

Audit logs write to `~/coder-worker/var/logs/` (outside the repo tree). This is correct and already isolated.

### Current gaps in `apps/coder-worker/`

| File | Issue |
|---|---|
| `git.ts:commitAndPush` | `git add .` stages the entire repo root — must scope to `apps/myapps/` (G1) |
| `git.ts:createBranch` | Uses `git checkout -B` (acceptable since Windows has its own clone, but document the invariant) |
| `git.ts:checkoutMain` | Returns to main after each job — correct cleanup behavior |
| `claude.ts` | CWD is set to `apps/myapps` — correct scope for Claude's file operations |
| `system-prompt.md` | Hard-limits scope to `apps/myapps/` — correct |
| `config.ts` | `systemPromptPath` default points to `.github/coder-agent/system.md` which does not match the actual location at `apps/coder-worker/system-prompt.md` — stale default, but overridden by env var in practice |

### Can the worker write to main or agent state?

- **Direct push to main:** No. It pushes to `bot/issue-{number}` only.
- **Agent state files:** Claude cannot write outside `apps/myapps/` (system prompt + no Bash). Even if it did, the scoped `git add` fix (G1) would prevent staging.
- **Merge to main:** The worker calls `createPr` but never merges. Merge requires human or gatekeeper review.

## 4. Conflict scenarios

### Scenario A: Mac and Windows both push to main simultaneously

**Cannot happen under current architecture.** The Windows worker never pushes to main. It pushes to `bot/issue-{number}` branches only. Mac sessions commit agent state to main. These are entirely separate git refs.

### Scenario B: Mac merges a bot PR while another bot job is running

**Low risk.** The bot fetches `origin/main` and creates a fresh branch at job start. If main moves during execution, the PR may have merge conflicts, but that is handled at review time. No data loss.

### Scenario C: Two coder-worker instances run simultaneously

**Prevented by runlock.** The `runlock.ts` module acquires a file lock at `~/.claude-runlock/claude.lock` before invoking Claude. Only one Claude invocation runs at a time.

### Scenario D: Mac and Windows share the same git clone

**Catastrophic.** `git checkout -B` on Windows would destroy Mac's working tree. **This must never happen.** Each machine must have its own clone. Document this as a hard invariant.

### Scenario E: Bot PR merged, then Mac session commits agent state

**No conflict.** Bot PRs touch `apps/myapps/` only. Agent state is under `agents/`. Different file paths, no merge conflict possible.

## 5. Recommended changes (minimal set)

### Must-do (4 changes)

| ID | Change | File | Effort |
|---|---|---|---|
| **M1** | Scope `git add .` to `git add apps/myapps/` | `apps/coder-worker/src/git.ts` | 1 line |
| **M2** | Change commit prefix from `fix:` to `chore:` | `apps/coder-worker/src/worker.ts` line 43 | 1 line |
| **M3** | Fix stale `systemPromptPath` default to point to `apps/coder-worker/system-prompt.md` | `apps/coder-worker/src/config.ts` | 1 line |
| **M4** | Add `architecture/platform-split.md` documenting the Mac/Windows invariants: separate clones, Windows never writes agent state, Windows never pushes to main | New file | ~30 lines |

### Should-do (2 changes)

| ID | Change | Rationale |
|---|---|---|
| **S1** | Add a pre-push hook on the Windows clone that rejects pushes to `main` from the bot account | Defense in depth — code already prevents this, but a hook catches regressions |
| **S2** | Add `agents/` and `plans/` to the system prompt's NEVER-modify list (they are already blocked by the scope rule, but explicit listing is clearer) | `agents/` is listed but `plans/` could be more prominent |

### Not needed

- No changes to `/end-session` or `/end-subagent-session` — these are interactive-only skills, unreachable from `claude -p`.
- No changes to CLAUDE.md — the coder-worker uses `system-prompt.md`, not CLAUDE.md, as its primary instruction set. (CLAUDE.md is loaded by Claude Code but the system prompt's hard scope overrides it.)
- No NSSM or service configuration changes — the isolation is at the git and prompt level, not the service level.
- No branch protection changes — already requires PR review on main.
