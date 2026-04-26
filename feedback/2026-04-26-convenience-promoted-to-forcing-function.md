---
date: 2026-04-26
time: "09:00"
author: evelynn
concern: personal
category: hook-friction
severity: high
friction_cost_minutes: 240
agents_implicated: [azir, talon, karma, evelynn, orianna, senna, lucian]
session: 92718db2
related_plans:
  - plans/implemented/personal/2026-04-20-strawberry-inbox-channel.md
  - plans/implemented/personal/2026-04-24-coordinator-boot-unification.md
  - plans/approved/personal/2026-04-26-monitor-arming-gate-bugfixes.md
related_commits:
  - 9ee2f2e0  # 2026-04-22 inbox watcher v3 introduced
  - 9369de37  # 2026-04-24 PR #39 added the Monitor gate hook
  - cd20732b  # 2026-04-26 hooks removed from settings.json (Duong directive)
state: open
---

# Convenience tool promoted to forcing function — review chain failed to catch

## What Duong asked for

A convenience: an inbox watcher so coordinators (Evelynn, Sona) wouldn't need
verbal reminders to read their inbox each session. Fire-and-forget messaging
between agents, background watcher, model-invocable.

## What got built

The convenience (2026-04-20, plan owner: Azir) shipped reasonably as
`strawberry-inbox-channel`.

Four days later (2026-04-24), Azir authored `coordinator-boot-unification.md`
which added a **PreToolUse hook gate** that blocked every tool call until the
coordinator armed the watcher. The hook had no `matcher` scoping, so it fired
before Read, Edit, Write, Bash, Agent — every tool. The convenience became
a hard discipline-enforcer: "you cannot do anything else until you start the
watcher."

Three latent bugs accumulated in the gate over the next two days:
- Env-var leak: subagents inherited `CLAUDE_AGENT_NAME` and got blocked
- `CLAUDE_SESSION_ID` unset post-`/compact` orphaned the session-keyed sentinel
- `$$` per-process key meant the three hook scripts (gate, bootstrap, posttooluse)
  computed three different non-tty fallback keys that never matched

By 2026-04-26 the cumulative friction (subagent dispatch failures, post-compact
broken state, every-tool-call latency, debugging multi-round PR fixes) consumed
most of Duong's Sunday morning. He removed the gate entirely.

## The review chain that didn't catch it

| Step | Agent | What they checked | What they missed |
|------|-------|-------------------|------------------|
| Plan author | Azir | Design, tasks, DoD | That this was a forcing function on a convenience feature |
| Plan promotion gate | Orianna | Owner, no TBDs, simplicity scan | That a PreToolUse hook with no matcher fires on every tool |
| Implementation | Talon | Build matches plan | (not their lane) |
| PR review (code) | Senna | Code quality, security | (not their lane) |
| PR review (fidelity) | Lucian | Implementation matches plan | (not their lane) |
| Coordinator intake | Evelynn (me) | Forwarded plan to Orianna | Did not interrogate design before promotion |
| Final merge | Duong | Trusted the chain | — |

Each downstream step assumed the previous step validated the design. The plan
itself was never interrogated for "is this the right shape of thing?" Azir's
seniority as head architect created authority deference — downstream agents
treated his plan as authoritative because of his role.

## Specific design slips that went unchallenged

- Hook had **no `matcher`** field — fired on every PreToolUse event including
  Read/Edit/Write, not just Bash where the watcher arming actually mattered
- The condition being enforced ("coordinator should arm watcher") is a
  **convenience reminder**, not an invariant whose violation breaks the system
- Identity resolution depended on `CLAUDE_AGENT_NAME` env var, which **leaks
  to subagents** — a known Unix-process semantics issue
- Cross-hook coordination used `$$` (per-process) where it should have used
  `${PPID}` (parent shell, stable across hook subprocesses) — basic POSIX
  shell knowledge that wasn't in the design
- State assumed `/tmp` survives `/compact`, which it does, but `CLAUDE_SESSION_ID`
  semantics post-compact were not designed for

## Cost

Approximately 4 hours of Duong's Sunday morning, plus accumulated multi-session
friction since 2026-04-24 (every coordinator session paid latency cost on every
tool call; multiple subagent dispatches were blocked or required workarounds).
Net negative versus the value of the original convenience.

## Status

Hooks removed from `.claude/settings.json` at commit `cd20732b`. PR #73 (which
was attempting to fix bugs in the now-removed gate) is moot. Hook scripts
themselves remain on main as dead code.

Duong is researching the structural fix; this entry is the record of the
problem only.

## What went wrong

A convenience feature (inbox watcher bootstrap) was promoted into a forcing
function via a PreToolUse hook that fired on every tool call (Read, Edit,
Write, Bash, Agent). The hook had no `matcher` scoping. It accumulated three
latent bugs (env-var leak to subagents, CLAUDE_SESSION_ID unset post-compact,
`$$`-per-process key mismatch across hook subprocesses) over the course of
4 days, eventually consuming ~4 hours of Duong's Sunday morning before he
removed the gate entirely at commit cd20732b.

## Suggestion

Two structural rules to consider:
1. PreToolUse hooks that enforce a "convenience reminder" (not a hard invariant)
   should carry a `matcher` that scopes them narrowly — or should not be hooks
   at all (a boot-chain suggestion surfaced via plan/startup, not a gate).
2. When a PR adds a PreToolUse hook with no `matcher` field, Senna/Lucian code
   review should flag it as a design question: is this enforcing an invariant
   whose violation breaks the system, or a reminder? If reminder, recommend
   removing the hook.

## Why I'm writing this now

Duong removed the gate this morning (2026-04-26) and the cleanup task is
in-flight. This entry exists so the pattern is captured before the scripts
are deleted — a future Orianna gate or hook design can reference it.
