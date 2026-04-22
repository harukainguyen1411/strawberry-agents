---
status: implemented
concern: personal
owner: karma
complexity: quick
orianna_gate_version: 2
tests_required: true
created: 2026-04-22
architecture_impact: none
orianna_signature_approved: "sha256:b131ac20380ce60c121040e8d3ddf464070d934bcecfb35308c42349c5de0024:2026-04-22T13:40:39Z"
orianna_signature_in_progress: "sha256:b131ac20380ce60c121040e8d3ddf464070d934bcecfb35308c42349c5de0024:2026-04-22T13:42:23Z"
orianna_signature_implemented: "sha256:b131ac20380ce60c121040e8d3ddf464070d934bcecfb35308c42349c5de0024:2026-04-22T13:43:42Z"
---

# Work-scope reviewer anonymity

## Context

Work-concern PRs land on `~/Documents/Work/mmp/workspace/` <!-- orianna: ok -- prospective deploy target path --> (remote `missmp/workspace` <!-- orianna: ok -- prospective remote name -->), where Duong's MMP teammates and colleagues can see every review, comment, and commit message. Agent-system internals (Senna, Lucian, Evelynn, Sona, `strawberry-reviewers`, `strawberry-reviewers-2`, `harukainguyen1411`, `duongntd99`, `*@anthropic.com`, `Co-Authored-By: Claude` trailers) are private tooling and must not leak into those work-visible surfaces. Personal-concern PRs (the `strawberry-app` repo) are unaffected — Duong owns that audience.

The enforcement must cover three surfaces: (1) commit messages on work-scope branches, (2) PR review bodies posted via `scripts/reviewer-auth.sh`, (3) PR comments posted via `gh pr comment` by reviewer lanes. The universal `Co-Authored-By: Claude` ban already exists repo-wide (rule in `~/.claude/CLAUDE.md` <!-- orianna: ok -- user-global CLAUDE.md, not repo file -->); this plan amplifies it specifically in the work-scope hook and adds an identity/handle denylist on top.

**Canonical scope signal (chosen):** git remote `origin` URL of the current working tree. If `origin` matches `missmp/*` <!-- orianna: ok -- prospective regex pattern --> (regex `[:/]missmp/` <!-- orianna: ok -- prospective regex pattern -->), the hook is operating on a work-scope repo and enforces. This works uniformly for (a) pre-commit inside the `workspace` repo, (b) `scripts/reviewer-auth.sh` which can resolve the target PR's repo via `gh pr view --json headRepository,baseRefName`. It avoids plan-frontmatter coupling (plans live in `strawberry-agents`, not in the repo being committed to) and avoids fragile path heuristics like `apps/**` <!-- orianna: ok -- glob pattern example, not a literal path -->.

## Tasks

### T1 — Denylist module (shared library)

- Kind: impl
- Estimate_minutes: 20
- Files: `scripts/hooks/_lib_reviewer_anonymity.sh` (new). <!-- orianna: ok -- new file, does not exist yet -->
- Detail: POSIX-sh library exposing `anonymity_scan_text <stdin>` (returns 0 clean, 1 hit; prints matched tokens to stderr) and `anonymity_is_work_scope <dir>` (checks `git -C <dir> remote get-url origin` against `[:/]missmp/` <!-- orianna: ok -- prospective regex pattern -->). Denylist tokens sourced from a single table at top: agent first-names (Senna, Lucian, Evelynn, Sona, Viktor, Jayce, Azir, Swain, Orianna, Karma, Talon, Ekko, Heimerdinger, Syndra, Akali, Ahri, Ori), github handles (`strawberry-reviewers`, `strawberry-reviewers-2`, `harukainguyen1411`, `duongntd99`), email patterns (`*@anthropic.com`), trailer patterns (`Co-Authored-By: Claude`). Word-boundary matching (grep `-wi`) to avoid false positives on substrings. Library is sourced, not executed.
- DoD: library file exists; `bash -n` clean; direct `source` + invocation from a scratch test passes for both positive and negative inputs.

### T2 — Pre-commit hook (work-scope message scan)

- Kind: impl
- Estimate_minutes: 15
- Files: `scripts/hooks/pre-commit-reviewer-anonymity.sh` (new), `scripts/install-hooks.sh`. <!-- orianna: ok -- new file, does not exist yet -->
- Detail: New hook runs only when `anonymity_is_work_scope "$(git rev-parse --show-toplevel)"` returns true. Reads `.git/COMMIT_EDITMSG` (or `$1` when invoked as `commit-msg` — use `pre-commit-` prefix but dispatch on `COMMIT_EDITMSG` for simplicity matching existing hook conventions). On hit: print one-line diagnostic per matched token and a guidance block pointing at `architecture/pr-rules.md` <!-- orianna: ok -- target docs file, does not exist yet --> `#work-scope-anonymity`, exit 1. Update `scripts/install-hooks.sh` comment block to list the new hook.
- DoD: hook installed via `scripts/install-hooks.sh`; manual commit with `Co-Authored-By: Claude` on a test branch in `~/Documents/Work/mmp/workspace/` <!-- orianna: ok -- prospective deploy target path --> is rejected; same commit in `strawberry-agents` passes.

### T3 — `scripts/reviewer-auth.sh` pre-submit scan

- Kind: impl
- Estimate_minutes: 20
- Files: `scripts/reviewer-auth.sh`.
- Detail: Before `exec gh "$@"`, if the subcommand is `pr review` or `pr comment`, extract `--body` (or `-b`) value and PR number. Resolve PR's head repo via `gh pr view <num> --json headRepository -q .headRepository.nameWithOwner` using the already-decrypted token (pass via `tools/decrypt.sh --exec` wrapping a small inline scan step, then chain to the real gh call). If head repo matches `missmp/*` <!-- orianna: ok -- prospective regex pattern -->, pipe the body through `anonymity_scan_text`; on hit, exit 3 with diagnostic and do NOT post. Clean bodies proceed unchanged. Personal-scope PRs skip the scan entirely.
- DoD: calling `scripts/reviewer-auth.sh gh pr review <work-pr> --body "-- Lucian"` exits non-zero with diagnostic; same call on a personal-scope PR posts normally; a work-scope call with a clean body posts normally.

### T4 — Docs

- Kind: docs
- Estimate_minutes: 15
- Files: `architecture/pr-rules.md` <!-- orianna: ok -- target docs file, does not exist yet -->, `architecture/cross-repo-workflow.md` <!-- orianna: ok -- target docs file, does not exist yet -->, `.claude/agents/senna.md`, `.claude/agents/lucian.md`.
- Detail: Add a `## Work-scope anonymity` section to `architecture/pr-rules.md` <!-- orianna: ok -- target docs file, does not exist yet --> listing the denylist surface, scope signal, and enforcement paths. Cross-link from `architecture/cross-repo-workflow.md` <!-- orianna: ok -- target docs file, does not exist yet -->. Add a one-paragraph reminder to Senna and Lucian agent defs: "On work-scope PRs (target repo `missmp/*` <!-- orianna: ok -- prospective regex pattern -->), never include agent names, reviewer handles, `harukainguyen1411`/`duongntd99`, `*@anthropic.com`, or `Co-Authored-By: Claude` trailers in review bodies, comments, or commit messages. Sign reviews with a generic role tag (e.g. `-- reviewer`) instead of an agent name. `scripts/reviewer-auth.sh` enforces; treat a rejection as a drafting bug."
- DoD: all four files updated; `architecture/pr-rules.md` <!-- orianna: ok -- target docs file, does not exist yet --> section is anchor-linkable as `#work-scope-anonymity`.

### T5 — Tests (xfail-first, then implementation)

- Kind: test
- Estimate_minutes: 25
- Files: `scripts/hooks/test-pre-commit-reviewer-anonymity.sh` (new), `scripts/__tests__/test-reviewer-auth-anonymity.sh` (new). <!-- orianna: ok -- new files, do not exist yet -->
- Detail: Per rule 12, land xfail first on the branch (mark with `TDD-PLAN: plans/proposed/personal/2026-04-22-work-scope-reviewer-anonymity.md`). Fixtures:
  - fixture-a: temp repo with `origin=missmp/fake` <!-- orianna: ok -- prospective test fixture value --> and commit msg containing `Senna` → hook rejects.
  - fixture-b: same repo + clean commit msg → hook passes.
  - fixture-c: temp repo with `origin=harukainguyen1411/strawberry-app` <!-- orianna: ok -- prospective test fixture value --> and commit msg containing `Senna` → hook passes (scope discrimination).
  - fixture-d: `scripts/reviewer-auth.sh` dry-run wrapper (env `ANONYMITY_DRY_RUN=1` skips actual gh exec after scan) on a mocked work-scope PR body containing `strawberry-reviewers-2` → exit 3.
  - fixture-e: same wrapper on a clean body → exit 0.
  - fixture-f: same wrapper on a personal-scope PR with `Senna` in body → exit 0 (scope discrimination).
  Note: T3 must add the `ANONYMITY_DRY_RUN` env hook so fixture-d through fixture-f can run without live PRs; that is an explicit T3 DoD addendum — add to T3 before writing implementation.
- DoD: both test scripts pass locally; all six fixtures green; `scripts/hooks/pre-push-tdd.sh` <!-- orianna: ok -- prospective hook path --> recognises the xfail tag; post-implementation the xfail is flipped to live.

## Test plan

The tests in T5 protect three invariants:

1. **Scope discrimination** — enforcement fires exactly when `origin` matches `missmp/*` <!-- orianna: ok -- prospective regex pattern -->; never on personal-concern repos. Fixtures fixture-a vs fixture-c for the hook, fixture-d vs fixture-f for reviewer-auth.
2. **Denylist coverage** — at least one fixture per denylist category (agent name, reviewer handle, trailer) rejects; exhaustive per-token coverage is not required, but the library's token table is the single source of truth and is unit-tested indirectly via the hook tests.
3. **Clean-path transparency** — fixtures fixture-b and fixture-e prove that clean inputs pass through unchanged; reviewer-auth must still `exec gh` with the original argv when the scan clears.

Test runner: the two scripts above run standalone (`bash scripts/hooks/test-pre-commit-reviewer-anonymity.sh`) and are wired into `scripts/hooks/test-hooks.sh` for batch execution.

## Open questions

- Retroactive cleanup of existing work-scope PRs is **out of scope** for this plan. Prospective-only per Duong's brief phrasing ("add to PR reviewers ... never have"). A separate plan can sweep history if needed.
- Optional CI post-open rescan (brief item 3) is **deferred**. The two enforcement paths (pre-commit + reviewer-auth) cover every sanctioned write path; CI rescan is a belt-and-braces measure worth its own plan if a bypass is ever observed.

## Architecture impact

No architecture/ files modified. New scripts added to scripts/hooks/ (pre-commit-reviewer-anonymity.sh, _lib_reviewer_anonymity.sh). Documentation sections added to architecture/pr-rules.md and architecture/cross-repo-workflow.md as part of T4, but these are existing architecture files updated in-place, not structural changes to the architecture layer.

## Test results

- PR #25 merged at e6d3ac2: https://github.com/harukainguyen1411/strawberry-agents/pull/25
- All required checks green at merge.

## References

- `scripts/reviewer-auth.sh` — existing reviewer identity wrapper
- `scripts/hooks/pre-commit-staged-scope-guard.sh` — reference for hook structure
- `scripts/install-hooks.sh` — dispatcher install
- `architecture/pr-rules.md` <!-- orianna: ok -- target docs file, does not exist yet --> — target for docs update
- `~/.claude/CLAUDE.md` <!-- orianna: ok -- user-global CLAUDE.md, not repo file --> — existing global AI-attribution ban (amplified here)
- CLAUDE.md rule 12 — TDD gate governs T5 ordering
