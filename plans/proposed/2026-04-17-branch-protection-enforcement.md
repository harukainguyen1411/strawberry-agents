---
status: proposed
owner: pyke
date: 2026-04-17
title: Branch protection enforcement — wire required checks, reviews, and admin guardrails
---

# Branch Protection Enforcement

Current `main` branch protection is a stub: `required_status_checks: null`, `required_pull_request_reviews: null`, `enforce_admins: false`. The plan-approved rules 14, 15, 16 in `CLAUDE.md` (TDD gate, E2E, QA report) all claim "required check via branch protection" but nothing is actually wired. This is how PR #117 (my own TDD plan implementation) and PR #126 (Shen's bash-guard fix) were `--admin`-merged with zero required checks reporting — neither had a plan-faithfulness or correctness gate on the actual merge.

This plan fixes the branch-protection record and adds a review-discipline invariant so agents cannot `--admin`-merge again.

---

## 1. Required status checks

Each contexts string must match a GitHub Actions **job name** (not workflow name) exactly.

| Rule | Workflow file | Job `name:` | Required context string |
|------|---------------|-------------|-------------------------|
| 12 (xfail-first)      | `.github/workflows/tdd-gate.yml` | `xfail-first check`        | `xfail-first check`        |
| 13 (regression test)  | `.github/workflows/tdd-gate.yml` | `regression-test check`    | `regression-test check`    |
| 14 (unit tests in CI) | **new** `.github/workflows/unit-tests.yml` (Shen to author) | `unit-tests`               | `unit-tests`               |
| 15 (E2E)              | `.github/workflows/e2e.yml`       | `Playwright E2E`           | `Playwright E2E`           |
| 16 (QA report)        | `.github/workflows/pr-lint.yml`   | `QA report present (UI PRs)` | `QA report present (UI PRs)` |

Rule 14 currently has only a client-side pre-commit hook; the plan text says "installed via `scripts/install-hooks.sh`" which is not verifiable on a PR. **Shen must add a CI mirror** — `unit-tests.yml` that runs the same per-package `test:unit` discovery against the PR branch and produces a required status. Without this, rule 14 is unenforced at merge time just like 15 and 16 were unenforced at protection time.

All five contexts must be configured with `strict: true` (branch must be up-to-date with base before merge) to prevent the "green-on-old-base" class of bypass.

**Non-blocking / never-required:**

- `TDD Gate / xfail-first check` on `push` events (non-PR) — informational only, never gates merge.
- `PR Body Linter` workflow-level status — only the specific job `QA report present (UI PRs)` is required; the workflow green-no-ops for non-UI PRs by design.

---

## 2. Required reviews

**Recommendation: option (a), second-account approval.** One required approving review from a user who is not the PR author.

Reasoning:

- **Option (b) "zero reviews, rely on status checks"** leaves no human (or agent) judgment gate. Status checks verify mechanical properties — plan-faithfulness, design-intent drift, and scope creep are not machine-detectable. PR #117 shows why: my own blockers B1 and B2 would never have been caught by any status check — they required a plan-faithfulness reader. Drop this option.
- **Option (c) CODEOWNERS → bot account.** Adds infrastructure (bot account, PAT management, CODEOWNERS syntax drift) without changing the underlying "one human, blocked from self-approving" problem. Defer.
- **Option (a) second-account approval.** Already half-wired in `scripts/setup-branch-protection.sh` step 2. Duong's second GitHub account is `harukainguyen1411` (collaborator); `Duongntd` is the admin/primary. The `harukainguyen1411` account is granted `push` permission and holds a fine-grained PAT used by agent sessions. Every PR requires one approving review from `harukainguyen1411`. When Evelynn or any agent opens a PR from `Duongntd`, they must coordinate with an agent session running under `harukainguyen1411` to review and approve. This creates a real independent-agent review gate that matches the existing agent-delegation model (reviewer subagent spawned via Evelynn).

Required-reviews configuration:

```json
"required_pull_request_reviews": {
  "required_approving_review_count": 1,
  "dismiss_stale_reviews": true,
  "require_code_owner_reviews": false,
  "require_last_push_approval": true
}
```

`require_last_push_approval: true` is important — it forces re-review after any new push, so a rubber-stamp approval followed by "just one more fix" does not slip through.

Second account is `harukainguyen1411` (collaborator, confirmed). If that account has not been authenticated in agent sessions, `scripts/setup-agent-git-auth.sh` is the intended path (see `architecture/key-scripts.md`). Shen's existing script still references the placeholder `SECOND_ACCOUNT` in the echo lines — replace with `harukainguyen1411` during the rewrite.

---

## 3. Admin enforcement

**Recommendation: `enforce_admins: true`.**

This prevents `gh pr merge --admin` bypass. Combined with the review requirement, it means every merge to main goes through the same status-checks + review gate, regardless of who runs it.

**Break-glass procedure** (for documented emergencies only, e.g. production on fire, required check workflow itself broken):

1. Duong (repo owner) runs `gh api repos/Duongntd/strawberry/branches/main/protection -X PATCH --input <patch-disabling-enforce-admins>`.
2. Performs the emergency merge with `gh pr merge --admin`.
3. Immediately re-enables `enforce_admins: true` via `bash scripts/setup-branch-protection.sh`.
4. Writes a post-incident note to `assessments/break-glass/YYYY-MM-DD-<slug>.md` covering: what broke, why break-glass was the right choice, what follow-up is needed to prevent recurrence.

This is a **human-only** procedure. Agents must not execute it under any circumstance.

---

## 4. Force push and deletion

Already disabled in the current stub record (`allow_force_pushes: false`, `allow_deletions: false`). Confirm these remain `false` in the rewritten script. No change needed.

Also add `required_linear_history: false` explicitly — rule 11 of CLAUDE.md says "never use `git rebase`, always merge," which requires merge commits, so linear history must NOT be required.

---

## 5. Rewrite of `scripts/setup-branch-protection.sh`

Replace the current stub payload with the full configuration. Shen to author; reference configuration below.

```bash
# scripts/setup-branch-protection.sh (target shape)
set -euo pipefail
REPO="${REPO:-Duongntd/strawberry}"
cat > /tmp/bp.json <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "xfail-first check",
      "regression-test check",
      "unit-tests",
      "Playwright E2E",
      "QA report present (UI PRs)"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
gh api "repos/$REPO/branches/main/protection" -X PUT \
  -H "Accept: application/vnd.github+json" --input /tmp/bp.json
rm /tmp/bp.json
```

`required_conversation_resolution: true` is a small add-on: reviewer-raised conversations must be resolved before merge. Cheap extra gate.

The second-account + auto-delete-branches + stale-branch-cleanup sections from the current script are orthogonal and should be retained, not deleted.

---

## 6. Retrospective — PR #117 and #126 admin-merges

**What happened.** Both PRs were merged from the same account that authored them, via `gh pr merge --admin`, bypassing what little protection existed (review was null, status checks were null, admin enforcement off). For PR #117 the reviewer (Pyke) had flagged B6 as a blocker and the follow-up commit `662d313` addressed it, but no gate verified that `662d313` was actually present in the merged commit or that any reviewer signed off on it.

**Why it mattered.** The plan I authored at `plans/approved/2026-04-17-tdd-workflow-rules.md` §3.4 and §4 rule 15 explicitly said "required check via branch protection" and "agents may never merge a red PR." Both statements presuppose a branch-protection record that is not null. Without that record, the plan's enforcement promise is paper-only — agents can run `--admin` and nothing stops them.

**What changes.** Sections 1–5 above wire the record. The new CLAUDE.md invariant below forbids `--admin` at the agent layer, so even if a gap reappears, agents will not exploit it.

---

## 7. CLAUDE.md invariant (new item 18)

Add under **Critical Rules — Universal Invariants**, preserving existing 1–17:

```
<!-- #rule-no-admin-merge -->
18. **Agents must NOT use `gh pr merge --admin` or any branch-protection bypass**, and
    must NOT merge a PR they authored. Every merge requires (a) all required status
    checks green, (b) one approving review from an account other than the PR author,
    and (c) no red required check. Break-glass admin merges are a human-only Duong
    procedure (see `plans/approved/2026-04-17-branch-protection-enforcement.md` §3).
```

Anchor: `#rule-no-admin-merge`. Rules 1–17 preserved.

---

## 8. Implementation order for Shen

1. Author `.github/workflows/unit-tests.yml` — CI mirror of the pre-commit unit-test hook, producing the `unit-tests` status context. Required before step 3 so the context actually exists when branch protection starts requiring it.
2. Rewrite `scripts/setup-branch-protection.sh` per §5.
3. Run `scripts/setup-branch-protection.sh` against the live repo (manual, Duong-initiated). Verify with `gh api repos/Duongntd/strawberry/branches/main/protection | jq '.required_status_checks, .required_pull_request_reviews, .enforce_admins'`.
4. Land CLAUDE.md rule 18 direct to main (plan-commit, `chore:` prefix).
5. Update `architecture/git-workflow.md` with the new review + required-checks model.
6. Smoke test: open a throwaway PR from a feature branch, confirm that (a) checks report, (b) merge is blocked without approval, (c) `--admin` is rejected.

---

## 9. Open questions

- **Second-account username.** Resolved: `harukainguyen1411` (collaborator). Replace `SECOND_ACCOUNT` throughout `scripts/setup-branch-protection.sh` with this value during the rewrite.
- **Bootstrap ordering for this PR's own merge.** This plan lands to main directly per rule 4, not via PR — so the protection record change does not block itself. The CLAUDE.md rule 18 edit is similarly a direct-to-main commit. No bootstrap loop.
- **Existing open PRs.** Any PR already open when protection lands will need to satisfy the new required checks (re-push to trigger) and gather one approval before merge. Expected one-time friction; not a design issue.
- **Agent session auth.** Review from the second account requires at least one agent session authenticated under that account. How Evelynn orchestrates "send this PR to the second-account session for review" is outside this plan's scope — likely a small addition to the agent-network protocol.

---

## 10. Non-goals

- CODEOWNERS file. Deferred — single-file review ownership is not useful when the reviewer pool is already `NOT author`.
- Merge queue. Overkill for a solo-operator repo.
- Signed commits requirement. Orthogonal; handle separately if at all.
- Retroactive review of commits already on main. Those are frozen history; focus is forward-only enforcement.
