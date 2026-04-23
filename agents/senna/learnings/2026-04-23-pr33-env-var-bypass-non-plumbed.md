# PR #33 re-review — env-var bypass that isn't actually plumbed

Date: 2026-04-23
PR: harukainguyen1411/strawberry-agents#33 (feat/inbox-write-guard)
Verdict: CHANGES_REQUESTED (second round)

## Pattern: "bypass wired to env var that runtime never sets"

Talon's fix for the critical /agent-ops regression added `STRAWBERRY_SKILL=agent-ops`
env-var bypass and a test (case `g`) that explicitly forces the var. Tests passed 13/13.
But at runtime:

- Claude Code PreToolUse hook payload has no skill field (confirmed via hooks docs).
- `.claude/skills/<name>/SKILL.md` has no hook-payload authorship mechanism.
- `Bash(export X=1)` env does not propagate across tool boundaries — each tool
  invocation gets parent Claude Code process env, not transient shell state.

Result: the bypass could never fire in production. The synthetic test case masked the
regression — the fix was cosmetic.

## How I caught it

1. Ran the test suite — 13/13 green.
2. Opened `.claude/skills/agent-ops/SKILL.md` and grepped for `STRAWBERRY_SKILL` — zero hits.
3. WebFetched Claude Code hooks docs to confirm no skill context in payload or env.
4. Concluded: the only place `STRAWBERRY_SKILL=agent-ops` ever exists is the test harness.

## Lesson

When reviewing bypass fixes that rely on env-var gates: **verify the env var is actually
set by the runtime code path the bypass is meant to unlock**. A passing unit test that
injects the env var proves only that the guard code reads the var correctly — it does
not prove that the real caller sets it.

The red-flag test is: "if I remove the env-var force in the test, does the caller-side
code still set it?" For this PR the answer is no — no code anywhere sets it.

## Recommended pattern for hook bypasses

Prefer one of:
- **Delegate to a script** the skill invokes via Bash. The script writes the file directly,
  bypassing the Write/Edit tool entirely, so the PreToolUse hook never fires. Mirrors the
  `/agent-ops list` and `/agent-ops new` shell-out pattern already in the skill. Clean.
- **Path-and-content pattern match** in the guard — recognize the sanctioned write by its
  file path (timestamp/shortid naming) + content shape (required frontmatter). Harder to
  get right, larger attack surface, but uses info the hook actually receives.

Avoid: env-var gates at tool-boundary hooks. They look tidy and test cleanly, but they
don't survive the process-model the hooks run under.

## Probes that confirmed fixes 2-4 landed cleanly

- Fix 2 (Edit allow-rule): `sed s/status: pending/status: read/` + strip `read_at:` +
  equality is sound for the common case. Two small residuals noted (line-scoped status
  replacement, unbounded `read_at:` injection) — low severity, flagged as non-blocking.
- Fix 3 (MultiEdit drop from matcher): case `k` covers unknown-tool passthrough.
- Fix 4 (absolute-path): tested repo-root strip, out-of-repo `agents/` suffix extraction,
  `../` traversal, worktree paths, `./` prefix. All block at exit 2.

## Review URL

https://github.com/harukainguyen1411/strawberry-agents/pull/33#pullrequestreview — posted
as `strawberry-reviewers-2` at 2026-04-23T09:45:24Z.
