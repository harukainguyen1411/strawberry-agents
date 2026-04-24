---
slug: resume-session-coordinator-identity
date: 2026-04-24
owner: karma
concern: personal
complexity: quick
status: approved
orianna_gate_version: 2
tests_required: true
---

# Resume-session coordinator identity — no-greeting fallback fix

## Context

On 2026-04-24, Sona booted as Evelynn on a resumed session (`/compact` → `/exit` → fresh `claude --resume`). The `SessionStart` hook fired with `source=resume`, the conversation had no greeting in its replayed transcript, and the repo-root `CLAUDE.md` rule "no greeting → Evelynn default" matched. Evelynn-identity Sona then merged PR #37 (out-of-scope), armed the wrong inbox Monitor, and read the wrong `open-threads.md`. Full incident in `agents/evelynn/inbox/archive/2026-04/20260424-0647-013277.md`.

PR #39 (coordinator-boot-unification, merged at 8f942bc1) hardened the launcher side — `scripts/mac/launch-evelynn.sh` and `scripts/mac/launch-sona.sh` export `CLAUDE_AGENT_NAME` / `STRAWBERRY_AGENT` / `STRAWBERRY_CONCERN` at alias time. That covers the explicit alias-launch path but NOT `claude --resume` invocations, which bypass the launcher and inherit only the caller shell's env. The CLAUDE.md routing rule is the last-mile fallback, and on resume it defaults wrong.

Fix shape: the `no greeting → Evelynn` fallback should apply ONLY to `source=startup` sessions. On `source=resume|clear|compact`, resolve coordinator identity via a chain — env var (already set by PR #39 when launcher was used) → hint file written by `/pre-compact-save` → fail-loud system-message telling the session to ask Duong rather than guessing. We skip JSONL parsing entirely: the hint file is one line, the skill already writes at compact time, and it's strictly simpler than walking `~/.claude/projects/**/*.jsonl`.

## Decision

1. Extend the `SessionStart` hook (currently a one-liner inline in `.claude/settings.json`) into a dedicated script `scripts/hooks/sessionstart-coordinator-identity.sh` that (a) preserves the existing "skipping startup reads" message on resume/clear/compact, and (b) additionally asserts coordinator identity from the resolution chain.
2. Resolution chain on `source ∈ {resume, clear, compact}`:
   - **Tier 1**: `$CLAUDE_AGENT_NAME` or `$STRAWBERRY_AGENT` env var — if set and is `evelynn` or `sona`, emit `additionalContext` pinning that identity.
   - **Tier 2**: Read `.coordinator-identity` (repo-root, gitignored) — one line, `evelynn` or `sona`, written by `/pre-compact-save`. If present and valid, emit `additionalContext` pinning that identity.
   - **Tier 3 (fail-loud)**: Neither tier resolved. Emit `additionalContext` that says: "RESUMED SESSION — coordinator identity unresolved. DO NOT assume Evelynn-default. Ask Duong which coordinator this session is before reading any coordinator startup files." This overrides the CLAUDE.md no-greeting-default rule for resume sessions.
3. On `source=startup`, the script exits 0 with no output — the existing "no greeting → Evelynn default" rule in CLAUDE.md continues to apply for fresh sessions only.
4. `/pre-compact-save` skill writes `.coordinator-identity` with the current coordinator name before `/compact` runs. The skill already runs coordinator-context consolidation — this is a one-line append.
5. `.coordinator-identity` is added to `.gitignore` (it's per-checkout state, not committed).

## Tasks

- **T1** — kind: code. estimate_minutes: 15. Files: `scripts/hooks/sessionstart-coordinator-identity.sh` (new) <!-- orianna: ok -->, `.claude/settings.json`. Detail: extract the existing inline `SessionStart` command into the new script. Preserve current behavior verbatim for `source=startup` (no output) and for resume/clear/compact (emit the existing "Resumed session — skipping startup reads" system message and `additionalContext`). Wire `settings.json` to invoke `bash scripts/hooks/sessionstart-coordinator-identity.sh`. DoD: running the hook with each source value produces byte-identical output to the current inline command; `shellcheck` clean; POSIX-portable bash per Rule 10.

- **T2** — kind: test. estimate_minutes: 20. Files: `scripts/hooks/tests/test-sessionstart-coordinator-identity.sh` (new) <!-- orianna: ok -->. Detail: xfail test — simulate `source=resume` stdin payload with NO env vars set and NO `.coordinator-identity` file present. Assert hook output includes the fail-loud "coordinator identity unresolved" string AND does NOT default to Evelynn. Cover the happy path too: env var set → assert identity pinned; hint file present → assert identity pinned; both set → assert env var wins. Mark xfail with `# xfail: plans/proposed/personal/2026-04-24-resume-session-coordinator-identity.md T3`. DoD: test runs under `scripts/hooks/test-hooks.sh`, fails until T3 lands.

- **T3** — kind: code. estimate_minutes: 25. Files: `scripts/hooks/sessionstart-coordinator-identity.sh`. Detail: implement the three-tier resolution chain from §Decision.2. Env var tier checks `CLAUDE_AGENT_NAME` then `STRAWBERRY_AGENT`; must validate value ∈ {`evelynn`, `sona`} — other values fall through to next tier. Hint-file tier reads `.coordinator-identity` at repo root (resolve via `git rev-parse --show-toplevel`), strips whitespace, validates against the same allowlist. Fail-loud tier emits the exact `additionalContext` string from §Decision.2 tier 3. Each tier emits valid JSON per the SessionStart hook contract (`systemMessage` + `hookSpecificOutput.additionalContext`). DoD: T2 passes; all four test cases green.

- **T4** — kind: code. estimate_minutes: 10. Files: `.claude/skills/pre-compact-save/SKILL.md`. Detail: add a step that writes the current coordinator identity to `.coordinator-identity` (one line, `evelynn` or `sona`, lowercased) before `/compact` is invoked. Identity is derived from `$CLAUDE_AGENT_NAME` with fallback to the coordinator name inferred from the current session's memory-path target. DoD: skill docs updated; manual dry-run produces a `.coordinator-identity` file with correct contents.

- **T5** — kind: code. estimate_minutes: 3. Files: `.gitignore`. Detail: append `.coordinator-identity` so the hint file is never committed. DoD: `git check-ignore .coordinator-identity` confirms ignored.

- **T6** — kind: docs. estimate_minutes: 10. Files: `CLAUDE.md` (repo root). Detail: amend the "Caller Routing" section — qualify the "No greeting given → Evelynn by default" rule with "**on fresh sessions only (`source=startup`). Resumed sessions resolve coordinator identity via `scripts/hooks/sessionstart-coordinator-identity.sh`; if the hook emits a fail-loud context, ask Duong rather than assuming.**" DoD: rule reads unambiguously; mentions the hook by path.

## Test plan

Invariants protected:

1. **Resume-without-identity must not silently default.** A resumed session with no greeting, no env var, and no hint file MUST NOT boot as Evelynn — it must surface the fail-loud message. (Regression for the 2026-04-24 Sona-as-Evelynn incident.)
2. **Env var wins.** Launcher-exported `CLAUDE_AGENT_NAME` takes precedence over everything, preserving PR #39's hardening.
3. **Hint file works as fallback.** When `/pre-compact-save` ran and wrote the hint, a subsequent `claude --resume` without env vars still resolves the right coordinator.
4. **Fresh-session default unchanged.** `source=startup` with no greeting still allows the CLAUDE.md "Evelynn default" rule to apply — this plan must not break fresh-session boot.

T2 covers all four invariants as discrete cases. The xfail lives on the branch with T1; T3 flips it green. No E2E or Playwright coverage needed — pure shell hook logic.

## References

- Incident report: `agents/evelynn/inbox/archive/2026-04/20260424-0647-013277.md`
- Prior hardening: PR #39 `coordinator-boot-unification` (merged 8f942bc1) — launcher env exports.
- Current SessionStart inline hook: `.claude/settings.json` line 46.
- Launcher scripts: `scripts/mac/launch-evelynn.sh`, `scripts/mac/launch-sona.sh`.
- Universal invariant context: repo-root `CLAUDE.md` "Caller Routing" section.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Owner (karma), concern, and complexity are explicit. Tasks T1–T6 are concrete with files, DoD, and estimates. T2 is an xfail test written before T3 implementation, satisfying the TDD gate (Rule 12) for `tests_required: true`. Invariants in the test plan map 1:1 to regression cases including the originating 2026-04-24 incident. Fix shape (three-tier resolution + hint file) is proportionate — rejected the heavier JSONL-parsing alternative with stated reasoning.
