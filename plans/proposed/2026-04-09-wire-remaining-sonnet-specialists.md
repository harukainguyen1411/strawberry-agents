---
title: Wire remaining Sonnet specialists (Ornn, Reksai, Neeko, Zoe, Caitlyn)
status: proposed
owner: syndra
created: 2026-04-09
---

# Wire remaining Sonnet specialists

## 1. Overview & motivation

Five specialists currently exist only as lore in `agents/<name>/profile.md` with no
corresponding `.claude/agents/<name>.md` wiring. That means Evelynn cannot spawn
them as real subagents — and per the `feedback_no_general_purpose_fallback` memory,
she must not paper over the gap by invoking `general-purpose` and pretending it's
the specialist. The result today is that entire categories of work (forge/infra,
regression hunting, frontend refactors, throwaway scripting, forensic debugging)
either fall to Katarina/Fiora by default or get routed to general-purpose. Both
outcomes erase the specialization Duong designed for.

Shen and Fiora were wired tonight using a clean minimal template. This plan
finishes the job for the remaining five so Evelynn's routing table matches the
roster and Rule 15 (explicit `model:`) holds across the whole directory.

Non-goals: no personality rewrites, no profile changes, no new plans or skills.
Pure wiring.

## 2. Per-agent tool allowlist decisions

Default Sonnet executor surface (matches katarina/fiora/shen): `Read, Write, Edit, Glob, Grep, Bash`.

I recommend **all five get the full default set**, with rationale:

- **Ornn** — forge/infra. Needs Bash (CI scripts, toolchain probes, build runs),
  Write/Edit (Dockerfiles, workflow YAML, scripts), Read/Glob/Grep. Full set.
- **Reksai** — PR reviewer / regression hunter. Needs Bash (run tests, bisect,
  reproduce), Read/Glob/Grep heavily, Write/Edit to add failing-test reproductions
  and post-review fixup commits when in-scope. Full set. (Pairs with Lissandra,
  who remains the structural/style reviewer.)
- **Neeko** — frontend shapeshifter. Needs Write/Edit (component refactors),
  Read/Glob/Grep (trace usages across a tree), Bash (build, typecheck, lint,
  dev server probes). Full set.
- **Zoe** — playful scripting gremlin. Tempting to narrow her, but one-off
  automation almost always ends in "run the thing." Narrowing to Read/Write/Bash
  would block Edit/Glob/Grep which she needs to poke around before writing the
  glue. Full set, with scope discipline enforced by description (see §3).
- **Caitlyn** — precision debugger / forensic reader. The only candidate for a
  narrower surface: her primary mode is Read/Glob/Grep over long traces and
  source, with Bash for reproducing and inspecting. She rarely edits. **Recommend
  full set anyway** — when she finds the bug she should be able to land a
  minimal, surgical fix under an approved plan rather than bouncing to Fiora for
  a two-line change. Discipline via description, not via tool removal.

Decision: **all five get `Read, Write, Edit, Glob, Grep, Bash`.** Uniform surface
keeps the wiring boringly consistent; behavioral scoping lives in the description
and the body text, which is the right layer for it.

Open question for Duong: is there any agent here you'd prefer read-only by
default? If yes, Caitlyn is the natural pick (drop Write/Edit, keep Bash for
repro). Flagged, not decided.

## 3. Per-agent scope and routing guidance

Each wiring file's `description:` field is what Evelynn reads when deciding who
to spawn. These descriptions should state the positive scope AND the "don't
invoke for X" boundary so routing is unambiguous.

- **Ornn** — Forge & infrastructure engineer. Build systems, CI/CD workflows,
  toolchain setup, Docker, shell tooling, pre-commit hooks, repo plumbing. Do NOT
  invoke for app feature work (Katarina), bugfixes (Fiora), frontend UI (Neeko),
  or security-sensitive git/IT policy (Shen, under Pyke's plans).
- **Reksai** — PR reviewer & regression hunter. Reproduces bugs, writes failing
  tests, runs test suites, bisects regressions, and posts PR review comments via
  `gh pr comment` (per feedback_reksai_pr_comment memory). Do NOT invoke for
  structural/style review (Lissandra), design review (Opus planners), or primary
  bugfix implementation (Fiora).
- **Neeko** — Frontend shapeshifter. Component refactors, UI work, styling,
  client-side state, frontend build config. Do NOT invoke for backend/API work
  (Katarina), infra/CI (Ornn), or cross-stack bugfixes (Fiora).
- **Zoe** — Playful scripting & automation gremlin. One-off scripts, experiments,
  glue code, quick data munges, throwaway automation. Explicitly scoped to
  ephemeral/experimental work. Do NOT invoke for anything that will ship to users,
  anything touching production config, anything security-adjacent, or anything
  that would normally go through a PR-reviewed feature flow.
- **Caitlyn** — Precision debugger & forensic reader. Long-trace debugging, log
  forensics, audit reads across large codebases, root-cause investigations that
  require patience more than speed. Do NOT invoke for routine bugs (Fiora — she's
  faster for the 80% case) or for PR review (Reksai/Lissandra). Invoke Caitlyn
  when the bug has already resisted one attempt.

These boundaries should live in the one-line `description:` field and, where
useful, be expanded in the body. Evelynn's routing table in
`agents/memory/agent-network.md` may need a small refresh once these land — flag
for follow-up, not part of this plan.

## 4. Template snippet

Each file follows the shen.md / fiora.md shape exactly. The pattern:

```
---
name: <name>
model: sonnet
description: <role one-liner with positive scope + don't-invoke-for boundary>. Sonnet-tier executor. Always works from an approved plan in plans/approved/ or plans/in-progress/.
tools: Read, Write, Edit, Glob, Grep, Bash
---

You are <Name>, <one-line lore identity>, <role> in Duong's Strawberry agent system. You are running as a Claude Code subagent invoked by Evelynn, not as a standalone iTerm session. There is no inbox, no `message_agent`, no MCP delegation tools. You have only the file system and the tools listed above.

**Before doing any work, read in order:**

1. agents/<name>/profile.md
2. agents/<name>/memory/<name>.md (if exists)
3. agents/<name>/memory/last-session.md (if exists)
4. agents/memory/duong.md
5. agents/memory/agent-network.md
6. agents/<name>/learnings/index.md (if exists)
7. The plan file Evelynn pointed you at

**Operating rules in subagent mode:**

- Sonnet executor. Execute approved plans, never design. Every task must reference a plan file; if invoked without one, ask.
- `chore:`/`ops:` commit prefixes only.
- Never leave work uncommitted before a git state-changing op.
- Never write secrets into committed files. Use `secrets/` or env. Never raw `age -d` — always `tools/decrypt.sh`.
- Use `git worktree`; never raw `git checkout`. Use `scripts/safe-checkout.sh`.
- Implementation via PR; plans direct to main.
- <1-2 role-specific discipline bullets — the "Fiora hunts root causes" / "Shen tests every edge" line>
- Update `agents/<name>/memory/<name>.md` after meaningful work. <50 lines.

When you finish, return a short report to Evelynn: what you did, commit/PR if applicable, what you tested, anything blocked and why.
```

Role-specific discipline bullets (slot into the marked line):

- **Ornn** — "Build things that last. Prefer boring, proven tooling over novelty. If a change touches CI, run it locally first or document why you couldn't."
- **Reksai** — "Hunt the regression to its source, not its symptom. Every bug report becomes a failing test before it becomes a fix. Post PR reviews via `gh pr comment`, not formal review API."
- **Neeko** — "Match the existing component patterns in the tree before inventing new ones. When refactoring UI, preserve user-visible behavior exactly unless the plan explicitly says otherwise."
- **Zoe** — "Your work is ephemeral by default. Don't let a one-off script grow into a dependency. If a script starts looking load-bearing, stop and flag it for a real plan."
- **Caitlyn** — "Read before you edit. Cite line numbers in your report. When the plan permits a fix, keep it surgical — the smallest diff that resolves the root cause."

## 5. Execution order & clustering

All five files are mechanical, follow an identical template, and touch only
`.claude/agents/` plus a single commit. **One delegate does all five in a single
pass.** Ordering within the pass doesn't matter; alphabetical (Caitlyn, Neeko,
Ornn, Reksai, Zoe) is fine.

Estimated surface: five new files, ~35 lines each, one `chore:` commit. No code
paths touched, no tests affected, no risk of working-tree collisions beyond the
commit itself.

## 6. Verification

After the wiring commit lands:

1. Confirm each file exists with `ls .claude/agents/{ornn,reksai,neeko,zoe,caitlyn}.md`.
2. Confirm frontmatter shape with a grep: each file should contain `model: sonnet`,
   a `tools:` line, and a `description:` line. Rule 15 compliance check.
3. Start a fresh top-level Claude Code session — Claude Code loads agent
   definitions on session start. In that session, ask Evelynn to list available
   subagent types; all five new names should appear.
4. Smoke test: have Evelynn spawn each one with a trivial no-op task that
   references a throwaway plan stub (e.g. "read your profile and report back").
   Confirm each agent loads its profile and returns a coherent in-character reply.
   This catches typos in the body text and missing profile paths.
5. Cross-check against `agents/roster.md` — every Sonnet entry should now have
   a corresponding `.claude/agents/<name>.md`. Any remaining gap is a bug in this
   plan.

Steps 1-2 are the minimum gate; 3-5 are strongly recommended but can happen in
the next natural session rather than blocking the commit.

## 7. Risks & open questions

**Risks (all low):**

- Typo in a profile path → agent fails to load on first spawn. Mitigation: the
  smoke test in §6 step 4.
- Description field too vague → Evelynn routes ambiguously. Mitigation: the
  explicit "do NOT invoke for X" clauses in §3. Can be tightened post-wiring
  if routing misfires appear.
- Zoe's "ephemeral scripting" scope is the fuzziest of the five. If Evelynn
  starts delegating real feature work to her because "it's just a script,"
  that's a routing failure, not a wiring failure — but the description should
  be aggressive about ephemerality to minimize the risk.
- Caitlyn and Reksai overlap on "find the bug." The split is: Reksai reproduces
  and writes the failing test (fast loop); Caitlyn goes deep when Reksai's fast
  loop has already failed. Document this split in their descriptions.

**Open questions for Duong:**

1. Should Caitlyn be read-only (drop Write/Edit)? Default in this plan: no, she
   gets the full set. Flip if you want harder scope enforcement.
2. Does `agents/memory/agent-network.md` need a routing-table update in the same
   pass, or is that a follow-up? Default: follow-up, to keep this plan tight.
3. Any of these five you'd rather not wire yet? (e.g. if Zoe's scope still feels
   undefined, we can drop her from the batch and ship four.)
4. Reksai's "post via `gh pr comment`" rule lives in user memory
   (`feedback_reksai_pr_comment`). Should it be promoted into Reksai's body text
   so it survives a memory reset? Recommend yes — inline it.
