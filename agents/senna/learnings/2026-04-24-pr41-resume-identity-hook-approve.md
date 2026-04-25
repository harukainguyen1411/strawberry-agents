# PR #41 — resume-session coordinator identity hook — APPROVE

**Repo:** `harukainguyen1411/strawberry-agents`
**Branch:** `fix/resume-session-coordinator-identity`
**Plan:** `plans/approved/personal/2026-04-24-resume-session-coordinator-identity.md` (owner: karma)
**Reviewer identity:** `strawberry-reviewers-2` (--lane senna)

## Verdict

APPROVE. Clean, plan-faithful, shellcheck-clean on the hook, tests 8/8 green locally.

## Implementation shape

New script `scripts/hooks/sessionstart-coordinator-identity.sh` replaces the inline one-liner in `.claude/settings.json`. For `source=resume|clear|compact` it walks a three-tier resolution chain:

1. Env var — `CLAUDE_AGENT_NAME` then `STRAWBERRY_AGENT`, allowlisted to `{evelynn, sona}`.
2. Hint file — `$REPO_ROOT/.coordinator-identity` (gitignored), written by `/pre-compact-save`.
3. Fail-loud — emits `additionalContext` instructing the session NOT to assume Evelynn-default and to ask Duong.

For `source=startup` the script exits 0 with no output, preserving the fresh-session CLAUDE.md default.

## Safety properties I verified

- `set -euo pipefail` honored; all env expansions use `${VAR:-}` for `set -u` compatibility.
- Allowlist normalization (`tr '[:upper:]' + tr -d '[:space:]'`) applied at every tier — non-matching values fall through (not hard-fail), per plan.
- `$_cap` derived from allowlisted name → cannot inject `%` into `printf '%s'` template.
- `_additional` strings contain no `"`, `\`, or control chars; em-dashes are valid JSON UTF-8.
- `jq -r '.source' 2>/dev/null || echo ""` handles empty/malformed stdin (SRC="" → early exit).
- `.claude/settings.json` preserves the chained `inbox-watch-bootstrap.sh` hook — no inbox regression.
- `.gitignore` works (`git check-ignore .coordinator-identity`).

## Suggestions flagged (non-blocking)

- **S1 — test gap**: The "env var beats hint file" invariant (plan T2 DoD) is declared but not actually asserted. `OUT3` is computed then abandoned (SC2034). Tier-1 short-circuit of tier-2 is exercise-able cheaply by extending INV-3's hint-file setup with one more check where `CLAUDE_AGENT_NAME=evelynn` and hint says `sona`.
- **S2 — opt-out**: `.no-precompact-save` → no hint file written → env var is only non-fail-loud safety net. Correct behavior but worth documenting.
- **S3 — hint staleness**: Hint file persists until next pre-compact-save overwrites it. Launcher env export from PR #39 covers this in practice (tier-1 wins), but cross-concern checkout reuse could surface staleness without env var.

## Mechanics

- `scripts/reviewer-auth.sh --lane senna` used correctly → auth confirmed as `strawberry-reviewers-2`.
- Posted APPROVED review with `-- reviewer` neutral sign-off appropriate for personal-concern PR (agent-infra, not work scope). Review URL: https://github.com/harukainguyen1411/strawberry-agents/pull/41

## Key insight

This is the right size of fix for the drift: the plan explicitly rejected the heavier JSONL-parsing alternative ("we skip JSONL parsing entirely"). The three-tier chain is strictly shell, strictly local, and fails loud by default instead of falling back to Evelynn-default — exactly the inversion the 2026-04-24 Sona-as-Evelynn incident called for.
