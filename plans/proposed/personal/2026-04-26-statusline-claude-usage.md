---
slug: statusline-claude-usage
date: 2026-04-26
owner: karma
concern: personal
complexity: quick
status: proposed
orianna_gate_version: 2
tier: quick
tests_required: true
qa_plan: shell-unit
---

# Claude Code statusline — 5h + 7d usage display

## Context

Lux's research note `assessments/research/2026-04-26-claude-usage-statusline.md` recommends the **primary path**: a small POSIX script that reads the statusline stdin JSON, extracts `rate_limits.five_hour` and `rate_limits.seven_day` (`used_percentage` + `resets_at` epoch), and prints a single-line summary. Wire it via `~/.claude/settings.json` `statusLine.command`. Defensive when fields are missing (fresh session, non-Pro/Max account) — fall back to `--` placeholders. No network calls, no caches, no transcript reconstruction.

This is a single-script change plus a one-line config wire-up plus a short architecture doc. No schema changes, no shared invariants touched, no new external integration. Pure quick-lane shape.

The script lives in-repo under `scripts/statusline/claude-usage.sh` so it is version-controlled and POSIX-portable per Rule 10. The user's `~/.claude/settings.json` is symlinked or pointed at the in-repo script — Duong wires that locally; the plan does not write to `~/.claude/`.

## Decision

1. **In-repo script** at `scripts/statusline/claude-usage.sh`. Reads JSON on stdin via `jq`. Extracts: `model.display_name`, `context_window.used_percentage`, `rate_limits.five_hour.used_percentage`, `rate_limits.five_hour.resets_at`, `rate_limits.seven_day.used_percentage`, `rate_limits.seven_day.resets_at`. Renders one line: `<model> | ctx <N>% | 5h <P>% (resets HH:MM) | 7d <Q>% (resets <weekday>)`. Missing fields → `--`.
2. **Reset-time formatting**: `resets_at` is Unix epoch. 5h reset → `date -r <epoch> +%H:%M` (BSD `date`) with GNU fallback `date -d @<epoch> +%H:%M`. 7d reset → weekday short name (`+%a`).
3. **Color thresholds (optional, ANSI)**: green ≤50%, yellow 50–80%, red >80%. Suppress colors when stdout is not a TTY OR when `NO_COLOR` env var is set.
4. **Wire-up doc** at `architecture/claude-statusline.md` — documents field semantics, the Pro/Max-only caveat, the "absent on first turn of a fresh session" caveat, and the one-liner Duong adds to `~/.claude/settings.json` (`{"statusLine":{"type":"command","command":"<repo>/scripts/statusline/claude-usage.sh"}}`).
5. **No secondary path** (oauth/usage endpoint) and **no tertiary path** (OTel) in this plan — Lux is explicit those are only adopted if the primary proves flaky. Defer.

## Tasks

- **T1** — kind: test. estimate_minutes: 20. Files: `scripts/statusline/tests/test-claude-usage.sh` (new). <!-- orianna: ok --> parallel_slice_candidate: true. Detail: xfail test for `scripts/statusline/claude-usage.sh`. Cases: (a) full payload with `rate_limits` populated → assert output matches `5h <pct>%` and `7d <pct>%` substrings; (b) payload with `rate_limits` absent → assert `5h --%` and `7d --%` placeholders; (c) payload with only `five_hour` present and `seven_day` missing → asserts mixed; (d) `NO_COLOR=1` → asserts no ANSI escape codes in output; (e) malformed JSON on stdin → script exits 0 with a degraded `-- | ctx --% | 5h --% | 7d --%` line (statusline must never crash Claude Code). Mark xfail with `# xfail: plans/proposed/personal/2026-04-26-statusline-claude-usage.md T2`. DoD: test script runs standalone via bash; fails on missing T2 implementation; shellcheck clean.

- **T2** — kind: code. estimate_minutes: 30. Files: `scripts/statusline/claude-usage.sh` (new). <!-- orianna: ok --> parallel_slice_candidate: false. Detail: implement per §Decision.1–3. POSIX-portable bash; uses only `jq`, `date`, `printf`. `jq -r '.rate_limits.five_hour.used_percentage // "--"'` style with `// "--"` defaults. For `resets_at` epoch → human time, detect platform: `date -r "$epoch" +%H:%M` first (BSD/macOS), fall back to `date -d "@$epoch" +%H:%M` (GNU/Linux/Git-Bash). Round percentages to integers (`printf '%.0f'`). Color block guarded by `[ -t 1 ] && [ -z "${NO_COLOR:-}" ]`. Malformed-JSON path: wrap the `jq` call with a fallback so any non-zero exit prints the all-`--` line. Make executable (`chmod +x` in the same commit). DoD: T1 passes all 5 cases; shellcheck clean; manual run with a sample payload prints expected line.

- **T3** — kind: docs. estimate_minutes: 15. Files: `architecture/claude-statusline.md` (new). <!-- orianna: ok --> parallel_slice_candidate: true. Detail: document (a) the stdin JSON schema fields the script consumes, (b) the Pro/Max-only caveat for `rate_limits`, (c) the "first-turn absence" caveat, (d) the one-line `~/.claude/settings.json` snippet pointing `statusLine.command` at the in-repo script (use absolute path because Claude Code invokes the command from the cwd of the active project), (e) link back to Lux's research note. Keep under 80 lines. DoD: file renders cleanly; settings snippet is copy-pasteable; references resolve.

- **T4** — kind: code. estimate_minutes: 5. Files: `scripts/statusline/sample-payload.json` (new). <!-- orianna: ok --> parallel_slice_candidate: true. Detail: commit a sample stdin payload (matching the schema in Lux's research note §1a) for use by T1 tests and for manual `cat sample-payload.json | scripts/statusline/claude-usage.sh` smoke runs. Include `rate_limits` populated with realistic percentages (e.g. `23.5` and `41.2`) and a future `resets_at` epoch. DoD: file is valid JSON (`jq . sample-payload.json`).

## Test plan

Invariants protected:

1. **Statusline must never crash Claude Code.** Malformed JSON or any unexpected stdin must yield exit 0 with a degraded `--` line (T1.e).
2. **Graceful degradation when `rate_limits` is absent.** Fresh sessions and non-Pro/Max accounts must see `--%` placeholders rather than empty strings or jq parse errors (T1.b, T1.c).
3. **`NO_COLOR` is honored.** Standard terminal-respect contract (T1.d).
4. **Happy-path output shape.** When all fields are present, the output line contains both `5h <int>%` and `7d <int>%` substrings — the load-bearing user-visible contract (T1.a).

T1 covers all four invariants as discrete cases under `scripts/statusline/tests/test-claude-usage.sh`. xfail lives on the branch with T1; T2 flips it green. No E2E, no Playwright — pure shell + jq.

## References

- Research note: `assessments/research/2026-04-26-claude-usage-statusline.md` (Lux, 2026-04-26)
- Statusline schema: https://code.claude.com/docs/en/statusline
- Schema gist (AKCodez): https://gist.github.com/AKCodez/ffb420ba6a7662b5c3dda2edce7783de
- Closest reference impl: https://github.com/benabraham/claude-code-status-line
- Prior empty-commit incident: `85c39168` (session 9c8170e8 — file write lost to subagent bash-denial regression; this plan is the re-author)
