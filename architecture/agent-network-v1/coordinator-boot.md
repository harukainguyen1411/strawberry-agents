# Coordinator Boot — Architecture

> Related: [compact-workflow.md](compact-workflow.md) (SessionStart hook mechanics)

## Overview

All coordinator launches (Evelynn and Sona) run through a single canonical
boot script: `scripts/coordinator-boot.sh`. This eliminates asymmetric wiring,
removes hardcoded identity fallbacks, and makes the boot sequence deterministic.

Implemented by plan `plans/in-progress/personal/2026-04-24-coordinator-boot-unification.md`.

## Invariants

| ID | Invariant |
|----|-----------|
| INV-1 | Identical boot sequence — Evelynn and Sona differ only in coordinator name, concern tag, and memory path prefix. No asymmetric hook wiring. |
| INV-2 | Deterministic resume detection — exactly one signal decides "resumed": the SessionStart hook payload `.source` field. Default on ambiguity is **fresh** (re-read everything). |
| INV-3 | Monitor arming is visible — if the inbox watcher is not armed, the PreToolUse gate emits `INBOX WATCHER NOT ARMED` on every subsequent tool call. |
| INV-4 | Identity always exported explicitly — every launcher sets `CLAUDE_AGENT_NAME`, `STRAWBERRY_AGENT`, and `STRAWBERRY_CONCERN` before `claude` spawns. No launcher relies on `.claude/settings.json .agent` as an identity source. |
| INV-5 | Single shared boot script — `scripts/coordinator-boot.sh` is the canonical boot surface. Launchers invoke it or mirror its identity exports; they do not re-implement boot logic. |
| INV-6 | Fail-loud on identity mismatch — if coordinator identity is unresolvable from env vars, hooks emit a visible diagnostic rather than silently falling back to a hardcoded default. |

## Boot Flow

```
user runs alias / launcher
       |
       v
scripts/coordinator-boot.sh <Evelynn|Sona>
  ├─ validate arg (whitelist: Evelynn, Sona)
  ├─ export CLAUDE_AGENT_NAME=<Name>
  ├─ export STRAWBERRY_AGENT=<Name>
  ├─ export STRAWBERRY_CONCERN=<personal|work>
  ├─ cd to repo root
  ├─ bash scripts/memory-consolidate.sh <name>
  └─ exec claude --agent <Name>
         |
         v
  SessionStart hooks fire (from .claude/settings.json):
    1. Resume detection: read .source field → if resume/clear/compact, inject RESUMED message
    2. inbox-watch-bootstrap.sh → if fresh start, emit Monitor-arm nudge
         |
         v
  PreToolUse gate (pretooluse-monitor-arming-gate.sh):
    - sentinel /tmp/claude-monitor-armed-${CLAUDE_SESSION_ID} present → silent no-op
    - sentinel absent + CLAUDE_AGENT_NAME ∈ {Evelynn,Sona} → emit NOT ARMED warning
```

## Identity Resolution

Identity is established at the process level before Claude Code starts, so hooks
always have a reliable env var to read:

```
Priority order (highest first):
  1. CLAUDE_AGENT_NAME (set by coordinator-boot.sh or launcher)
  2. STRAWBERRY_AGENT  (mirror — set by same scripts)
  3. FAIL LOUD         (no silent fallback to .agent field)
```

The `.claude/settings.json .agent` field is NOT used as an identity source by
any hook. It is kept for potential framework compatibility reasons but is
decorative from the boot system's perspective.

## Launcher Inventory

| Platform | File | Env vars set |
|----------|------|--------------|
| macOS alias (Evelynn) | `scripts/mac/aliases.sh` alias `evelynn` | via coordinator-boot.sh |
| macOS alias (Sona) | `scripts/mac/aliases.sh` alias `sona` | via coordinator-boot.sh |
| macOS iTerm (Evelynn) | `scripts/mac/launch-evelynn.sh` | exported directly + exec claude |
| macOS iTerm (Sona) | `scripts/mac/launch-sona.sh` | exported directly + exec claude |
| Windows PS (Evelynn) | `scripts/windows/launch-evelynn.ps1` | `$env:CLAUDE_AGENT_NAME` etc. |
| Windows PS (Sona) | `scripts/windows/launch-sona.ps1` | `$env:CLAUDE_AGENT_NAME` etc. |
| Windows bat (Evelynn) | `scripts/windows/launch-evelynn.bat` | `set CLAUDE_AGENT_NAME` etc. |
| Windows bat (Sona) | `scripts/windows/launch-sona.bat` | `set CLAUDE_AGENT_NAME` etc. |

## Resume Detection

Signal A (deterministic, framework-level) lives in `.claude/settings.json`
SessionStart hook:

```bash
jq -r '.source' | { read -r src;
  if [ "$src" = "resume" ] || [ "$src" = "clear" ] || [ "$src" = "compact" ]; then
    echo '{"systemMessage":"Resumed session — skipping startup reads.",...}'
  fi
}
```

Signal B (heuristic, model-level) has been REMOVED from both agent
`initialPrompt` fields. The opening paragraph that said "if this is a resumed
session ... skip the reads" is gone. The model now defers entirely to Signal A.

## Monitor Arming Gate

`scripts/hooks/pretooluse-monitor-arming-gate.sh` runs on every PreToolUse:

- Reads `CLAUDE_SESSION_ID` to form a per-session sentinel path.
- If sentinel `/tmp/claude-monitor-armed-${CLAUDE_SESSION_ID}` is present: no-op.
- If absent AND `CLAUDE_AGENT_NAME` is Evelynn or Sona: emit warning JSON.
- If absent AND agent is not a coordinator: no-op (subagents have no inbox watcher).

`scripts/hooks/posttooluse-monitor-arm-sentinel.sh` creates the sentinel when the
Monitor tool is invoked with `scripts/hooks/inbox-watch.sh`.

## Failure Modes

| Failure | Symptom | Mitigation |
|---------|---------|------------|
| `coordinator-boot.sh BadName` | exits 2, stderr message | whitelist guard in boot script |
| Neither env var set in hook | stderr diagnostic, empty stdout | INV-6 fail-loud in inbox-watch.sh |
| Monitor not armed | `INBOX WATCHER NOT ARMED` on every PreToolUse | sentinel-based gate (INV-3) |
| Resumed session re-reads files | impossible: only Signal A decides | Signal B removed (INV-2) |
