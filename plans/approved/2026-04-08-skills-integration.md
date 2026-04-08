---
status: proposed
owner: syndra
date: 2026-04-08
title: Claude Skills Integration — Migration Plan for the Strawberry Agent System
gdoc_id: 1ScvmPhEXni2GyhQns6Mt1oshjNQOx8LUzO24_26N-kw
gdoc_url: https://docs.google.com/document/d/1ScvmPhEXni2GyhQns6Mt1oshjNQOx8LUzO24_26N-kw/edit
---

# Claude Skills Integration

## Problem

Claude Code now ships a first-class **Skills** system. A skill is a `SKILL.md` file with YAML frontmatter and markdown body, living in one of four scopes (enterprise, personal `~/.claude/skills/`, project `.claude/skills/`, or plugin). Skills are:

- **Auto-discoverable by the model**: descriptions are loaded into the agent's context at session start; the full body only loads when the skill is invoked (by the model, by a slash command, or both).
- **User-invokable via `/skill-name`**: every skill is also a slash command. Custom commands in `.claude/commands/` have been merged into the skills system — same machinery.
- **Scoped by tool**: `allowed-tools` in frontmatter restricts which tools the skill may use when active.
- **Subagent-aware in two directions**: (a) a skill can `context: fork` into a subagent for isolated execution, and (b) a subagent can `skills:` preload specific skills into its startup context.
- **Dynamic**: `` !`cmd` `` placeholders run shell commands and inject the output into the skill body before the model sees it.

Strawberry's current architecture predates all of this. Every capability — locking the screen, safe git checkouts, session closing, the startup sequence, plan publishing — is encoded either as: (a) prose in `CLAUDE.md` rules, (b) a bash script in `scripts/`, or (c) a full-blown subagent with its own profile, memory, and session protocol. That's the entire tool inventory. There is no skill surface at all, and no integration with the slash-command system that Claude Code now offers natively.

The ask from Duong: **draft a migration plan that adopts skills into the existing subagent setup**.

This plan is not "add some skills and see what sticks." It's a systematic re-partition of the existing capability surface across three tools — skill, agent, script — with explicit criteria for each, a re-evaluation of the pending Tibbers plan, a proposed initial skill set, and a migration ordering that flags reversibility.

## How skills actually work (verified against docs)

Before any design, the mental model. Every claim below is sourced from `code.claude.com/docs/en/skills` and `code.claude.com/docs/en/sub-agents`.

### File layout

```
<scope>/skills/<skill-name>/
  SKILL.md              # required: frontmatter + instructions
  reference.md          # optional supporting docs
  examples/             # optional
  scripts/              # optional scripts the skill can run
```

`SKILL.md` is the entrypoint. Supporting files are only loaded when the skill references them in its body. Skill directories can be nested — Claude Code auto-discovers skills in `.claude/skills/` from subdirectories when editing files in those subtrees (monorepo-friendly).

### Four scopes, strict priority order

| Scope | Path | Applies to |
|---|---|---|
| Enterprise | managed settings | all org users |
| Personal | `~/.claude/skills/<name>/SKILL.md` | all of Duong's projects |
| Project | `.claude/skills/<name>/SKILL.md` | this repo only |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | wherever the plugin is enabled |

Name collisions: enterprise > personal > project. Plugin skills use a `plugin-name:skill-name` namespace and can't collide.

### Frontmatter (the important fields)

```yaml
---
name: my-skill                    # slash command name, a-z0-9-
description: what/when           # used by Claude to auto-load, 250-char soft cap
disable-model-invocation: true   # user-only, Claude cannot auto-invoke
user-invocable: false            # background-only, only Claude can invoke
allowed-tools: Read Grep         # scoped tool access while active
paths: "src/**/*.ts"             # auto-load only when editing matching files
context: fork                    # run in a forked subagent
agent: Explore                   # which subagent type to fork to
model: haiku                     # model override
effort: low                      # effort override
hooks: ...                       # lifecycle hooks
---
```

Two substitution mechanisms in the body:

- `$ARGUMENTS`, `$ARGUMENTS[N]`, `$0` / `$1` — args passed when invoked
- `` !`shell command` `` and ` ```! ` fenced blocks — run at load time, output is inlined into the prompt *before Claude sees it*. This is preprocessing, not tool-calls.

### Invocation paths

1. **Auto-load by model**: Claude sees the description in context, decides to load the full body when relevant. Disable with `disable-model-invocation: true`.
2. **Slash command**: `/skill-name arg1 arg2` — user triggers explicitly.
3. **Context-fork**: `context: fork` runs the skill as a new subagent task.
4. **Subagent preload**: a subagent's frontmatter `skills:` list injects the full skill body at subagent startup.

### The load-bearing skill ↔ subagent facts

Directly from `/en/sub-agents`, verbatim:

> "Subagents don't inherit skills from the parent conversation; you must list them explicitly."

> "Subagents cannot spawn other subagents. If your workflow requires nested delegation, use Skills or chain subagents from the main conversation."

These two sentences dictate most of the architecture in this plan. Translated:

1. **No automatic inheritance.** If Evelynn has skill X loaded and she spawns Pyke as a subagent, Pyke does not see X. Pyke's profile must explicitly declare `skills: [X]` in its frontmatter to preload X, or X must be a project skill that Pyke discovers independently via its own `.claude/skills/` scan — but even then, the *description* gets auto-loaded, not the body.
2. **Subagents cannot spawn subagents.** Strawberry's entire "Evelynn delegates to specialists who delegate to sonnets" mental model *breaks* when agents run as subagents (which they now do, per `a161190 chore: add windows mode — subagents + remote control for non-Mac machines`). Skills are the *official workaround* for nested delegation. This is not a nice-to-have — it is a structural forcing function.

### Plugins and the marketplace

Plugins ship with their own `skills/` directories. The installed `claude-plugins-official` marketplace already contains a `skill-creator` plugin and skill-bundled plugins for telegram, discord, imessage, github, gitlab, firebase, supabase, terraform, playwright, linear, asana, slack, context7, greptile, laravel-boost, serena, fakechat. These are first-party or blessed community plugins, not arbitrary third parties. Project skills can be committed to the repo's `.claude/skills/` and ship with the codebase — no marketplace involvement.

### Bundled skills (already available in this session)

`/batch`, `/claude-api`, `/debug`, `/loop`, `/simplify` ship with Claude Code itself. The ones Evelynn's system reminder mentioned (`update-config`, `keybindings-help`, `schedule`) are harness-level, available everywhere. Nothing to install.

## Skill vs agent vs script — decision matrix

| Dimension | Skill | Subagent | Script |
|---|---|---|---|
| **Cost** | Zero new tokens; body loaded into current context | New context window, own model tier, own startup cost | Zero tokens |
| **Isolation** | None (runs in caller's context) unless `context: fork` | Full (own context window) | Full (no LLM at all) |
| **Statefulness** | Stateless per invocation | Can have memory/journal/profile | Stateless |
| **Judgment required** | Yes (it's a prompt) | Yes (it's a prompt) | No (deterministic) |
| **Natural language input** | Yes (`$ARGUMENTS` parses intent) | Yes | No (exact syntax) |
| **Persists across sessions** | As a file in the repo | As an agent with memory dirs | As a file in the repo |
| **Discoverability** | Slash menu + auto-load | Roster + profile | Only if caller knows the path |
| **Best for** | Procedural discipline: "when doing X, follow this playbook" | Deep domain work needing a fresh context | Deterministic procedures with no judgment |
| **Worst at** | Heavyweight work that blows out caller's context | Trivial one-shot work (cost + latency) | Anything needing language understanding |

### Decision heuristics

Pick **skill** when:
- The action is a *procedure* or *playbook* that the caller (Evelynn, or any agent) should follow inline.
- The work is stateless and short.
- It needs to wrap a shell/script with natural-language input and a refusal/discipline layer.
- It encodes a *convention or rule* that must be discoverable and applied consistently.
- It's something the caller does *often*, so spawning a subagent for it is wasteful.

Pick **subagent** when:
- The work genuinely benefits from a fresh context window (context isolation is the point).
- It has deep domain memory / persistent learnings.
- It specializes at the tier level (Opus planner, Sonnet executor, Haiku runner).
- The work is open-ended and multi-step in a way that would pollute the caller's context.

Pick **script** when:
- Zero judgment. No language parsing. Same input → same output, always.
- Runs in CI, hooks, or cron without a Claude session.
- Other scripts need to call it.

### The overlap trap

Skills and subagents overlap when the work is "run a disciplined procedure." A skill is cheaper (no new context), a subagent is safer (context isolation). The right call is a *gradient*:

- Procedure ≤ 100 tokens of prompt, low blast radius, called often → **skill**
- Procedure needs 500+ tokens of context to run safely, moderate blast radius, called sometimes → **skill with `context: fork`** (best of both: declarative like a skill, isolated like a subagent)
- Multi-step workflow, persistent memory, deep specialization → **subagent**

## The Tibbers re-evaluation

**Verdict: Tibbers becomes a skill. The Haiku subagent plan is withdrawn in favor of a `/run` project skill with `context: fork` and `agent: general-purpose` (or a dedicated stripped-down agent type).**

### Why the original plan is weaker now

The Tibbers plan (`plans/proposed/2026-04-08-errand-runner-agent.md`) proposed a Haiku 4.5 subagent whose entire discipline — the allowed list, the denylist, the refusal format, the tool allowlist — lives in its profile.md and is rehydrated on every spawn. The cost justification was "Haiku is cheaper than Opus for trivial shell commands."

That reasoning is correct in a vacuum. It ignores two things the skills doc makes explicit:

1. **Spawning a subagent has a fixed overhead cost regardless of model tier** — new context window, startup, tool discovery, profile load. For a command that takes one Bash call, the overhead dominates the per-token savings. Haiku's cheapness doesn't compensate for the round-trip.
2. **Skills can enforce exactly the same discipline a profile can**, via frontmatter (`allowed-tools: Bash Read Grep Glob`), body prose (the allowed/forbidden list), and dynamic context (`` !`pwd` `` to verify the working directory before running anything). The discipline lives in the *same scope* where the work runs — Evelynn's context — so there's no inheritance problem.

### What the skill version looks like

`/run <natural language command>` — a project skill at `.claude/skills/run/SKILL.md`:

```yaml
---
name: run
description: Run a trivial one-shot shell command. Use for lock screen, open folder, process check, read-only git inspect, single-file cat. Refuses anything needing a plan, judgment, or mutation.
allowed-tools: Bash Read Grep Glob
disable-model-invocation: false
---

Run the following trivial shell command. Follow the hard scope rules.

## Allowed
- Single shell command or single logical pipeline
- Read-only fs inspection
- Read-only git inspection (status, log, diff — no args that mutate)
- Process inspection
- Lock screen, open folder, clipboard copy, notification
- Wall time < 10s

## Forbidden — refuse with "out of scope: <reason>"
- Any file edit, git mutation, agent spawn, web fetch
- Reading > 1 file, output > 50 lines
- Anything touching secrets/ .env credentials
- Anything needing elevation (sudo/runas/UAC)
- Anything on the denylist below

## Denylist (hard refuse)
shutdown restart reboot halt poweroff
rm -rf rm -r  del /s  del /q  Remove-Item -Recurse
format mkfs diskpart
taskkill /f  kill -9  Stop-Process -Force
chmod 777  icacls grant  takeown
curl wget Invoke-WebRequest iwr
sudo runas gsudo
eval exec Invoke-Expression
git (commit|push|pull|merge|rebase|reset|clean|stash|add|checkout|branch -D)
secrets/ .env id_rsa *.pem *.key credentials ~/.ssh ~/.aws ~/.config/gh
heredocs or > redirects outside /tmp

## Output format
- Command with output: return raw output, nothing else
- Command with no output: return "done." and stop
- Failure: "failed: <reason>"
- Refusal: "out of scope: <reason>"

Command: $ARGUMENTS
```

Evelynn says "lock my screen" → she invokes `/run lock my screen` (or the model auto-invokes the skill from description match) → the skill body is injected into Evelynn's context with the discipline rules → Evelynn runs the Bash tool directly → returns the result.

Zero new subagent. Zero new context window. Same discipline. Cheaper, faster, simpler.

### What we lose vs the Tibbers subagent plan

- **Context isolation**. The scope rules live in Evelynn's context now, and Evelynn could in theory ignore them. Mitigation: the skill is short and discipline-heavy, Evelynn's profile gets a one-line rule "when running a shell errand, use `/run`", and refusal is the default posture encoded in the skill body.
- **Haiku tier savings**. Evelynn runs Opus-tier for the one Bash call. If this becomes a real cost line item (track for two weeks post-launch), upgrade the skill to `context: fork` and `agent: <haiku-errand>` — that gives back Haiku-tier execution with the same skill interface. The skill ↔ subagent bridge means this is a one-line change, not a re-architecture. **This is the reversibility unlock.**
- **Distinct identity and audit trail**. Tibbers-as-a-name had a cultural purpose ("it's property, not a peer"). The skill loses that framing. The audit trail is preserved — the transcript still shows `/run <cmd>` and the output — but there's no character identity to reinforce the discipline culturally. Acceptable loss; the frontmatter constraint is the enforcement mechanism anyway.

### Recommendation on the existing Tibbers plan

Move `plans/proposed/2026-04-08-errand-runner-agent.md` to `plans/archived/` once this plan is approved. Write a short supersession note at the top referencing this plan. Do not delete — the denylist and scope analysis in that plan are load-bearing research and the skill version re-uses them verbatim.

## Existing-system audit

For each existing capability, the right shape. Ordered by how interesting the call is.

| Capability | Current form | Recommendation | Rationale |
|---|---|---|---|
| **Trivial shell commands (Tibbers)** | Proposed Haiku subagent | **Skill** (`/run`) with path to `context: fork` fallback | See above |
| **`scripts/safe-checkout.sh`** | Bash script (CLAUDE.md rule 5) | **Skill wrapping the script** (`/checkout`) | Script stays as the deterministic engine; skill adds discipline + refusal ("don't `git checkout` directly, route through this") and is auto-discoverable via slash menu. Prevents the rule being silently ignored. |
| **Session closing protocol** | Prose in `agent-network.md`, each agent executes manually | **Skill** (`/close-session`) with `disable-model-invocation: true` | Five mandatory steps that currently depend on agent discipline. A user-invocable skill runs them as a checklist with dynamic context injection for the log_session call. Much harder to skip a step. |
| **Startup sequence** | Prose in `CLAUDE.md`, each agent executes manually | **Skill** (`/bootstrap`), `user-invocable: false`, auto-loaded at session start via an initial-prompt mechanism | This is the most ambitious and the most fragile. Needs research into whether a skill can actually run at session open. If not — stays as prose. Flag: risky, see Migration Ordering. |
| **Secrets handling protocol** | Feedback memory + `secrets/` dir + gitleaks hook | **Skill** (`/secret-needed <name>`) with `disable-model-invocation: true` | A user-invokable skill that walks the "stop, prompt Duong, wait for file, source and verify by length" dance deterministically. The memory stays as the *rationale*; the skill is the *procedure*. Also shippable as a project skill so every agent in the repo gets it. |
| **Plan publish/fetch/unpublish** (Swain's plan) | Scripts, not yet built | **Scripts called by skills** (`/plan-publish`, `/plan-fetch`, `/plan-unpublish`) | The gdoc sync is deterministic and belongs in a script. The natural-language entry point ("publish this plan") belongs in a skill. Swain's plan should be amended to specify the skill wrapper — flag to Evelynn. |
| **`scripts/health-check.sh`** | Bash script | **Skill** (`/health`) that runs the script and interprets output | Script does the work, skill turns raw output into a human summary. Example of the "wrap deterministic core with natural-language skin" pattern. |
| **Heartbeat registration** | `agents/health/heartbeat.sh <name> <platform>` | **Script, unchanged. Skill-triggered from `/bootstrap`** | Pure determinism. The skill layer just calls it. |
| **Pyke (git specialist)** | Opus subagent | **Subagent, unchanged** | Deep specialization, needs own context for audit work, multi-step judgment. Keep as subagent. Add `skills: [safe-checkout, secret-needed]` to his frontmatter so he preloads the git discipline skills without re-deriving them. |
| **Syndra / Swain / Bard** | Opus subagents | **Subagents, unchanged** | Same reasoning as Pyke. These are deep specialists, not procedures. |
| **Katarina / Ornn / Fiora / Lissandra / Rek'Sai** | Sonnet subagents | **Subagents, unchanged** | Same. Implementers need a clean context per task. |
| **Caitlyn (QC)** | Sonnet subagent | **Subagent, unchanged** | Same. |
| **Evelynn** | Opus head agent | **Subagent, unchanged** but with expanded `skills:` list | Evelynn is the skill-heaviest agent — she's the router and the surface Duong talks to, so every workflow skill should preload into her. |
| **The CLAUDE.md rules themselves** | Prose | **Stay as prose** | Rules are declarative policy, not procedures. A skill that says "follow the rules" adds nothing. The rules-restructure plan (sister plan) addresses rules surface quality. This plan does not touch CLAUDE.md rules directly. |

## Initial project skill set (six skills, shipped in `.claude/skills/`)

Cap at six, committed to the repo, owned by the project. All are `name: <short-name>`, project-scoped, versioned in git.

1. **`/run`** — trivial shell command with discipline + denylist. Replaces the Tibbers subagent. (See above.)
2. **`/checkout <branch-or-worktree>`** — safe git checkout wrapping `scripts/safe-checkout.sh`. `allowed-tools: Bash`. Enforces CLAUDE.md rule 5 by being the discoverable path — typing `/checkout` is easier than remembering the rule.
3. **`/close-session`** — session closing protocol as a five-step checklist skill. `disable-model-invocation: true` (only the user ends the session). Uses dynamic context injection (`` !`date` ``, `` !`git log -1 --oneline` ``) to prefill the log entry. Replaces the manual prose-driven ritual.
4. **`/secret-needed <var-name> [group]`** — walks Duong through the file-based secret delivery protocol. `disable-model-invocation: true` (Duong is in the loop by design). Embeds the rationale so any agent in any session applies it the same way. Replaces the feedback-memory-as-discipline pattern with a skill-as-discipline pattern.
5. **`/plan-propose <slug>`** — scaffolds a new plan file in `plans/proposed/` with correct frontmatter (`status: proposed`, `owner: <caller>`, `date: <today>`, `title: ...`) and the standard section skeleton. Enforces CLAUDE.md rules 7-9 by being the path of least resistance. Replaces the "remember the frontmatter format" problem.
6. **`/agent-brief <agent> <task>`** — generates a well-structured brief for spawning a specialist subagent (problem statement, context, constraints, expected output). Encodes the delegation-to-specialists feedback-memory rule as a tool Evelynn actually uses. Shows Duong that Evelynn is routing, not drafting.

**Deliberately not in the initial set:**

- `/bootstrap` (startup sequence) — too risky for v1, needs research into session-init hooks. Defer to v2.
- `/health`, `/commit-ratio`, and similar script wrappers — not enough friction today to justify the skill layer. Add later if the scripts get called often.
- `/simplify`, `/batch`, `/loop`, `/schedule` — bundled skills, already available, no action needed.
- Anything that overlaps with a bundled skill.

## External skills to pull in

**Conservative recommendation: zero external skills for v1, one for v2.**

The `claude-plugins-official` marketplace is already installed at `~/.claude/plugins/marketplaces/claude-plugins-official/`. It contains plugins with skills for: telegram, discord, imessage, github, gitlab, firebase, supabase, terraform, playwright, linear, asana, slack, context7, greptile, laravel-boost, serena, fakechat. Also `skill-creator` (a skill that helps author other skills).

Of these, the only one that clearly fits Strawberry today is **`telegram`** — the repo already has telegram bridge infrastructure (`scripts/start-telegram.sh`, `scripts/telegram-bridge.sh`), and a skill-based interface to it would replace some of the manual bridge orchestration. But the repo's existing bridge is bespoke (Windows mode, inbox-driven) and the plugin may not fit. **Defer to Bard** to evaluate whether the plugin's telegram skills subsume the current bridge or conflict with it. Do not install the plugin blind.

Also consider **`skill-creator`** itself in v2 — when we start writing more skills, having a skill that generates skill boilerplate is meta-correct. Install when we hit skill #7.

Nothing else in the marketplace aligns with current Strawberry needs. No community skill directory outside plugins currently exists (or at least none that the docs point to). Document this as "none today, reassess quarterly."

## Skill ↔ subagent interaction model — the headline architectural call

This is the most important design decision in the plan because it resolves the "will my agents see my skills?" question for the entire system.

**Decision: project-scoped skills in `.claude/skills/`, plus per-agent `skills:` preload declarations in each subagent's frontmatter.** Not inheritance. Explicit preload. Belt and suspenders.

### Why this is the only correct answer

The docs are unambiguous (direct quote, worth repeating): *"Subagents don't inherit skills from the parent conversation; you must list them explicitly."*

This rules out a "load everything into Evelynn, let it cascade" model. If Evelynn has `/secret-needed` and spawns Pyke to handle encrypted-secrets implementation, Pyke does not automatically see `/secret-needed`. Pyke will either: (a) re-derive the protocol (bad, wastes tokens and risks drift), or (b) fail to follow it (bad, violates the discipline the memory was supposed to fix), or (c) have been pre-declared with `skills: [secret-needed]` in his own profile frontmatter (correct).

### The preload pattern

Every subagent profile gets a `skills:` frontmatter list declaring which skills are relevant to its role. Example for Pyke:

```yaml
---
description: Git and IT security specialist...
skills:
  - secret-needed
  - checkout
  - run
---
```

For Evelynn (everything she might need to route):

```yaml
---
description: Head coordinator...
skills:
  - run
  - checkout
  - close-session
  - secret-needed
  - plan-propose
  - agent-brief
---
```

For implementers (Katarina, Ornn, Fiora):

```yaml
skills:
  - checkout
  - secret-needed
```

Implementers get a smaller list because their job is narrower. They don't spawn agents, don't close sessions on their own (Evelynn orchestrates), don't write plans.

### Why this doesn't cause context bloat

A skill's *description* is always in context (250-char soft cap). Its *body* only loads on invocation. For subagents using `skills:` preload, the body is injected at startup — so there's a real context cost per preloaded skill. Keep per-agent preload lists tight. Six-ish maximum per agent.

### The ambient project skills layer

Project-scoped `.claude/skills/` is auto-discovered by any Claude Code session in the repo. So any agent running in this repo — even a fresh Claude Code session without a specific agent profile — sees the skill *descriptions* automatically. That gives Duong himself a working slash-menu of `/run`, `/checkout`, `/close-session`, etc., without any agent-specific config. This is a free win.

### What subagents spawned from subagents should do — the nested delegation problem

Also verbatim from the docs: *"Subagents cannot spawn other subagents. If your workflow requires nested delegation, use Skills or chain subagents from the main conversation."*

Strawberry's current model is Evelynn → specialist Opus agent → Sonnet implementer. In the iTerm world this works because each "agent" is actually an independent iTerm session that Evelynn messages via MCP, not a subagent. In **windows mode (subagent mode)**, which the repo just added in commit `a161190`, this chain breaks: if Evelynn is running as a subagent, she cannot spawn another subagent. Specialists running under Evelynn cannot spawn implementers.

This is already a known problem — the current workaround is that Evelynn-as-subagent writes plans/briefs and the *human* routes them to the next agent. Skills don't fix this fully, but they *do* provide a workaround for procedures:

- Anything that was "Evelynn spawns a Haiku subagent to run a command" → **skill**. Resolved.
- Anything that was "Evelynn spawns Pyke to write a security plan" → **still broken in subagent mode**; Evelynn writes the brief, Duong (or the iTerm session) spawns Pyke.
- Anything that was "Pyke spawns Katarina to implement" → **still broken in subagent mode**; Pyke writes a plan, Duong approves and Evelynn spawns Katarina from the top level.

**This means the skills migration partially paves a path out of the subagent-mode limitation, but only for procedural work.** Strategic / deep-specialist work still requires top-level subagent spawning, which means Duong-in-the-loop. Flag this as an open question for the rules-restructure plan.

## Anti-patterns to avoid

Named risks and how to avoid them. These are failure modes I'd expect to hit if we move too fast.

1. **Context bloat from too many preloaded skills.** Each skill in a subagent's `skills:` list injects the full body at startup. Six skills at 200 lines each = 1200 lines of system prompt before the agent does anything. Mitigation: cap preload lists at 6. Prefer auto-load-by-description for situational skills; only preload skills the agent uses on every run.

2. **Skill description noise.** Descriptions always load (subject to `SLASH_COMMAND_TOOL_CHAR_BUDGET`). If we ship 30 skills, the descriptions start crowding out agent profiles. Mitigation: initial set is 6. Re-evaluate before adding #7. Front-load descriptions so the key use case is in the first 60 chars (docs recommend this, it's for a reason).

3. **Skill/agent routing confusion.** "Should I invoke `/run` or spawn Pyke?" Mitigation: the agent-brief skill (`/agent-brief`) should include a decision heuristic in its body ("if the task is a trivial procedure → skill; if it's a multi-step plan → spawn specialist"). Codify the dispatching logic where the dispatcher will actually read it.

4. **Project skills drifting out of sync with agent profiles.** If we rename `/run` → `/errand` and forget to update every subagent's `skills:` list, preloads silently fail (Claude just doesn't find the skill). Mitigation: a script `scripts/verify-skill-refs.sh` that grep's every `.claude/agents/*.md` frontmatter for `skills:` entries and verifies the skill exists in `.claude/skills/`. Run in CI.

5. **Skills that fail silently.** A skill body runs, the model claims success, but the underlying Bash command actually errored. Same failure mode as Tibbers had. Mitigation: every skill that runs a shell command must check exit codes and state "failed: <reason>" explicitly. Bake this into the `/plan-propose` template so new skills default to it.

6. **Skills that duplicate CLAUDE.md rules.** If `/checkout` says "use git worktree" and CLAUDE.md rule 5 also says "use git worktree," the two can drift. Mitigation: make the skill *the* source of truth for the procedure, and have CLAUDE.md rule 5 reference the skill name rather than restate the procedure. ("Never use raw `git checkout`. Use `/checkout`.") Coordinate with the rules-restructure plan.

7. **Skills used as a substitute for subagents when isolation actually matters.** A skill that does deep research in the main context will blow out that context. Mitigation: when in doubt, use `context: fork`. Reviewers should flag any PR that adds a skill with more than ~50 lines of body that *doesn't* have `context: fork`.

8. **Over-invocation of `disable-model-invocation: true`.** Tempting to lock everything down so Claude can only run skills the user explicitly types. But the auto-loading is half the value — Claude picks up `/checkout` when the user says "switch to the fix branch." Mitigation: `disable-model-invocation: true` only for skills with side effects or timing dependencies (deploy, close-session, secret-needed). Everything else stays auto-invocable.

9. **Plugin skill adoption without review.** Installing `telegram` plugin blindly could conflict with Strawberry's existing telegram bridge. Mitigation: zero external plugin skills in v1. Bard evaluates v2 additions.

## Migration ordering

Five phases. Each phase has a **reversibility** tag: `easy` (delete one file), `medium` (undo partial integration), `hard` (wider refactor to undo).

### Phase 1 — Infrastructure (reversibility: easy)

1.1. Create `.claude/skills/` directory at repo root. Empty.
1.2. Add a short section to `architecture/agent-system.md` documenting the skills scope and conventions for this repo (file format, preload pattern, naming).
1.3. Add `scripts/verify-skill-refs.sh` that validates skill references in agent profiles. Run manually for now.

No behavioral change yet. Pure scaffolding. Reversible by deleting the empty directory.

### Phase 2 — Two low-risk skills as proof of concept (reversibility: easy)

2.1. Ship `/checkout` as the first skill. It wraps an existing script, has zero blast radius beyond what the script already does, and tests the plumbing end-to-end.
2.2. Ship `/plan-propose` as the second skill. It creates a file in `plans/proposed/` — pure additive, no destructive capability.
2.3. Update Evelynn's profile frontmatter with `skills: [checkout, plan-propose]` to test the preload mechanism.
2.4. Manual verification: run Evelynn, confirm both skills appear in `/` menu, invoke each, confirm behavior.

Easy win, low risk, tests every piece of the integration (skill authoring, project scope discovery, preload, slash invocation). If something is fundamentally wrong about the integration model, we find out here while the blast radius is two trivial skills.

### Phase 3 — `/run` (the Tibbers replacement) (reversibility: medium)

3.1. Author `/run` per the spec in the Tibbers re-evaluation section above.
3.2. Move `plans/proposed/2026-04-08-errand-runner-agent.md` → `plans/archived/` with a supersession note.
3.3. Update Evelynn's `skills:` list and profile to mention that trivial shell errands use `/run`.
3.4. **Two-week observation period.** Track: how often is `/run` invoked? How often does it refuse? Does Evelynn ever bypass it and run Bash directly (discipline failure)?
3.5. If observations show bypass or drift, upgrade to `context: fork` with a Haiku agent — the reversibility is built in to the skill design.

Medium reversibility because archiving the Tibbers plan is a visible decision and undoing it means resurrecting the plan. The `/run` skill itself is deletable.

### Phase 4 — Disciplinary skills (reversibility: medium)

4.1. Ship `/secret-needed`. Update Evelynn, Pyke, and all implementer agents' `skills:` lists to preload it. Announce in a commit message: "all agents now use /secret-needed for the secret handoff protocol."
4.2. Ship `/close-session`. User-invocable only. Test manually across a few agent sessions before making it mandatory.
4.3. Ship `/agent-brief`. Evelynn-only. Update Evelynn's profile to prefer `/agent-brief` when spawning specialists.

Medium reversibility because these touch agent profiles and change discipline. Undo path: delete the skills, revert the profile edits. Not hard, but not free.

### Phase 5 — Risky experiments (reversibility: hard)

5.1. Investigate `/bootstrap` (startup sequence as a skill). Research question: can a skill run automatically at session open, or does every agent profile need to explicitly invoke it? If not automatic, it's a lateral move from the current prose-based startup sequence and not worth the complexity. Defer indefinitely if automation isn't there.
5.2. Evaluate first external plugin skill (likely `telegram`). Bard drives. If it fits, install under a feature flag. If it conflicts with existing bridges, document and skip.

Hard reversibility because these touch the session boot path and external dependencies. Do not proceed without explicit Duong approval per item.

### Non-goals for this migration

- Converting every script to a skill. Scripts are fine as scripts when they're called from CI or hooks.
- Converting specialist Opus agents to skills. Specialists exist for context isolation and deep domain work — skills would lose that.
- Building a skill marketplace or sharing mechanism beyond committing to this repo.
- Replacing CLAUDE.md. The rules stay as prose. Skills reference rules; they don't replace them.

## Coordination with the rules-restructure plan

The sister plan running in parallel (`plans/proposed/2026-04-08-rules-restructure.md`, being drafted by another Syndra instance) is restructuring CLAUDE.md and the rules surfaces. This plan and that plan share a rules surface in that **skills are a new rules surface**: skill frontmatter encodes tool scoping, invocation rules, and (via `allowed-tools`) permission decisions. Without redesigning the rules structure here, I flag what the skills migration needs the rules surface to provide:

1. **A "rules can reference skills" pattern.** CLAUDE.md rule 5 ("use `git worktree`, use `scripts/safe-checkout.sh`") should be rewritable as "use `/checkout`." The rules-restructure plan needs to accommodate rules that reference skill names, and keep those references valid when skills are renamed or removed. Ideally the `scripts/verify-skill-refs.sh` check covers this — grep CLAUDE.md for skill references alongside agent profiles.

2. **A "skills don't replace rules" principle.** Worth stating explicitly in the rules surface: rules are policy, skills are procedure. A rule can require that a procedure be used, but the rule itself stays in CLAUDE.md. This prevents a future drift where we start putting declarative constraints into skill bodies and the two surfaces fragment.

3. **A registry of project skills in architecture docs.** `architecture/agent-system.md` currently lists agents; it should gain a "Skills" subsection that mirrors the agent list — name, purpose, which agents preload it. Keeps the two surfaces discoverable together.

4. **Agent profile frontmatter convention**. Agent profiles already have frontmatter (description, etc.). The rules-restructure plan should standardize the `skills:` list location and format, and the verify-skill-refs script depends on that standard. Flag this as a coordination handoff.

No hard blocker. The plans are compatible. Sequence: rules-restructure lands first (cleans up the prose surface), then skills migration (adds the new procedural surface on top).

## Open questions for Duong

1. **Tibbers supersession.** Plan recommends withdrawing `plans/proposed/2026-04-08-errand-runner-agent.md` in favor of `/run` skill. Agreed?
2. **Initial skill set.** Six skills proposed (`run`, `checkout`, `close-session`, `secret-needed`, `plan-propose`, `agent-brief`). Any to drop or add for v1?
3. **External plugin skills.** Recommend zero for v1, Bard evaluates telegram plugin for v2. Agreed, or is there a plugin you specifically want pulled in early?
4. **`/bootstrap` experiment.** Risky phase-5 item — converting the agent startup sequence to a skill. Skip entirely, defer to "see if we want it later," or explore in phase 5 as proposed?
5. **Preload list size cap.** Plan suggests max 6 skills preloaded per agent to control context bloat. Hard cap, soft cap, or no cap?
6. **Nested delegation workaround.** Flagged that windows/subagent mode breaks `Evelynn → specialist → implementer` chain, and skills only paper over the procedural half. Is that acceptable, or should the rules-restructure plan explicitly address the iTerm-vs-subagent-mode split?
7. **Timing relative to rules-restructure plan.** This plan assumes rules-restructure lands first. Confirm sequencing, or should skills migration run in parallel?

## Success criteria

- Six skills live in `.claude/skills/`, versioned in git, discoverable via `/` in any agent session in this repo.
- Evelynn, Pyke, and at least two implementer subagents have `skills:` preload lists and demonstrably use the preloaded skills (visible in their transcripts).
- `/run` is invoked at least once per Evelynn session for trivial commands (adoption check). No Bash-for-trivial-tasks bypass observed for two weeks.
- The archived Tibbers plan has a clear supersession note and is referenced from this plan's implementation PR.
- `scripts/verify-skill-refs.sh` passes in CI, catching any renamed/deleted skills that still have references.
- `architecture/agent-system.md` has a skills section that mirrors the agent roster in shape and completeness.
- Zero incidents of a skill running a denylisted command (applies to `/run` and `/checkout` specifically).
- Skill description budget stays under 50% of `SLASH_COMMAND_TOOL_CHAR_BUDGET` (leaves headroom for more skills without eating into context).

## Out of scope for this plan

- Authoring the skill files themselves (implementer task after approval).
- Updating individual agent profiles with `skills:` lists (implementer task, one per agent).
- Writing `scripts/verify-skill-refs.sh` (implementer task).
- Researching and installing the `telegram` plugin (Bard task, phase 5).
- Any change to CLAUDE.md rules (coordinated with the rules-restructure plan).
- Building `/bootstrap` (explicitly deferred to phase 5 pending research).
- Metrics/telemetry for skill invocation counts (nice-to-have, not blocking).

## Decisions

Blanket approval from Duong on 2026-04-08 ("all good, proceed as proposed"). Each open question resolved as follows:

1. **Tibbers supersession.** Approved as proposed by Duong 2026-04-08 — withdraw the Tibbers errand-runner plan in favor of the `/run` skill. The Tibbers plan is being archived as part of this approval batch.
2. **Initial skill set.** Approved as proposed by Duong 2026-04-08 — ship the six skills (`run`, `checkout`, `close-session`, `secret-needed`, `plan-propose`, `agent-brief`) as v1.
3. **External plugin skills.** Approved as proposed by Duong 2026-04-08 — zero external plugin skills in v1; Bard evaluates the telegram plugin for v2.
4. **`/bootstrap` experiment.** Approved as proposed by Duong 2026-04-08 — explore in phase 5 as proposed.
5. **Preload list size cap.** Approved as proposed by Duong 2026-04-08, per the recommendation in the plan — cap preloaded skills at 6 per agent.
6. **Nested delegation workaround.** Approved as proposed by Duong 2026-04-08 — accepted that skills paper over the procedural half of the nested-delegation gap; rules-restructure does not need to resolve the iTerm-vs-subagent split as a blocker for this plan.
7. **Timing relative to rules-restructure plan.** Approved as proposed by Duong 2026-04-08 — rules-restructure lands first, then skills migration.
