---
decision_id: 2026-04-27-team-mode-it2-empirical-test
date: 2026-04-27
coordinator: evelynn
concern: personal
axes: [scope-vs-debt, explicit-vs-implicit]
question: How do we get TeamCreate working given the agent-team mandate plus the open Ink Box-in-Text crash (#52337) on sensitive-path edits?
options:
  a: empirically test it2 (install, set up iTerm2 split-pane, re-run a known-crashing Senna/Viktor team-mode dispatch); if it sidesteps the Ink crash, migrate; if not, file #52337 with our repro and adopt the architectural workaround (sensitive-path edits coordinator-only)
  b: file #52337 with our repro AND set up it2 in parallel — adopt whichever path unblocks first
  c: install it2 based on the docs alone, declare iTerm2 the default, accept that some agents may still crash and patch reactively
coordinator_pick: a
coordinator_confidence: medium
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

Duong re-affirmed the agent-team mandate (per duong.md §Agent Team mode, commit 1a7d9a06): TeamCreate is mandatory for any iterating coordinator work; falling back to standard background `Agent` dispatches is not acceptable. Our 2026-04-26 learning (`team-mode-ink-crash-and-tmux-fallback`) flagged team-mode as buggy under tmux — Senna and Viktor reliably crash on launch, Lucian-shape agents survive. Duong asked whether iTerm2 could be substituted for tmux. Two-pass research from claude-code-guide established: (1) iTerm2 is officially supported via the `it2` CLI wrapper alongside tmux; (2) issue #52337 is OPEN and unfixed in v2.1.119, identifying a JSX `<Box>` nested in `<Text>` violation in Ink, triggered by the sensitive-path Edit/Write confirmation dialog; (3) no env-var, settings.json key, or CLI flag exists to suppress the crash; (4) the documented workaround is to keep sensitive-path edits on the parent session. Pass 1 and pass 2 disagreed on whether iTerm2-via-it2 sidesteps the crash (renderer-level bug suggests no; the bolted-on architecture suggests it might still hit the same code path). Empirical test is the only way to know.

## Why this matters

Picking c (commit to it2 on docs alone) would be a hopeful migration that may leave the same crash in place under a new multiplexer — debt without resolution. Picking b (parallel two-track) burns coordinator attention authoring an upstream issue report against an unverified hypothesis. Picking a (empirical test first, then route) costs ~15 min of execution to get a definitive answer; it also surfaces the real correlation (sensitive-path-touching frequency vs prompt size — Senna/Viktor edit `.claude/` more than Lucian) which sharpens whichever follow-up plan we commission. Per learning 2026-04-18-empirical-before-ruling: the 5-min worktree test beats the yo-yo. Same pattern applies here.
