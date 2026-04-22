---
status: implemented
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: true
complexity: quick
tags: [hooks, git, ai-attribution, enforcement, commit-msg]
related:
  - scripts/install-hooks.sh
  - scripts/hooks/pre-commit-secrets-guard.sh
  - architecture/key-scripts.md
  - agents/syndra/learnings/
architecture_impact: none
orianna_signature_approved: "sha256:7af6422f64f5a3071d52684b951db58de5e4d5e49fc3e6fec3d89c7295d55df8:2026-04-22T15:00:47Z"
orianna_signature_in_progress: "sha256:7af6422f64f5a3071d52684b951db58de5e4d5e49fc3e6fec3d89c7295d55df8:2026-04-22T15:03:46Z"
orianna_signature_implemented: "sha256:7af6422f64f5a3071d52684b951db58de5e4d5e49fc3e6fec3d89c7295d55df8:2026-04-22T15:17:09Z"
---

# Block AI co-author trailers at commit-msg time

## 1. Context

The global CLAUDE.md rule "Never include AI authoring references in commits" is agent-policy. Agent discipline alone is insufficient: today a Syndra commit (`663c274`) landed with a `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer, requiring a three-commit revert+reapply chain (`bcc66d1` / `54ac1bf` / `d2cb0e0`) and a Syndra learning to recover. This is the **second** such offense this session — the pattern is mechanical, so the enforcement must be mechanical.

A new `commit-msg` git hook will reject any staged commit message containing a `Co-Authored-By:` trailer whose name or email field matches known AI-attribution signatures (Claude, Anthropic, AI, bot, assistant). The hook is the right phase: the check is on the message, not the diff. An explicit `Human-Verified: yes` trailer (exact-case) is the escape hatch for real edge cases (a human collaborator whose name contains a blocked keyword); this is deliberately narrow so abuse is self-documenting in `git log`.

Installation requires extending `scripts/install-hooks.sh` to register a **third** dispatcher verb — today it only installs `pre-commit` and `pre-push`. The extension is mechanical: one additional `install_dispatcher "commit-msg"` line plus the corresponding `commit-msg-*.sh` pattern in the loop (handled by the existing VERB substitution). No existing `commit-msg` hooks are present in `scripts/hooks/`, <!-- orianna: ok -- no hooks exist yet, not a path claim --> so chaining concerns do not apply.

## 2. Decision

Add `scripts/hooks/commit-msg-no-ai-coauthor.sh`, <!-- orianna: ok -- prospective file path, not yet committed --> wire it via `install-hooks.sh`, land an xfail regression test that proves the hook rejects the exact offending trailer from `663c274`, and document in `architecture/key-scripts.md`. Scope is new commits only; historical rewrites are explicitly out of scope.

## 3. Rejection patterns

The hook scans the commit message (argument `$1` passed by git = path to `COMMIT_EDITMSG`) for any line matching (case-insensitive, POSIX ERE):

- `^Co-Authored-By:.*\b(claude|anthropic|ai|bot|assistant)\b`
- `^Co-Authored-By:.*@(anthropic\.com|claude\.com|noreply\.anthropic\.com)`

Word-boundary on the name-keyword pass ensures "Kai" does not false-match "AI". The `Human-Verified: yes` trailer (exact case, exact value) anywhere in the message suppresses the check for that commit only.

## 4. Rejection message

```
✘ AI co-author trailer detected in commit message:
    <offending line>

Per global CLAUDE.md: "Never include AI authoring references in commits."

Remove the trailer and retry. If a human collaborator's name legitimately
contains a blocked keyword, add a `Human-Verified: yes` trailer to override.
```

## 5. Out of scope

- Rewriting historical commits that carry the trailer.
- Diff-content AI-attribution scanning (e.g., "Generated with Claude" in source code).
- PR-description attribution linting (GitHub-side, not a git hook).

## Tasks

1. **xfail regression test** — `kind: test`, `estimate_minutes: 10`. Files: `scripts/hooks/tests/commit-msg-no-ai-coauthor.test.sh`. <!-- orianna: ok -- prospective test file path --> Detail: Write a POSIX bash test with five cases. Case one — create a temp file containing the exact `663c274` commit message including the `Co-Authored-By: Claude Opus 4.7 1M context noreply-anthropic` trailer, invoke `scripts/hooks/commit-msg-no-ai-coauthor.sh <tmpfile>` and assert exit code `1` plus stderr contains the offending line. Case two — append `Human-Verified: yes` to that same message and assert exit code `0`. Case three — a clean message with no AI trailer and no override asserts exit code `0`. Case four — a non-AI co-author such as `Co-Authored-By: Jane Doe <jane@example.com>` asserts exit code `0`. Case five — word-boundary: `Co-Authored-By: Kai Nguyen <kai@example.com>` asserts exit code `0`. Per Rule 12, this commit lands **before** the hook implementation and must be xfail — the hook file does not yet exist, so the test script should `exit 0` with an "xfail — hook not yet implemented" stderr line when `[ ! -x scripts/hooks/commit-msg-no-ai-coauthor.sh ]`. DoD: test script executable, lands in its own commit tagged `kind: test`, referenced in the follow-up hook commit's message.
2. **Hook implementation** — `kind: feat`, `estimate_minutes: 20`. Files: `scripts/hooks/commit-msg-no-ai-coauthor.sh`. <!-- orianna: ok -- prospective hook file, implemented in PR #29 --> Detail: POSIX-portable bash with `#!/usr/bin/env bash` and `set -uo pipefail`. Accept `$1` as path to commit message file. Read the file; if it contains an exact-match `Human-Verified: yes` line, exit 0 silently. Otherwise, scan for `Co-Authored-By:` lines and apply both regex passes case-insensitively via `grep -iE`. On match: print the rejection message block from §4 to stderr with the offending line interpolated, exit 1. Otherwise exit 0. DoD: hook is executable, runs cleanly on a clean message, rejects the `663c274` fixture, accepts the `Human-Verified: yes` override, and the xfail test in Task 1 flips to pass.
3. **install-hooks.sh wiring** — `kind: chore`, `estimate_minutes: 10`. Files: `scripts/install-hooks.sh`. Detail: Add `install_dispatcher "commit-msg"` after the `pre-push` line. <!-- orianna: ok -- install-hooks.sh is an existing file, reference not a claim --> The existing VERB-substitution loop already filters by `$verb-*.sh` glob, so no loop changes are needed. Add `commit-msg-no-ai-coauthor.sh — blocks AI co-author trailers` to the header comment block enumerating hooks. Re-run `scripts/install-hooks.sh` locally to confirm it generates `.git/hooks/commit-msg`. DoD: fresh `install-hooks.sh` run produces a `commit-msg` dispatcher; a test commit with the offending trailer is rejected at commit-time; the xfail test from Task 1 now passes end-to-end when invoked directly.
4. **Docs: key-scripts.md** — `kind: chore`, `estimate_minutes: 5`. Files: `architecture/key-scripts.md`. Detail: Add a row for `scripts/hooks/commit-msg-no-ai-coauthor.sh` <!-- orianna: ok -- now existing file, reference not a claim --> in the hooks table, matching the existing four-column pattern of path, installed-via, description, and exit codes. Reference the rule "Never include AI authoring references in commits" from global CLAUDE.md. DoD: table entry present, renders cleanly.
5. **Docs: install-hooks header** — `kind: chore`, `estimate_minutes: 5`. Files: `scripts/install-hooks.sh` — header comment only; may be combined with Task 3's commit if small enough. Detail: Ensure the top-of-file comment block lists the new hook under a new `commit-msg hooks` section, mirroring the `pre-commit` and `pre-push` sections. DoD: comment block accurate; the `ls`-style enumeration at script end — `[install-hooks] Sub-hooks active: ...` — picks up the new hook automatically via its existing glob.

**Task count:** 5. **Total estimate:** 50 minutes.

## Test plan

Invariants protected:
- **I1** — A commit message carrying any known AI-attribution `Co-Authored-By:` trailer is rejected at `commit-msg` time, exit code 1, with the offending line echoed to stderr. Covered by Task 1 test cases (a)+(b).
- **I2** — The `Human-Verified: yes` escape hatch is case-sensitive and exact; lowercase or reworded variants do NOT suppress the check. Covered by Task 1 case (c) plus an additional assertion that `human-verified: yes` (lowercase) still rejects.
- **I3** — Non-AI co-authors (human collaborators with ordinary names) pass cleanly. Covered by Task 1 case (e).
- **I4** — Word-boundary matching on the name-keyword pass: a name like "Kai" or "Bart" does not false-match "AI" or "bot". Add an explicit case to Task 1: `Co-Authored-By: Kai Nguyen <kai@example.com>` asserts exit 0.
- **I5** — Fresh install via `scripts/install-hooks.sh` produces a working `commit-msg` dispatcher that invokes the new hook. Covered manually in Task 3 DoD. <!-- orianna: ok -- suppressor for path reference in DoD prose -->

The Task 1 test script is invoked directly (not via the dispatcher) so it runs identically in CI and locally, independent of hook installation state. Post-implementation, the test lives in `scripts/hooks/tests/` <!-- orianna: ok -- directory reference not a path claim --> alongside `pre-compact-gate.test.sh` and should be added to `scripts/hooks/test-hooks.sh` if that runner enumerates tests (verify during Task 1).

## Architecture impact

PR #29 (merge commit `51383944d7fdfc6e65fdd04e078461116317c102`) touched only `scripts/hooks/commit-msg-no-ai-coauthor.sh`, `scripts/hooks/tests/commit-msg-no-ai-coauthor.test.sh`, `scripts/install-hooks.sh`, and `architecture/key-scripts.md`. No files under the `architecture/` directory were structurally modified — `key-scripts.md` received only an additive table row. The architectural description in `architecture/plan-lifecycle.md` and sibling docs remains accurate. No architecture doc update is required. <!-- orianna: ok -- directory token in negation context, not a path claim -->

## Test results

PR #29 merge commit: `51383944d7fdfc6e65fdd04e078461116317c102`
Head SHA: `b77f2eb37716392196f0bc3c10946f22a54fe86d`
PR URL: https://github.com/harukainguyen1411/strawberry-agents/pull/29

All CI checks passed:

| Check | Workflow | Conclusion | Run URL |
|-------|----------|------------|---------|
| QA gate check (Rule 16) | PR Lint (Rule 16 — Akali / Playwright MCP gate) | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24785098445/job/72526752746 |
| xfail-first check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24785098398/job/72526752770 |
| xfail-first check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24785082235/job/72526693823 |
| regression-test check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24785098398/job/72526752689 |
| regression-test check | TDD Gate | SUCCESS | https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24785082235/job/72526693679 |

Gate fact-check: `assessments/plan-fact-checks/2026-04-21-commit-msg-no-ai-coauthor-hook-2026-04-21T13-07-39Z.md`
