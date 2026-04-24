---
date: 2026-04-24
owner: azir
concern: personal
status: approved
complexity: normal
topic: coordinator-boot-unification
supersedes: []
---

# Coordinator Boot Unification (Evelynn + Sona)

## 1. Problem

Duong reports — across two consecutive days on Evelynn (launched via the
`evelynn` zsh alias), and less severely on Sona — three recurrent boot-time
failures:

1. **False-positive "resumed" detection.** A fresh session is frequently
   treated as resumed. The SessionStart hook injects
   `RESUMED SESSION — do not re-read startup files. Reply only: Session
   resumed.`, the model takes that branch, and the whole startup chain
   (coordinator CLAUDE.md re-read, memory load, open-threads, inbox scan)
   is skipped.

2. **`Monitor` tool never armed.** The inbox watcher exists
   (`scripts/hooks/inbox-watch.sh`) and a SessionStart hook emits a
   `hookSpecificOutput.additionalContext` nudge telling the coordinator to
   invoke the Monitor tool on its first action — but arming is an
   instruction to the model, not a gated step, so it gets skipped the
   moment anything else is on the coordinator's plate (which is always).

3. **Inbox watcher mis-scopes.** Sona's session watches Evelynn's inbox.
   Root cause: neither zsh alias exports a coordinator identity env var.
   `scripts/hooks/inbox-watch-bootstrap.sh` and `inbox-watch.sh` both
   resolve identity as
   `CLAUDE_AGENT_NAME → STRAWBERRY_AGENT → .claude/settings.json .agent`,
   and the last field is hard-coded to `"Evelynn"`. Evelynn appears to
   boot correctly only by coincidence — she matches the hardcoded
   default. Sona silently binds to Evelynn's inbox.

This plan unifies the boot so Evelynn and Sona have identical,
deterministic, robust startup every time.

## 2. Root-Cause Analysis

### Symptom 1 — false "resumed" detection

Two independent resume signals, neither deterministic:

**Signal A — framework-level (SessionStart hook).**
`.claude/settings.json` SessionStart hook at lines 42–47:

```
jq -r '.source' | { read -r src; if [ "$src" = "resume" ] || [ "$src" = "clear" ] || [ "$src" = "compact" ]; then
  echo '{"systemMessage":"Resumed session — skipping startup reads.",...
         "additionalContext":"RESUMED SESSION — do not re-read startup files. Reply only: Session resumed."}}';
fi; }
```

This is actually deterministic (it reads `.source` from the hook payload,
which Claude Code sets to `"startup"` / `"resume"` / `"clear"` /
`"compact"`). If this were the only signal, symptom 1 would not occur.

**Signal B — model-level (initialPrompt).**
Both `.claude/agents/evelynn.md` and `.claude/agents/sona.md`
`initialPrompt` open with:

> "If this is a resumed session (you already have prior conversation
> history above this message), skip the file reads entirely and just
> reply with 'Session resumed.' — nothing else."

This is a heuristic judgement the model makes. It is the real source of
the flake: when the model sees a long context window (injected hook
messages, system preamble, MCP instructions, compaction noise, etc.) on
a fresh launch, it can mis-classify and take the "resumed" branch
despite `.source == "startup"`.

**Pathology:** two resume signals, one deterministic (Signal A) and one
heuristic (Signal B), wired in parallel. Signal B overrides Signal A
because the model acts on whichever fires first in its reasoning. When
Signal A correctly says "fresh" but Signal B says "resumed", the model
follows B.

### Symptom 2 — Monitor never armed

`scripts/hooks/inbox-watch-bootstrap.sh` emits a `systemMessage` /
`additionalContext` string telling the coordinator:

> "INBOX WATCHER: invoke the Monitor tool on your first action with:
>   command: bash scripts/hooks/inbox-watch.sh..."

This is a request, not a requirement. The coordinator complies only if
it chooses to, and it routinely does not when Duong's opening message
contains any time-sensitive task. Arming Monitor is not a gated step in
the boot sequence; it is a nudge in free-form text.

### Symptom 3 — inbox mis-scope on Sona

- `scripts/mac/aliases.sh` defines `sona='cd ~/... && claude --agent Sona'`
  and `evelynn='cd ~/... && claude --agent Evelynn'`. Neither alias
  exports `CLAUDE_AGENT_NAME` or `STRAWBERRY_AGENT`.
- The `--agent` CLI flag does not (in current Claude Code) export a
  process env var visible to SessionStart hooks.
- Identity resolution chain falls through to `.claude/settings.json
  .agent == "Evelynn"` (line 166), a hardcoded default.
- Result: every non-Evelynn coordinator binds to Evelynn's inbox via
  silent fallback.
- Evelynn "working" is a coincidence, not a correctness property: the
  hardcoded default happens to match.

**This is the single most dangerous issue in the three**, because it is
silent and survives all other fixes.

## 3. Invariants

The fix preserves or establishes the following invariants.

- **INV-1 — Identical boot sequence.** Evelynn's and Sona's startup
  chains must be byte-identical except for (a) the coordinator-specific
  CLAUDE.md path, (b) the `concern` tag, (c) the agent name. No
  asymmetric hook wiring, no duplicated code paths, no drift surface.

- **INV-2 — Deterministic resume detection.** Exactly one signal decides
  "is this a resumed session?", and it is framework-level (the hook
  payload's `.source` field), not a model-level judgement. If the signal
  is ambiguous or missing, default **fresh** (re-read everything). It is
  always cheaper to re-read than to miss memory.

- **INV-3 — Monitor arming is a gated step.** The inbox watcher must be
  armed as part of the boot sequence, not a nudge the model can skip.
  Failure to arm must be visible — either the session fails to proceed,
  or the session logs a clear "INBOX WATCHER NOT ARMED" warning on every
  tool call until it is armed.

- **INV-4 — Identity always exported explicitly.** Every coordinator
  launch path (zsh alias, `scripts/mac/launch-evelynn.sh`, Windows
  equivalents, iTerm launcher, and any future launcher) MUST export
  `CLAUDE_AGENT_NAME=<Evelynn|Sona>` before `claude` spawns. No
  launcher may rely on `.claude/settings.json .agent` as an identity
  source. The hardcoded default is removed (or repurposed — see §5).

- **INV-5 — Single shared boot script.** One script under `scripts/`
  is the canonical boot surface for all coordinators. Launchers source
  it or invoke it; they do not re-implement boot logic. Coordinator
  differences are parameterised (coordinator name, concern), not
  duplicated.

- **INV-6 — Fail-loud on identity mismatch.** If
  `CLAUDE_AGENT_NAME` is set and does not match the agent the hook is
  about to act on (e.g. Monitor arming, inbox scoping), the hook emits a
  loud warning into `additionalContext`. Silent fallback is prohibited
  for coordinator identity — it is the failure mode we are removing.

## 4. Design

### 4.1 Shape

The fix is shell + env vars + the existing hook system. No new agent,
no new hook framework, no config DSL.

Four concrete surfaces change:

1. **Zsh aliases** (`scripts/mac/aliases.sh`) — export identity before
   `claude` runs.
2. **Shared boot script** (`scripts/coordinator-boot.sh`, new) — one
   function, sourced by both aliases and launchers.
3. **SessionStart hook** (`.claude/settings.json`) — keep the
   framework-level deterministic resume check; remove the model-level
   heuristic from `initialPrompt`.
4. **Identity resolution hardening** — remove the hardcoded
   `.claude/settings.json .agent` fallback from both inbox scripts;
   add fail-loud warnings.

### 4.2 File-level changes

#### A. `scripts/coordinator-boot.sh` (new)

A POSIX-portable bash script, source-able. Responsibilities:

```
#!/usr/bin/env bash
# coordinator-boot.sh — single canonical boot path for Evelynn and Sona.
# Usage:
#   source scripts/coordinator-boot.sh Evelynn
#   source scripts/coordinator-boot.sh Sona
# Exports:
#   CLAUDE_AGENT_NAME      (canonical case: Evelynn | Sona)
#   STRAWBERRY_AGENT       (mirror, for older hooks)
#   STRAWBERRY_CONCERN     (personal | work)
# Runs:
#   cd to repo root
#   bash scripts/memory-consolidate.sh <name>   (per existing initialPrompt)
#   exec claude --agent <name>
```

Key properties:
- Validates the coordinator argument against a whitelist (`Evelynn`,
  `Sona`) — unknown value aborts with exit 2.
- Exports env vars before `exec claude`.
- Runs the memory-consolidate step once, deterministically, from shell
  rather than from `initialPrompt` (removes another source of model-
  decided flakiness).

#### B. `scripts/mac/aliases.sh` (modify)

```
alias evelynn='bash ~/Documents/Personal/strawberry-agents/scripts/coordinator-boot.sh Evelynn'
alias sona='bash    ~/Documents/Personal/strawberry-agents/scripts/coordinator-boot.sh Sona'
```

Windows equivalents (`scripts/windows/launch-evelynn.ps1`,
`launch-evelynn.bat`) set `$env:CLAUDE_AGENT_NAME = 'Evelynn'` etc.
before invoking `claude`.

#### C. `.claude/settings.json` (modify)

Two edits:

1. **Resume detection stays framework-level.** Keep the existing
   SessionStart hook that reads `.source`. This is already correct and
   deterministic.

2. **Remove `.agent` field.** Drop line 166 (`"agent": "Evelynn"`) from
   `.claude/settings.json`. This was the hardcoded default that made
   Sona's mis-scope silent. With INV-4, identity must come from env
   vars. If neither env var is set, identity resolution fails loud
   (INV-6).

   *Note:* because `.claude/settings.json` is a Claude Code–consumed
   file, verify removing `.agent` does not break framework features;
   if the framework requires it, keep the field but change hooks to
   ignore it for coordinator identity purposes.

#### D. `.claude/agents/evelynn.md` and `.claude/agents/sona.md` (modify)

**Remove Signal B** (model-level resume heuristic). Replace the opening
paragraph of `initialPrompt` with:

```
Read the following files in order. Do not short-circuit on presumed
"resume" — the SessionStart hook has already decided that. If the
hook injected "RESUMED SESSION ...", skip the reads. Otherwise read
the full chain.
```

This keeps behaviour on resume identical (the hook wins) and
eliminates the model's freelance resume judgement.

Also move the `memory-consolidate.sh` invocation out of `initialPrompt`
into `coordinator-boot.sh` (§4.2.A). `initialPrompt` becomes pure file
reads — smaller, more reliable.

#### E. `scripts/hooks/inbox-watch.sh` (modify — identity hardening)

Replace the current three-step chain with two steps only:

```
coord=""
if [ -n "${CLAUDE_AGENT_NAME:-}" ]; then
  coord="$(printf '%s' "$CLAUDE_AGENT_NAME" | tr '[:upper:]' '[:lower:]')"
elif [ -n "${STRAWBERRY_AGENT:-}" ]; then
  coord="$(printf '%s' "$STRAWBERRY_AGENT" | tr '[:upper:]' '[:lower:]')"
fi
if [ -z "$coord" ]; then
  # Fail-loud instead of silent fallback
  printf 'inbox-watch: no CLAUDE_AGENT_NAME or STRAWBERRY_AGENT set; refusing to default\n' >&2
  exit 0  # stdout empty — Monitor sees nothing — coordinator notices
fi
```

Drop the `.claude/settings.json .agent` fallback entirely.

#### F. `scripts/hooks/inbox-watch-bootstrap.sh` (modify — same treatment)

Same identity resolution simplification. **Also change the Monitor
nudge** from free-form `additionalContext` text to a direct,
unambiguous, imperative instruction delivered as the session's *very
first* `additionalContext` block, and add a follow-up gate (§4.2.G).

#### G. Monitor arming gate (new behaviour, implemented via hook)

Add a lightweight PreToolUse hook (matcher: any tool, first N
invocations) that:

1. Checks a session-scoped sentinel at
   `/tmp/claude-monitor-armed-${CLAUDE_SESSION_ID}`.
2. If absent and this is the N-th tool call without arming, emits
   `systemMessage: "INBOX WATCHER NOT ARMED — invoke Monitor with bash
   scripts/hooks/inbox-watch.sh now."` on every subsequent tool call.
3. The SubagentStart/Monitor-start hook creates the sentinel when the
   Monitor tool is invoked with the inbox-watch command.

This satisfies INV-3: arming becomes visible. The session does not hard
fail, but the warning surface makes the omission impossible to ignore.

Implementation note: the PreToolUse warning path is cheap (single
`[ -f ... ]` check) and is a no-op once the sentinel exists.

**Scope callout:** the sentinel check only fires on the coordinator
(CLAUDE_AGENT_NAME ∈ {Evelynn, Sona}). Subagents have no inbox watcher
requirement and must not trigger the warning.

### 4.3 What is NOT changing

- No new agent.
- No new hook framework or config DSL.
- `.claude/agents/_shared/` is not touched; existing _shared content is
  per-role (architect, coordinator) rather than per-boot.
- `scripts/memory-consolidate.sh` keeps its current shape.
- Inbox *content* protocol is unchanged.
- Orianna and plan-lifecycle guards are unchanged.

## 5. Migration / Rollout

1. Author `scripts/coordinator-boot.sh` (POSIX-portable).
2. Update `scripts/mac/aliases.sh`. Duong re-sources `~/.zshrc` once.
3. Update Windows launchers (`scripts/windows/launch-evelynn.ps1` /
   `.bat`) to export `CLAUDE_AGENT_NAME` before `claude`.
4. Update `.claude/agents/evelynn.md` and `.claude/agents/sona.md`
   `initialPrompt` to remove Signal B.
5. Update `scripts/hooks/inbox-watch.sh` and
   `scripts/hooks/inbox-watch-bootstrap.sh` to drop `.agent`-field
   fallback and fail loud.
6. Remove `"agent": "Evelynn"` from `.claude/settings.json` (subject to
   framework compatibility — see §4.2.C note). If framework requires
   the field, leave it but add a prominent code comment that it is
   decorative and ignored by boot hooks.
7. Wire the Monitor-arming PreToolUse gate.
8. Verification runs — see §6.

No migration of existing data/files required. No plan lifecycle moves.
No plan-fidelity risk.

## 6. Acceptance Criteria

All must hold:

- **AC-1** Fresh launch of `evelynn` (via zsh alias) reads the full
  startup chain 5/5 times in a row.
- **AC-2** Fresh launch of `sona` (via zsh alias) reads the full
  Sona-specific startup chain 5/5 times in a row and binds to Sona's
  inbox.
- **AC-3** Resumed launch (`claude --continue` or Claude Code's
  resume flow) correctly short-circuits to `"Session resumed."` 5/5
  times. No false negatives (resumed session re-reading and blowing
  context budget).
- **AC-4** Running `env | grep CLAUDE_AGENT_NAME` in a spawned
  coordinator shows the correct name for both coordinators.
- **AC-5** Running `bash scripts/hooks/inbox-watch.sh` in a Sona
  session (with `CLAUDE_AGENT_NAME=Sona`) emits only Sona-inbox
  pending-message lines. Same for Evelynn.
- **AC-6** Unsetting both env vars and running
  `bash scripts/hooks/inbox-watch.sh` produces a stderr diagnostic and
  exits 0 with empty stdout — no silent fallback to Evelynn.
- **AC-7** Fresh coordinator session with Monitor NOT armed emits the
  "INBOX WATCHER NOT ARMED" warning on the second tool call. Arming
  Monitor with the inbox-watch command causes the warning to stop.
- **AC-8** Evelynn and Sona `.claude/agents/*.md` `initialPrompt`
  differ ONLY in three fields: agent name, concern, memory path prefix.
  A diff tool (`diff evelynn.md sona.md`) should highlight only those
  tokens.

## 7. Open Questions

- **OQ-1.** Does Claude Code require `.claude/settings.json .agent`
  for its own behaviour (e.g. CLI `--agent` default, hook identity
  surface)? If yes, we leave it and add a code comment; if no, we
  delete it. Answer requires a 60-second framework-behaviour probe —
  the plan breaks down (Kayn) should include it as a pre-task.

  *Recommended default:* leave the field, change the hooks to ignore
  it. Safer, reversible, zero framework risk.

OQ-1 is the only genuine fork. All other decisions were made in §4.

**OQ-1 resolution (Evelynn, 2026-04-24):** Accept Azir's recommended default. Leave the `.agent` field in `.claude/settings.json` for framework-compatibility safety, but hard-gate the hooks to ignore it as an identity source (INV-4 still holds — identity MUST come from env vars). Kayn's breakdown should include a preamble subtask that probes whether Claude Code reads the field (60-second check); if the probe shows the framework does NOT read it, a follow-up task to delete the field can be added, but is out of scope for this plan. This keeps the change reversible and avoids framework coupling we can't cheaply verify.

**Simplicity note (Evelynn, 2026-04-24):** §4.2.G describes the Monitor-arming gate with an "N-th tool call" counter — that adds session state we don't need. Kayn's breakdown should simplify to "emit the INBOX WATCHER NOT ARMED warning on every PreToolUse until the sentinel exists" (no counter, stateless check, no-op once armed — as Azir himself hints). This is a breakdown-level tightening, not a plan revision.

## 8. References

- `.claude/settings.json` — SessionStart hook, `agent` field.
- `.claude/agents/evelynn.md`, `.claude/agents/sona.md` — `initialPrompt`.
- `scripts/hooks/inbox-watch.sh` — inbox watcher (Monitor target).
- `scripts/hooks/inbox-watch-bootstrap.sh` — SessionStart bootstrap.
- `scripts/mac/aliases.sh` — zsh aliases.
- `scripts/mac/launch-evelynn.sh` — mac iTerm launcher.
- `scripts/windows/launch-evelynn.ps1`, `launch-evelynn.bat` — Windows.
- Repo-root `CLAUDE.md` — rule 10 (POSIX-portable bash).
- `architecture/compact-workflow.md` — related SessionStart behaviour.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear owner (Azir), a coherent problem statement with root-cause analysis, six named invariants, eight testable acceptance criteria, and file-level design for seven concrete surfaces (A–G). The single open question (OQ-1) was resolved inline with the safer reversible default — keep the `.agent` field, gate hooks to ignore it. The plan itself flags §4.2.G's tool-call-counter as overengineered and defers the simplification to Kayn's breakdown, which is the right seam. Approved for promotion to `plans/approved/personal/`.
