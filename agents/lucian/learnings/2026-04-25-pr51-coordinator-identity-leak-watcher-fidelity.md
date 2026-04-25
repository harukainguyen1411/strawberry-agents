---
date: 2026-04-25
agent: lucian
topic: PR #51 fidelity review — coordinator identity leak + watcher fix
verdict: APPROVE
---

# PR #51 fidelity — coordinator identity leak + watcher subprocess fix

## Verdict
APPROVE under `strawberry-reviewers`. Two-commit branch, textbook Rule 12 xfail-first ordering.

## What clinched it
- Dual-state Rule 12 verification by hand: cloned PR branch, ran tests at HEAD (11/11 pass), then rolled scripts/hooks + scripts/mac + scripts/windows + coordinator-boot.sh back to xfail-commit's parent and reran tests with the new test files in place — 4 assertions fail (the four xfail cases), proving tests genuinely encode the failure modes.
- `.gitignore:106` lookup + `git check-ignore -v` confirms `.coordinator-identity` per-checkout-state status.
- Three-tier chain in both watcher hooks documented in header AND implemented in body — header drift is a common subtle defect; matched literally here.

## Reusable techniques
- **Dual-state Rule 12 check pattern.** Clone PR branch shallow → run tests at HEAD (expect pass) → `git checkout <xfail-commit-parent> -- <impl-paths>` keeping test files at HEAD → rerun (expect fail). Faster than re-cloning per state, and isolates "the new tests catch the regression" from "tests pass on impl". Use this whenever a plan declares specific failure modes.
- **Plan-§Test-plan-N to test-file-name 1:1 mapping table.** Build the table early; reviewers downstream re-use it. Caught nothing new here but accelerated drafting the review body.

## Drift notes I flagged but did not block on
- `coordinator-boot.sh` correctly does NOT subshell-wrap its exports (alias path already invokes via `bash`). Plan distinguishes this in §Background.
- Test 1 Part A's `REPO_DIR` resolves wrong under dot-source (sourced $0 = "bash"); test acknowledges this in a comment and still validates the leak property under test. Acceptable.

## Hooks etc
- `scripts/reviewer-auth.sh gh api user` returned `strawberry-reviewers` (correct lane). Submitted via `gh pr review --approve` — no self-approval block since reviewer ≠ author (`duongntd99`).
