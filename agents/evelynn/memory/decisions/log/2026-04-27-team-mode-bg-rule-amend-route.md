---
decision_id: 2026-04-27-team-mode-bg-rule-amend-route
date: 2026-04-27
coordinator: evelynn
concern: personal
axes: [scope-vs-debt, explicit-vs-implicit]
question: How do we land the amendment to `#rule-background-subagents` (and its enforcing PreToolUse hook) so team-mode dispatches can run in foreground?
options:
  a: Karma quick-lane plan (rule prose + hook patch + regression test for both branches — one-shot still bg, team_name dispatch fg), Talon impl, Senna+Lucian review, merge full chain
  b: Karma + Talon collapsed; iTerm2 test runs in parallel via Duong launching a separate claude session manually
  c: Direct edit to rule + hook now under Duong-authorized bypass, retroactive Karma plan to lock in regression test
coordinator_pick: a
coordinator_confidence: medium
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

Foreground Agent dispatch with `team_name` set is the documented mechanism for adding a teammate to a Claude Code agent team. The local `#rule-background-subagents` rule (in agents/evelynn/CLAUDE.md and agents/sona/CLAUDE.md) blanket-mandates `run_in_background: true` for every Agent dispatch, and is enforced at runtime by a PreToolUse hook in .claude/settings.json. The rule was written before the agent-team mandate landed (duong.md §Agent Team mode, commit 1a7d9a06) and never got carved out for team_name dispatches. Today, the hook blocks any foreground Agent call — including the legitimate team-mode case where a teammate must spawn into a pane to participate in team orchestration. Discovered while attempting an empirical iTerm2 split-pane test.

## Why this matters

This is exactly the surgical-trap shape that learning 2026-04-25-gate-bypass-on-surgical-infra-commits captured: a small-feeling diff (one prose paragraph + one boolean tweak in a hook check) that has cross-process semantics (changes how the harness gates Agent-tool dispatches). The prior incident in that learning was an env-hygiene direct-edit that silently broke the inbox watcher; the current edit is structurally similar (PreToolUse gate amendment). Doctrine is to take the full quick-lane chain (Karma → Talon → Senna+Lucian) regardless of LOC, so the regression test lands in the same commit and we get the Lucian fidelity check + Senna code/security pass. Pick b parallelizes by punting the test to manual Duong execution, which works but transfers coordinator overhead to Duong and gives no win on calendar time. Pick c is the surgical-trap itself dressed up as urgency. Pick a costs ~45-60 min of clock time but pays it once and produces a regression test that prevents future drift.
