---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: true
complexity: quick
tags: [hooks, git, enforcement, pre-commit, concurrency]
related:
  - scripts/install-hooks.sh
  - scripts/hooks/pre-commit-agent-shared-rules.sh
  - scripts/hooks/pre-commit-secrets-guard.sh
  - architecture/key-scripts.md
---

# Pre-commit staged-scope guard — prevent cross-agent commit sweeping

## 1. Context

Two incidents today prove that agent `git add` discipline alone is insufficient when multiple agent sessions share a working tree. First, Syndra added an AI co-author trailer to a commit that swept up unrelated staged work from a parallel session. Second, Ekko #67 ran a broad `git add` during the batch promote sequence and absorbed a separate Evelynn `CLAUDE.md` edit that Duong had staged — that edit landed under Ekko's misleading message `chore: add architecture_impact: none to pre-orianna-plan-archive frontmatter` at commit `10f7581`. Root cause in both: `git add -A`, `git add .`, or `git add <dir>/` with a dirty working tree owned by someone else.

The fix is a mechanical pre-commit hook that compares the set of staged paths against a declared scope. When the committing agent sets `STAGED_SCOPE` (newline-separated paths) or writes `.git/COMMIT_SCOPE`, any staged path not in the declared list causes a hard reject with the out-of-scope list echoed. When neither is set, the hook WARNS (non-blocking) if the commit touches more than three top-level directories or more than ten files — surfacing sloppy adds without breaking trivial commits. An escape hatch `STAGED_SCOPE=*` (exactly the asterisk) disables the check for legitimate bulk operations (memory consolidation, `scripts/install-hooks.sh` runs), logged loudly so drift is auditable in `git log`-adjacent tooling. <!-- orianna: ok -->

Wiring is trivial: drop `scripts/hooks/pre-commit-staged-scope-guard.sh` into the hooks directory and the existing `scripts/install-hooks.sh` `pre-commit-*.sh` glob picks it up automatically (alphabetical ordering places it after `scripts/hooks/pre-commit-secrets-guard.sh` and before `scripts/hooks/pre-commit-t-plan-structure.sh`, which is correct — secret scan runs first, scope check runs on the already-secret-free staged set). No changes to `scripts/install-hooks.sh` code required; only the header comment enumeration needs a row added. <!-- orianna: ok -->

## 2. Decision

Add `scripts/hooks/pre-commit-staged-scope-guard.sh`, an xfail regression test covering all three behaviors (hard block, warning path, escape hatch), and a row in `architecture/key-scripts.md`. Agent-definition updates that teach Yuumi/Ekko/Syndra/Talon/Viktor/Jayce to set `STAGED_SCOPE` are explicitly follow-up — this plan delivers enforcement only. The hook warns when scope is undeclared; that is the non-breaking on-ramp that lets the agent fleet migrate gradually. <!-- orianna: ok -->

## 3. Scope declaration semantics

The hook resolves scope in priority order:

1. `STAGED_SCOPE` environment variable — newline-separated paths (POSIX `printf '%s\n'`). Blank lines ignored. Leading/trailing whitespace trimmed per line.
2. `.git/COMMIT_SCOPE` file — same format. Cleared (`rm -f`) by the hook on successful scope match, so stale scope cannot leak into the next commit. <!-- orianna: ok -->
3. Neither set → warning mode.

Scope entries are compared as exact path matches (relative to repo root, as emitted by `git diff --cached --name-only`). No glob expansion; agents that legitimately touch many files declare each or use the `*` escape hatch. Exact-match keeps the hook logic POSIX-portable and audit-friendly.

## 4. Reject / warn messages

**Hard reject** (`STAGED_SCOPE` set, out-of-scope paths present):

```
✘ Staged-scope guard: commit contains files outside the declared STAGED_SCOPE.

Out-of-scope staged paths:
  <path1>
  <path2>

Declared scope:
  <scope1>
  <scope2>

This usually means `git add -A` / `git add .` / `git add <dir>/` swept up
another agent's parallel work. Unstage the foreign files (`git reset HEAD <path>`)
and retry, or widen STAGED_SCOPE if they legitimately belong to this commit.

Bulk-operation escape: STAGED_SCOPE='*' (exact asterisk) disables the check.
```

**Warning** (no scope set, >3 top-level dirs OR >10 files):

```
⚠ Staged-scope guard: commit is unscoped and touches <N> files across
<K> top-level directories. Set STAGED_SCOPE to narrow the commit, or
STAGED_SCOPE='*' if this is intentional bulk work.

Staged paths:
  <paths…>
```

Warning exits 0 — it is diagnostic only, surfaced once per commit.

**Escape hatch** (`STAGED_SCOPE=*`):

```
[staged-scope] Escape hatch active (STAGED_SCOPE=*). <N> files committed without scope check.
```

Logged to stderr, exit 0.

## 5. Out of scope

- Agent-definition updates teaching each sonnet executor to set `STAGED_SCOPE`. Follow-up plan; listed in §7.
- Shared-rules `_shared/` updates standardizing a commit preamble with scope declaration. Follow-up. <!-- orianna: ok -->
- Rewriting historical incidents (e.g. `10f7581`). No retro-fix.
- Glob / pattern matching in scope entries. Exact paths only.
- `commit-msg`-phase validation of scope (that would need scope restated in the message). Out of scope.

## 6. Tasks

1. **xfail regression test** — `kind: test`, `estimate_minutes: 15`. Files: `scripts/hooks/tests/pre-commit-staged-scope-guard.test.sh`. Detail: POSIX bash test with five cases driven against a throwaway git repo created under `mktemp -d`. Case A — stage two files (`a.txt`, `b.txt`), export `STAGED_SCOPE=$'a.txt'`, invoke `scripts/hooks/pre-commit-staged-scope-guard.sh`, assert exit 1 and stderr contains `b.txt` under "Out-of-scope". Case B — same two staged files, unset `STAGED_SCOPE`, assert exit 0 and stderr empty (2 files, 1 dir — below warn threshold). Case C — stage 12 files spread across 4 top-level dirs, no scope, assert exit 0 and stderr contains `⚠ Staged-scope guard`. Case D — same 12 files, `STAGED_SCOPE='*'`, assert exit 0 and stderr contains `Escape hatch active`. Case E — stage `a.txt` only, `STAGED_SCOPE=$'a.txt'`, assert exit 0 and `.git/COMMIT_SCOPE` absent after run. Per Rule 12, the test commit lands BEFORE the hook implementation; guard: when `[ ! -x scripts/hooks/pre-commit-staged-scope-guard.sh ]`, print `xfail — hook not yet implemented` to stderr and `exit 0`. DoD: test script executable, tagged `kind: test`, referenced in Task 2's commit message. <!-- orianna: ok -->

2. **Hook implementation** — `kind: feat`, `estimate_minutes: 30`. Files: `scripts/hooks/pre-commit-staged-scope-guard.sh`. Detail: POSIX-portable bash, `#!/usr/bin/env bash`, `set -uo pipefail`. Read staged paths via `git diff --cached --name-only --diff-filter=ACMR`. Resolve scope from `STAGED_SCOPE` env first, else `.git/COMMIT_SCOPE` file, else unset. If scope equals the literal single character `*` → emit escape-hatch message, exit 0. If scope is a list → compute the set difference (staged minus scope); empty diff → `rm -f "$(git rev-parse --git-dir)/COMMIT_SCOPE"` and exit 0; non-empty diff → emit reject block from §4, exit 1. If scope unset → count staged files and unique top-level directories (first path component via `awk -F/ '{print $1}' | sort -u`); if files > 10 OR dirs > 3, emit warning block from §4, exit 0; else silent exit 0. All output to stderr. Respects `pre-commit-*.sh` alphabetical ordering — filename prefix `pre-commit-staged-scope-guard.sh` lands after `secrets-guard.sh` and before `t-plan-structure.sh`, which is the desired ordering. DoD: hook executable, passes all five Task 1 cases, and a manual `git commit` in the live repo with two staged files + scoped to one is rejected cleanly. <!-- orianna: ok -->

3. **install-hooks.sh header update** — `kind: chore`, `estimate_minutes: 5`. Files: `scripts/install-hooks.sh`. Detail: Add a row for `pre-commit-staged-scope-guard.sh` in the header comment enumeration, placed alphabetically after secrets-guard and before t-plan-structure. No code changes — the existing glob `pre-commit-*.sh` picks the new hook up automatically. Re-run `scripts/install-hooks.sh` locally and confirm the `[install-hooks] Sub-hooks active:` enumeration at script end includes the new file. DoD: header comment accurate, local re-install confirms auto-pickup. <!-- orianna: ok -->

4. **Docs: key-scripts.md** — `kind: chore`, `estimate_minutes: 5`. Files: `architecture/key-scripts.md`. Detail: Add a row for `scripts/hooks/pre-commit-staged-scope-guard.sh` in the hooks table matching the four-column pattern (path, installed-via, description, exit codes). Description references the two incident commits and the `STAGED_SCOPE` contract. Link the follow-up plan stub from the Test plan section. DoD: table entry renders cleanly, cross-reference present. <!-- orianna: ok -->

5. **Follow-up stub** — `kind: chore`, `estimate_minutes: 5`. Files: `plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md` (stub). Detail: Minimal frontmatter + one-paragraph context pointing back to this plan, tasking the agent-definition sweep to teach Yuumi, Ekko, Syndra, Talon, Viktor, Jayce to set `STAGED_SCOPE` before `git commit`. `status: proposed`, `complexity: quick`, `tests_required: false`. This is a stub — it does not need to be Orianna-signed today, only tracked. DoD: stub file exists in the proposed personal directory, discoverable via `ls`. <!-- orianna: ok -->

**Task count:** 5. **Total estimate:** 60 minutes.

## Test plan

Invariants protected:

- **I1 — Hard block on out-of-scope paths.** When `STAGED_SCOPE` is a non-empty, non-`*` list and any staged path is outside it, exit 1 with the offending paths echoed. Covered by Task 1 Case A.
- **I2 — Unscoped trivial commits pass silently.** No scope, ≤10 files, ≤3 dirs → exit 0, no stderr. Covered by Task 1 Case B.
- **I3 — Unscoped bulk commits warn (non-blocking).** No scope, >10 files or >3 dirs → exit 0 with warning to stderr. Covered by Task 1 Case C.
- **I4 — Escape hatch works and logs loudly.** `STAGED_SCOPE=*` → exit 0 with loud stderr log, regardless of file count. Covered by Task 1 Case D.
- **I5 — `.git/COMMIT_SCOPE` is cleared on successful match.** Prevents stale scope leaking into the next commit. Covered by Task 1 Case E. <!-- orianna: ok -->
- **I6 — Hook auto-registers via existing dispatcher.** The `pre-commit-*.sh` glob in `scripts/install-hooks.sh` picks up the new file without code changes. Covered manually in Task 3 DoD.

The Task 1 test script is invoked directly (not via the dispatcher) so it runs identically in CI and locally, independent of hook installation state. Register it in `scripts/hooks/test-hooks.sh` if that runner enumerates tests — verify during Task 1 and include the registration in the Task 1 commit if the runner is enumeration-based.
