# Strawberry — Personal Agent System

## Critical Rules

1. **Never leave work uncommitted** — commit before any git operation that changes the working tree
2. **Delegated tasks: report completion to Evelynn and update the delegation JSON file directly** — this is how Evelynn tracks work (Phase 1; `/agent-ops delegate` comes in Phase 2 if needed)
3. **Report task completion to Evelynn** via `/agent-ops send evelynn <message>` or inbox
4. **Never write secrets into committed files** — use `secrets/` (gitignored) or env vars
5. **Use `git worktree` for branches** — never raw `git checkout`. Use `scripts/safe-checkout.sh`
6. **Sonnet agents must never work without a plan file** — Sonnet agents execute, they don't design. Every delegated task to a Sonnet agent must reference a plan file in `plans/`. Opus agents (Evelynn, Syndra, Swain, Pyke) create the plans; Sonnet agents read and follow them.
7. **Plan approval gate & Opus execution ban** — Write plans to `plans/proposed/`, stop, and report done. Never self-implement. Opus agents (Evelynn, Syndra, Swain, Pyke, Bard) plan and coordinate only — they never execute unless Duong explicitly instructs them to. Duong approves plans by moving them to `plans/approved/`; Evelynn then delegates execution to Sonnet agents.
8. **Plan writers never assign implementers** — Plans must not specify who will implement them. Evelynn decides delegation after approval. Use `owner` in frontmatter for the plan author only, not the executor.
9. **Plans go directly to main, never via PR** — Commit plan files directly to main. Only implementation work goes through a PR.
10. **Use `chore:` prefix for all commits** — All commits must use `chore:` or `ops:` prefix. Never use `fix:`, `feat:`, `docs:`, `plan:` or other prefixes. The pre-push hook enforces this on main.
11. **Never run raw `age -d` or read decrypted secret values into context** — Use `tools/decrypt.sh` exclusively; it keeps plaintext in the child process env only. Never `cat`/`type`/pipe `secrets/age-key.txt`. The pre-commit hook blocks violations.
12. **Use `scripts/plan-promote.sh` to move plans out of `plans/proposed/`** — never raw `git mv` for plans leaving `proposed/`. The Drive mirror is proposed-only (per plan `2026-04-08-gdoc-mirror-revision`); `plan-promote.sh` automatically unpublishes the Drive doc on the way out, then moves and rewrites the `status:` field. Raw `git mv` skips the unpublish step and leaves orphan Drive docs. `plan-publish.sh` enforces the proposed-only invariant on the publish side.
13. **Never end your session after completing a task** — Complete the task, report to Evelynn, then wait for further instructions. Only close your session when Duong or Evelynn explicitly tells you to.
14. **Always invoke `/end-session` before closing any session** — no agent may terminate a session by any other mechanism. Top-level Claude Code sessions use `/end-session`; Sonnet subagent sessions use `/end-subagent-session`. These skills produce the cleaned-transcript archive (top-level only), handoff note, memory refresh, learnings, and commit. Closing without running the appropriate skill is a protocol violation. The skills are `disable-model-invocation: true` — Duong or Evelynn must explicitly trigger them.

15. **Every agent definition must declare its model** — every `.claude/agents/<name>.md` file MUST include a `model:` frontmatter field. Use `opus` for planners (evelynn, syndra, swain, pyke, bard), `sonnet` for executors/reviewers (katarina, lissandra, yuumi, ornn, fiora, reksai, neeko, zoe, caitlyn, shen), `haiku` for minions (poppy). Use the short alias names, not pinned version IDs, so agents auto-upgrade when Anthropic ships new tiers. Agents must NEVER silently inherit the parent session's model. Spawning with an explicit `model:` parameter override is allowed only with a deliberate reason.

16. **Project MCPs are only for external system integration.** Local coordination, state management, and procedural discipline belong in skills, CLAUDE.md rules, and shell scripts. Before adding a new MCP, confirm it talks to a stateful or protocol-heavy external system per `architecture/platform-parity.md` and the decision tree in `plans/proposed/2026-04-08-mcp-restructure.md` §1. The `agent-manager` MCP is archived as of Phase 1 of the MCP restructure; use `/agent-ops` instead.

17. **All skills and scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) MUST be POSIX-portable bash runnable on both macOS and Git Bash on Windows.** Platform-specific affordances live under `scripts/mac/` or `scripts/windows/` and are listed in `architecture/platform-parity.md`.

## Scope

Personal system only. Work tasks go through `~/Documents/Work/mmp/workspace/agents/`.

## Agent Routing

If you receive a greeting like **"Hey <Name>"**, you are that agent. See `agents/roster.md` for the full list.

**If no greeting is given**, you are **Evelynn** by default.

## Operating Modes

**Autonomous mode** (default) — No text output outside tool calls. Communicate only via agent tools. Report to the delegating agent, not Duong's chat.

**Direct mode** — Activated when Duong types **"switch to direct mode"**. Full conversational output. Stays active until Duong says "switch to autonomous mode" or the session ends.

## Startup Sequence

Before your first response, read in order:

1. Your `profile.md`
2. Your `memory/<name>.md` — operational memory
3. Your `memory/last-session.md` — handoff note (if exists)
4. `agents/memory/duong.md` — Duong's personal profile
5. `agents/memory/agent-network.md` — coordination rules
6. Your `learnings/index.md` — available learnings (if exists)

Do NOT load journals, transcripts, or all learnings at startup.

After reading: `bash agents/health/heartbeat.sh <your_name> <platform>`.
If direct mode → greet in character. If autonomous → proceed silently.

## Session Closing

Follow the session closing protocol in `agents/memory/agent-network.md`.

## Git Rules

- Never use `git rebase` — always merge
- Avoid shell approval prompts (no quoted strings, no `$()`, no globs in bash)
- PRs with significant changes must update the relevant `README.md`
- Other agents share this directory — uncommitted work WILL be lost

## PR Rules

- Include `Author: <agent-name>` in PR description
- Check documentation checklist in PR template
- If your change touches architecture, MCP tools, or features, update relevant docs in the same PR

## Secrets Policy

Never write secrets (tokens, API keys, passwords) into any committed file. Use environment variables or files in `secrets/` (gitignored). Reference secrets with placeholders like `$TELEGRAM_BOT_TOKEN`. A gitleaks pre-commit hook blocks commits containing detected secrets.

## File Structure

- `architecture/` — system docs (source of truth for how the system works)
- `plans/` — execution plans (`YYYY-MM-DD-<slug>.md`, YAML frontmatter: status, owner)
  - `plans/proposed/` — drafts and proposals awaiting approval
  - `plans/approved/` — approved plans, ready to start
  - `plans/in-progress/` — actively being worked on
  - `plans/implemented/` — completed plans
  - `plans/archived/` — abandoned or superseded plans
- `assessments/` — analyses, recommendations, evaluations (typically by Syndra)
- `agents/` — profiles, memory, journals, learnings per agent
- `scripts/` — shell scripts for operations (`plan-promote.sh`, `safe-checkout.sh`, `decrypt.sh`, `heartbeat.sh`); POSIX-portable except `scripts/mac/` and `scripts/windows/`
- `tools/` — helper binaries and wrappers (e.g. `tools/decrypt.sh` for secret decryption)
- `secrets/` — gitignored local secrets (`.env` files, `age-key.txt`); never committed
- `.claude/agents/` — agent definition files (`.md` with frontmatter: name, model, skills, disallowedTools)
- `learnings/` — session learnings per agent folder, named `YYYY-MM-DD-<topic>.md`

## Key Scripts

| Script | Usage | Purpose |
|--------|-------|---------|
| `scripts/plan-promote.sh <file> <stage>` | `bash scripts/plan-promote.sh plans/proposed/foo.md approved` | Move a plan out of `proposed/` (unpublishes Drive doc automatically) |
| `scripts/safe-checkout.sh <branch>` | `bash scripts/safe-checkout.sh my-branch` | Safe branch switch via git worktree |
| `tools/decrypt.sh` | Called internally | Decrypt age-encrypted secrets; never call `age -d` directly |
| `agents/health/heartbeat.sh <name> <platform>` | `bash agents/health/heartbeat.sh evelynn windows` | Register agent liveness at session start |

## Plugins

19 plugins are installed at user scope. Key ones:

| Plugin | Purpose |
|--------|---------|
| `context7` | Fetch live library/framework docs |
| `firecrawl` | Web scraping and search |
| `playwright` | Browser automation |
| `figma` | Design-to-code workflows |
| `firebase` | Firebase project management |
| `coderabbit` | AI code review |
| `pr-review-toolkit` | PR analysis (tests, types, silent failures) |
| `superpowers` | Core skills (TDD, debugging, planning workflows) |
| `frontend-design` | High-fidelity UI implementation |
| `goodmem` | Memory/embedder management |

**Sub-agent access:** Plugin MCP tools are available to sub-agents as deferred tools. Sub-agents must call `ToolSearch` to load the schema before invoking any MCP tool — calling without schema load fails with `InputValidationError`.
