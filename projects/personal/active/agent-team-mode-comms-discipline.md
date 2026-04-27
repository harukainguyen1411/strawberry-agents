---
slug: agent-team-mode-comms-discipline
status: active
concern: personal
scope: [personal, work]
owner: duong
created: 2026-04-27
deadline: TBD (research-bounded)
claude_budget: moderate
tools_budget: limited
risk: moderate
user: duong-only
focus_on:
  - the lead always sees what the teammate said
  - shutdown requests always converge to a clean teardown
  - teammates can talk to each other when that is the right shape, not only through the lead
  - the right communication pattern is the path of least resistance
less_focus_on:
  - replacing the team mode mechanic itself
  - tmux backend (in-process is current default)
related_plans: []
---

## Goal

When Duong is running a team — a lead coordinator and one or more teammates — he wants the
work to converge without him having to read the teammates' terminals. Today it does not. A
teammate often answers by writing into its own terminal (only Duong sees), and the lead is
left blind, pinging into the void. Shutdown requests get ignored or silently dropped. The
team stalls; Duong becomes the relay he was trying to avoid.

He wants the Agent Team feature to feel like a real team: the lead asks, the teammate
answers in a way the lead receives; teammates that have something to say to each other can
say it directly when that is the right shape; everyone shuts down cleanly when the work is
done. The feature exists; the discipline around it does not yet.

## Definition of Done

- Duong can spin up a team, give the lead one task, and walk away. No terminal-watching, no
  manual relay. Whatever the teammates produce reaches the lead, and the lead drives to a
  conclusion.
- A `shutdown_request` from the lead converges to a clean teardown every time. No silent
  drops, no orphaned `isActive: true` flags blocking the next `TeamDelete`.
- When two teammates need to coordinate something the lead does not need to mediate, they
  can — and the runbook says clearly when that is appropriate vs when it must hub through
  the lead.
- The "right" communication shape is the easy one. A teammate or lead doing the wrong thing
  feels like swimming upstream, not the default.
- The shipped guidance has been demonstrated end-to-end on a real team in this repo, not
  just argued for in prose.

## Constraints

- Three Evelynn sessions and two Sona sessions are running concurrently in this repo. The
  work touching shared agent definitions and the runbook itself must coordinate with them
  before editing.
- The deadline is research-bounded — done when the DoD is met, not on a calendar.
- Must continue to honour the existing teammate-default mandate
  (`#rule-background-subagents`). This project hardens that mandate; it does not relax it.
- Moderate Claude budget, limited tools budget. Empirical probes are preferred where they
  give faster ground truth than reading more docs.

## Decisions

_(Running log — appended as project-level binding decisions are made.)_

- 2026-04-27 — project framing: full graph in scope (lead↔teammate AND teammate↔teammate),
  research includes Anthropic docs + Claude Code source/issues + empirical probes, output
  lands via Karma quick-lane plan + Talon impl + dual review.
- 2026-04-27 — SendMessage as the exclusive channel for substantive teammate output; terminal
  output is acknowledged as a user-only side channel and is never load-bearing for the lead.
  Enforcement direction: agent-def rule + a detection mechanism (shape TBD by the plan).
- 2026-04-27 — tmux substrate is a footnote with the existing escape hatch; in-process is the
  documented default. The plan does not actively engineer tmux-death recovery.
- 2026-04-27 — every inbound task and every `shutdown_request` requires a typed
  completion-marker SendMessage reply from the teammate. Idle-without-marker is a runbook
  violation; the lead has a structural detection-and-escalation path. This convention also
  fixes the stale-task-already-done pattern (a teammate that completed prior work cannot
  silently swallow a late-arriving task — it must reply with the marker referencing the new
  task ID).

## Out of scope

- Replacing the Agent Team feature with a different multi-agent substrate.
- The tmux backend except as a footnote (in-process is the current default).
- The plan-author-worktree-reaped class of bug.
- Application-side messaging surfaces (Slack, Discord, inbox).
