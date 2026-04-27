# Team-mode React Ink startup crash and tmux fallback

**Date:** 2026-04-26
**Session:** 9c8170e8-221a-4350-97cb-aad8c9907db1 (Leg 6)
**Topic:** Team-mode subagent infrastructure — platform prerequisites and agent-shape survivability

## What happened

Attempted team-mode dispatch (`TeamCreate`, team `phase2-fanout`) to run four parallel subagents. Prerequisites:
- `it2` CLI gap: `asdf reshim` + `~/.local/bin` symlink resolved the PATH issue.
- `tmux` gap: `brew install tmux` (v3.6a) was required as the team-mode fallback terminal.

After setup, four agents dispatched: senna-pr89, senna-pr93, senna-pr93-2, lucian-pr93. Lucian survived and returned a full review. All three Senna dispatches crashed at startup with:

```
Error at cli.js:484 — truncate widget (React Ink renderer)
```

Pattern confirmed across multiple re-dispatches: agents with longer system prompts (Senna, Viktor) crash; agents with shorter system prompts (Lucian, Lucian-shaped tasks) survive.

## Lessons

1. **Team-mode requires `it2` CLI or `tmux`** — install `tmux` via `brew install tmux` before team-mode use. The `it2` path (iTerm2 dependency) is fragile on machines without iTerm2 sourced PATH.

2. **React Ink truncate-widget crash is agent-prompt-size correlated** — this is a framework-side bug, not a task-complexity issue. Longer system prompts hit the crash. Viktor and Senna are reliably affected. Lucian-shape agents (shorter prompt) survive.

3. **Workaround: standard Agent tool, not team mode** — until the Ink crash is fixed upstream, dispatch reviewers and implementers via standard `Agent` tool with `run_in_background: true`. Reserve team mode for Lucian-shaped agents only if team coordination value is high.

4. **Team member cleanup via jq** — dead team members should be removed from `~/.claude/teams/<name>/config.json` via `jq 'del(.members[] | select(.id == "dead-id"))'` after crashes; the team config persists between sessions.

## When to apply

Before any team-mode dispatch: (a) verify `tmux` installed, (b) estimate system-prompt length for each agent, (c) prefer standard Agent dispatch for Senna/Viktor until upstream Ink fix confirmed.
