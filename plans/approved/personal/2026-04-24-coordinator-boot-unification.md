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

## Tasks

Breakdown owner: Kayn, 2026-04-24. Three-commit split mandated by Evelynn (Rule 12, infra-safety):

- **C1** — additive launcher/boot-script work (T1–T9). No behaviour flip.
- **C2** — xfail tests covering INV-1..INV-6 + AC-1..AC-8 (T10–T16). Must fail against current state and land BEFORE C3.
- **C3** — behaviour flip: hook identity hardening, Signal B removal, Monitor-arming gate wiring (T17–T24).

Preamble (T0) runs before C1; its outcome gates an optional follow-up (T23) but does NOT gate any invariant.

Tasks tagged `[TOP-LEVEL]` touch coordinator write surfaces (`.claude/agents/evelynn.md`, `.claude/agents/sona.md`, `.claude/settings.json`) — implementer must flag back to Evelynn before committing.

### P0 — Preamble probe (pre-C1, gates only T23)

- [ ] **T0** — 60-second framework-behaviour probe: does Claude Code read `.claude/settings.json .agent`? Launch a disposable session with the field set to a unique sentinel string (e.g. `"ProbeSentinel"`), grep the SessionStart hook payload JSON and `CLAUDE_CODE_AGENT` env for the sentinel, record result in `assessments/probes/2026-04-24-settings-agent-field-probe.md`. Determines whether T23 is in scope. estimate_minutes: 10. Files: `assessments/probes/2026-04-24-settings-agent-field-probe.md` (new). DoD: probe note committed with explicit YES/NO verdict and evidence snippet; the field is NOT modified by this task.

### C1 — Additive launcher & boot-script work (no behaviour flip)

- [ ] **T1** — Author `scripts/coordinator-boot.sh` (POSIX-portable bash). Validate coordinator arg against whitelist (`Evelynn`|`Sona`); export `CLAUDE_AGENT_NAME`, `STRAWBERRY_AGENT`, `STRAWBERRY_CONCERN` (personal for Evelynn, work for Sona); `cd` to repo root; run `bash scripts/memory-consolidate.sh <name>`; `exec claude --agent <name>`. Unknown arg → exit 2 with stderr message. estimate_minutes: 35. Files: `scripts/coordinator-boot.sh` (new). DoD: `bash scripts/coordinator-boot.sh BadName` exits 2; `shellcheck` clean; script marked `chmod +x`; runs on macOS bash 3.2 and Git Bash (Rule 10).
- [ ] **T2** — Update `scripts/mac/aliases.sh` so `evelynn` and `sona` aliases invoke `coordinator-boot.sh <Name>` instead of bare `claude --agent <Name>`. estimate_minutes: 10. Files: `scripts/mac/aliases.sh`. DoD: both aliases route through coordinator-boot.sh; sourcing `aliases.sh` in a fresh zsh does not error.
- [ ] **T3** — Update `scripts/mac/launch-evelynn.sh` iTerm launcher to export `CLAUDE_AGENT_NAME=Evelynn` (either directly or by delegating to `coordinator-boot.sh Evelynn`). estimate_minutes: 15. Files: `scripts/mac/launch-evelynn.sh`. DoD: launcher exports identity before `claude` spawns; spot-check via `env | grep CLAUDE_AGENT_NAME` in a launched session.
- [ ] **T4** — Update `scripts/windows/launch-evelynn.ps1` to set `$env:CLAUDE_AGENT_NAME='Evelynn'`, `$env:STRAWBERRY_AGENT='Evelynn'`, `$env:STRAWBERRY_CONCERN='personal'` before invoking `claude`. estimate_minutes: 15. Files: `scripts/windows/launch-evelynn.ps1`. DoD: PowerShell parse check passes; env vars set prior to `claude` invocation line.
- [ ] **T5** — Update `scripts/windows/launch-evelynn.bat` to `set CLAUDE_AGENT_NAME=Evelynn` (plus siblings) before invoking `claude`. estimate_minutes: 10. Files: `scripts/windows/launch-evelynn.bat`. DoD: `.bat` sets all three env vars before the `claude` line.
- [ ] **T6** — Add Sona launcher parity on Windows: `scripts/windows/launch-sona.ps1` and `scripts/windows/launch-sona.bat`, mirroring the Evelynn ones but with `Sona`/`work`. estimate_minutes: 20. Files: `scripts/windows/launch-sona.ps1` (new), `scripts/windows/launch-sona.bat` (new). DoD: both exist and export identity identically-shaped to the Evelynn equivalents.
- [ ] **T7** — Add Sona launcher parity on macOS: `scripts/mac/launch-sona.sh` (if not present) delegating to `coordinator-boot.sh Sona`. estimate_minutes: 10. Files: `scripts/mac/launch-sona.sh` (new or modify). DoD: launcher present, executable, routes through coordinator-boot.sh.
- [ ] **T8** — Document the launcher/boot-script surface in `architecture/coordinator-boot.md`: invariants INV-1..INV-6, the single boot script, identity resolution order, failure modes. estimate_minutes: 25. Files: `architecture/coordinator-boot.md` (new). DoD: page renders; cross-linked from `architecture/compact-workflow.md` "related".
- [ ] **T9** — **C1 commit**: conventional `chore:` prefix (scripts outside `apps/**` plus docs). Subject: `chore: add coordinator-boot.sh + launcher identity exports`. Body summarises T1–T8. No behaviour flip yet. estimate_minutes: 10. Files: commit only. DoD: single commit on branch containing T1–T8 diffs; pre-push hooks pass; no files from C2/C3 included.

### C2 — xfail tests (must fail against current state, land BEFORE C3)

Tests live under `scripts/hooks/tests/` matching existing naming (`test-<what>.sh`, POSIX bash; follow the style of any existing test there).

- [ ] **T10** — Test: `test-coordinator-boot-identity-export.sh`. Asserts AC-4 — after sourcing `coordinator-boot.sh Evelynn` in a subshell, `CLAUDE_AGENT_NAME=Evelynn`, `STRAWBERRY_AGENT=Evelynn`, `STRAWBERRY_CONCERN=personal`; same for Sona/work. Stubs the `exec claude` call (replaces `claude` in PATH with an `#!/bin/sh\nenv > "$OUT"` stub). estimate_minutes: 30. Files: `scripts/hooks/tests/test-coordinator-boot-identity-export.sh` (new). DoD: test executable, runs under plain bash; guards AC-4 regression (xfail property is weak here — C1 already provides the script by the time this test runs, but it still must fail if coordinator-boot.sh is reverted).
- [ ] **T11** — Test: `test-inbox-watch-fail-loud.sh`. Asserts AC-6 — with both `CLAUDE_AGENT_NAME` and `STRAWBERRY_AGENT` unset, `bash scripts/hooks/inbox-watch.sh` exits 0, emits a stderr diagnostic containing `no CLAUDE_AGENT_NAME`, and produces EMPTY stdout (no fallback to Evelynn's inbox). estimate_minutes: 25. Files: `scripts/hooks/tests/test-inbox-watch-fail-loud.sh` (new). DoD: xfail on C1 HEAD (current script falls back to `.agent` field → non-empty stdout scoped to Evelynn); will pass after C3/T17.
- [ ] **T12** — Test: `test-inbox-watch-scopes-by-env.sh`. Asserts AC-5 — with `CLAUDE_AGENT_NAME=Sona` set and a test-fixture Sona inbox containing a known sentinel message, `inbox-watch.sh` stdout contains the Sona sentinel and NOT any Evelynn-only sentinel. Uses a tmpdir fixture for inbox paths. estimate_minutes: 30. Files: `scripts/hooks/tests/test-inbox-watch-scopes-by-env.sh` (new). DoD: xfail on C1 HEAD because current chain falls through to `.agent=Evelynn`; will pass after C3/T17 when the `.agent` fallback is removed.
- [ ] **T13** — Test: `test-monitor-arming-gate-stateless.sh`. Asserts the simplified stateless gate (Evelynn's simplicity tightening): with sentinel `/tmp/claude-monitor-armed-${CLAUDE_SESSION_ID}` absent, the PreToolUse gate emits `INBOX WATCHER NOT ARMED` on EVERY tool call (not just the N-th); with sentinel present, gate is a silent no-op (`[ -f ... ]` returns 0, nothing emitted). Test simulates PreToolUse JSON payload on stdin and asserts systemMessage/additionalContext output. estimate_minutes: 30. Files: `scripts/hooks/tests/test-monitor-arming-gate-stateless.sh` (new). DoD: xfail on C1 HEAD (hook does not yet exist); will pass after C3/T21.
- [ ] **T14** — Test: `test-monitor-gate-coordinator-scoped.sh`. Asserts §4.2.G scope callout — with `CLAUDE_AGENT_NAME=Kayn` (a subagent), gate is silent even without sentinel. Only fires for `Evelynn`/`Sona`. estimate_minutes: 20. Files: `scripts/hooks/tests/test-monitor-gate-coordinator-scoped.sh` (new). DoD: xfail on C1 HEAD; will pass after C3/T21.
- [ ] **T15** — Test: `test-initialprompt-signal-b-absent.sh`. Asserts AC-8 + INV-2 — `grep -i 'resumed session' .claude/agents/evelynn.md .claude/agents/sona.md` returns ONLY lines that reference the SessionStart hook (Signal A), not the model-level heuristic paragraph. Negative grep: the string "skip the file reads" must not appear in either initialPrompt. estimate_minutes: 20. Files: `scripts/hooks/tests/test-initialprompt-signal-b-absent.sh` (new). DoD: xfail on C1 HEAD (Signal B currently present); will pass after C3/T19+T20.
- [ ] **T16** — **C2 commit**: conventional `chore:` prefix (tests outside `apps/**`). Subject: `chore: xfail tests for coordinator-boot-unification (INV-1..INV-6, AC-1..AC-8)`. Per Rule 12 these xfail tests MUST land before any implementation commit on the branch; this commit MUST come before C3. estimate_minutes: 10. Files: commit only. DoD: single commit with T10–T15 diffs; `bash scripts/hooks/tests/test-*.sh` shows T11/T12/T13/T14/T15 failing (xfail); pre-push passes.

### C3 — Behaviour flip (lands last, after C2 xfail tests prove contract)

- [ ] **T17** — Harden `scripts/hooks/inbox-watch.sh`: drop the `.claude/settings.json .agent` third fallback; identity chain becomes `CLAUDE_AGENT_NAME → STRAWBERRY_AGENT → fail-loud`. On missing env, print `inbox-watch: no CLAUDE_AGENT_NAME or STRAWBERRY_AGENT set; refusing to default` to stderr and `exit 0` with empty stdout. estimate_minutes: 20. Files: `scripts/hooks/inbox-watch.sh`. DoD: diff matches §4.2.E exactly; T11 and T12 now PASS; shellcheck clean.
- [ ] **T18** — Harden `scripts/hooks/inbox-watch-bootstrap.sh`: same identity-chain simplification as T17; remove `.agent` field read; simplify the Monitor nudge `additionalContext` to an imperative first-action instruction. estimate_minutes: 25. Files: `scripts/hooks/inbox-watch-bootstrap.sh`. DoD: no reference to `.claude/settings.json` or `.agent` remains in the script; shellcheck clean; Monitor nudge is a single unambiguous imperative block.
- [ ] **T19** — **[TOP-LEVEL]** Remove Signal B from `.claude/agents/evelynn.md` `initialPrompt`: delete the "If this is a resumed session ... reply with 'Session resumed.'" paragraph; replace with the §4.2.D block. Move the `memory-consolidate.sh` invocation OUT of `initialPrompt` (now in coordinator-boot.sh per T1). estimate_minutes: 20. Files: `.claude/agents/evelynn.md`. DoD: Signal B paragraph removed; initialPrompt is a pure file-reads chain; after T20, `diff .claude/agents/evelynn.md .claude/agents/sona.md` shows only the three-token variance per AC-8. Implementer MUST flag to Evelynn before committing.
- [ ] **T20** — **[TOP-LEVEL]** Mirror T19 changes into `.claude/agents/sona.md`. estimate_minutes: 15. Files: `.claude/agents/sona.md`. DoD: same structure as evelynn.md post-T19; T15 PASSES; `diff` constraint from T19/AC-8 satisfied. Implementer MUST flag to Evelynn before committing.
- [ ] **T21** — Author `scripts/hooks/pretooluse-monitor-arming-gate.sh` implementing the stateless gate (Evelynn's simplicity tightening): on every PreToolUse invocation, `[ -f /tmp/claude-monitor-armed-${CLAUDE_SESSION_ID} ]` — if present, silent exit 0 (no-op); if absent AND `CLAUDE_AGENT_NAME` ∈ {Evelynn,Sona}, emit `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"INBOX WATCHER NOT ARMED — invoke Monitor with bash scripts/hooks/inbox-watch.sh now."}}`. For non-coordinator identities, silent no-op. No counter, no state beyond the sentinel file. estimate_minutes: 35. Files: `scripts/hooks/pretooluse-monitor-arming-gate.sh` (new). DoD: shellcheck clean; T13 and T14 PASS; POSIX-portable bash (Rule 10); single `[ -f ]` check when sentinel present.
- [ ] **T22** — Add a Monitor-arming sentinel writer: when the Monitor tool is invoked with `scripts/hooks/inbox-watch.sh`, `touch /tmp/claude-monitor-armed-${CLAUDE_SESSION_ID}`. Implement via a matching PreToolUse or PostToolUse hook on the Monitor tool. estimate_minutes: 25. Files: `scripts/hooks/posttooluse-monitor-arm-sentinel.sh` (new). DoD: arming Monitor with the inbox-watch command creates the sentinel; T13's "sentinel present → silent" arm succeeds against this hook.
- [ ] **T23** — **[TOP-LEVEL]** **Conditional on T0.** Wire the new PreToolUse and PostToolUse hooks from T21/T22 into `.claude/settings.json`. If T0 probe shows the framework does NOT read `.agent`, also remove the `"agent": "Evelynn"` field from `.claude/settings.json`. If T0 shows the framework DOES read it, leave the field and document in `architecture/coordinator-boot.md` §identity (JSON has no comments). estimate_minutes: 30. Files: `.claude/settings.json`, optionally `architecture/coordinator-boot.md`. DoD: hooks wired under the appropriate `hooks` section; `.claude/settings.json` parses as valid JSON; field-deletion decision justified by the T0 probe note. Implementer MUST flag to Evelynn before committing.
- [ ] **T24** — **C3 commit**: conventional `chore:` prefix (no `apps/**` diff; all scripts + agent defs + settings). Subject: `chore: harden coordinator identity resolution + remove Signal B + wire Monitor-arming gate`. Body notes this is the behaviour flip; links back to C1/C2 commit SHAs. If pre-push TDD gate fails, investigate — do NOT use `--no-verify`. estimate_minutes: 15. Files: commit only. DoD: single commit with T17–T23 diffs; pre-push passes; all C2 tests now PASS; AC-1..AC-8 satisfiable by T25 smoke.

### Post-flip verification

- [ ] **T25** — Manual smoke: run AC-1..AC-8 verification, scripted where possible, by-hand where not. Record results in `assessments/qa-reports/2026-04-24-coordinator-boot-unification-smoke.md`. estimate_minutes: 40. Files: `assessments/qa-reports/2026-04-24-coordinator-boot-unification-smoke.md` (new). DoD: each of AC-1..AC-8 has PASS/FAIL line with evidence (command + output snippet).

### Phase gates

- **Gate C1 → C2**: C1 committed before any C2 test is authored. C2 tests must xfail against C1 HEAD (not raw `main`) for T11–T15 — C1 is additive only and does not affect existing hook behaviour, so the xfail property holds transitively.
- **Gate C2 → C3**: C2 commit SHA recorded in the C3 commit body. C3 MUST NOT be pushed before C2. Rule 12 enforced by the pre-push TDD gate.
- **Gate C3 → done**: T25 smoke report committed; all 8 ACs PASS.

### Totals

- Task count: 26 (T0 + T1..T25).
- Total estimate_minutes: 10 + (35+10+15+15+10+20+10+25+10) + (30+25+30+30+20+20+10) + (20+25+20+15+35+25+30+15) + 40 = **545 minutes** (~9 hours of AI execution across one probe + three commits).
- `[TOP-LEVEL]` tasks: T19, T20, T23 (three — all coordinator write surfaces).
- Max single-task estimate: 40 minutes (T25). All tasks ≤ 60 minutes per breakdown rules.

### Open questions

None. OQ-1 was pre-resolved by Evelynn (accept Azir's default, probe via T0, optional delete via T23). The simplicity tightening of §4.2.G is encoded in T13/T21 (stateless gate, no counter). No new OQs surfaced during breakdown.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear owner (Azir), a coherent problem statement with root-cause analysis, six named invariants, eight testable acceptance criteria, and file-level design for seven concrete surfaces (A–G). The single open question (OQ-1) was resolved inline with the safer reversible default — keep the `.agent` field, gate hooks to ignore it. The plan itself flags §4.2.G's tool-call-counter as overengineered and defers the simplification to Kayn's breakdown, which is the right seam. Approved for promotion to `plans/approved/personal/`.
