---
status: proposed
owner: camille
date: 2026-04-19
title: Branch protection restore for harukainguyen1411/strawberry-app — ruleset with owner bypass
links:
  - plans/approved/2026-04-17-branch-protection-enforcement.md
  - plans/approved/2026-04-19-public-app-repo-migration.md
---

# Branch Protection Restore — strawberry-app

## 1. Verified current state (2026-04-19)

Probes run against `harukainguyen1411/strawberry-app`:

| Probe | Result |
|-------|--------|
| `gh api repos/harukainguyen1411/strawberry-app/branches/main/protection` | `404 Not Found` — no classic protection configured |
| `gh api graphql { branchProtectionRules }` | `nodes: []` — confirms no classic rules |
| `gh api repos/harukainguyen1411/strawberry-app/rulesets` | `[]` — no rulesets either |
| Collaborators | `Duongntd`: role `write` (push, triage). `harukainguyen1411`: role `admin` (owner) |
| Repo settings | `visibility: public`, `delete_branch_on_merge: true`, `two_factor_requirement_enabled: null` |
| `.github/branch-protection.json` | Present, full 5-context spec (matches §1 of 2026-04-17 enforcement plan) |
| `scripts/setup-branch-protection.sh` | Present and correctly shaped — **never executed against the new repo** |

**Diagnosis.** The migration plan §4 step 3.4 (Caitlyn) called for running `scripts/setup-branch-protection.sh` against the new repo after the first green workflow run. That step appears to have been skipped. The JSON template and script are in place; only the `PUT` API call has not been made. This is a Phase-3 exit-criterion regression — item 3 of the §9 migration sign-off ("Branch protection on strawberry-app matches ... §1 ... 1 required review, `enforce_admins` per that plan") is currently failing.

Contradicting the earlier migration memory entry, **no branch protection exists** on `main`. Ekko's probes were correct.

Recent PR status checks (observed on PR #47, merged 2026-04-19) — exact job-name context strings that can be required:

- `xfail-first check` (workflow: `TDD Gate`)
- `regression-test check` (workflow: `TDD Gate`)
- `unit-tests` (workflow: `Unit Tests`)
- `Playwright E2E` (workflow: `E2E (Playwright)`)
- `QA report present (UI PRs)` (workflow: `PR Body Linter`)
- `validate-scope` (workflow: `Validate Scope`)
- `Lint + Test + Build (affected)` (workflow: `CI`)
- `check-no-hardcoded-slugs` (workflow: `Lint — no hardcoded repo slugs`)
- `Unit tests (Vitest)` (workflow: `MyApps — Tests (unit + E2E)`)
- `E2E tests (Playwright / Chromium)` (workflow: `MyApps — Tests (unit + E2E)`)

## 2. Target state

Restore the protection defined by `plans/approved/2026-04-17-branch-protection-enforcement.md` **with one deviation**: split the enforcement actor model so that the human owner account can bypass all gates while the agent account cannot.

### 2.1 Why rulesets, not classic protection

Classic branch protection expresses admin bypass as a single `enforce_admins: bool`. With classic rules:

- `enforce_admins: true` → everyone (including `harukainguyen1411`) must satisfy checks and reviews. Rules out owner bypass — wrong.
- `enforce_admins: false` → all admins bypass. `Duongntd` is currently `write` (not admin), so this **would work today** — `harukainguyen1411` bypasses, `Duongntd` does not. However it is a fragile coupling: the day `Duongntd` is promoted to admin (or any other admin is added), the agent gains bypass with no audit trail. It also provides no per-actor bypass visibility.

Rulesets (GitHub's newer API) express bypass as an explicit `bypass_actors` list keyed on actor IDs, with `bypass_mode: "always"` or `"pull_request"`. This makes the owner bypass **explicit and role-change-resilient** and aligns with GitHub's recommended direction for new rule configuration.

**Recommendation:** ruleset on `main`, `bypass_actors` pinned to `harukainguyen1411`'s user ID (`273533031`), with `Duongntd` not in the bypass list.

### 2.2 Rules applied by the ruleset

| Rule | Source | Value |
|------|--------|-------|
| `required_status_checks` | 2026-04-17 enforcement plan §1 | 5 contexts listed below, `strict_required_status_checks_policy: true` |
| `pull_request` | 2026-04-17 enforcement plan §2 | 1 required approving review, dismiss stale, require last push approval, no code owner review |
| `non_fast_forward` | prevent force push | `true` |
| `deletion` | prevent branch deletion | `true` |
| `required_linear_history` | rule 11 (always merge) | `false` — must remain false |
| `required_conversation_resolution` | enforcement plan §5 | `true` |

Required status contexts (exact strings, cross-checked against PR #47):

1. `xfail-first check`
2. `regression-test check`
3. `unit-tests`
4. `Playwright E2E`
5. `QA report present (UI PRs)`

Open decision — see §5 Q1 below: whether to additionally require `validate-scope`, `Lint + Test + Build (affected)`, `check-no-hardcoded-slugs`, and the MyApps vitest/Playwright pair. The 2026-04-17 plan only specified five; the recent PR stream runs ten. Duong to decide.

### 2.3 Bypass model

| Actor | Path | Status checks | Reviews | Force push | Delete branch |
|-------|------|---------------|---------|------------|---------------|
| `harukainguyen1411` (user ID 273533031) | `bypass_actors[]` with `bypass_mode: "always"` | bypass | bypass | bypass (non_fast_forward waived) | bypass |
| `Duongntd` (agent) | not listed | enforced | enforced | blocked | blocked |
| Any other actor | not listed | enforced | enforced | blocked | blocked |

`bypass_mode: "always"` (versus `"pull_request"`) means the owner can merge directly from the UI/CLI without even needing a PR. That is the "routine shepherding" mode Duong requested. If routine shepherding should still go through a PR but skip reviews/checks, change to `"pull_request"` — see §5 Q2.

## 3. Recipe — exact commands

All commands run as `harukainguyen1411` (the repo admin) or any token with the `Administration: write` permission on `harukainguyen1411/strawberry-app`.

### 3.1 Create the ruleset

```bash
cat > /tmp/main-ruleset.json <<'JSON'
{
  "name": "main-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "bypass_actors": [
    {
      "actor_id": 273533031,
      "actor_type": "User",
      "bypass_mode": "always"
    }
  ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "required_linear_history",
      "parameters": {}
    },
    {
      "type": "required_signatures"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "xfail-first check" },
          { "context": "regression-test check" },
          { "context": "unit-tests" },
          { "context": "Playwright E2E" },
          { "context": "QA report present (UI PRs)" }
        ]
      }
    }
  ]
}
JSON
```

Two caveats in the payload above — the executor must resolve before `PUT`:

- **`required_linear_history`** must NOT be in the rules array if the repo uses merge commits (rule 11 of CLAUDE.md). Remove that rule object before applying. It is included here only to flag that the ruleset schema supports it; do not enable.
- **`required_signatures`** is NOT in the 2026-04-17 enforcement plan. The `scripts/setup-branch-protection.sh` stub does not set it. Remove before applying unless Duong explicitly wants commit signing (§5 Q3).

Corrected payload (what to actually send):

```bash
cat > /tmp/main-ruleset.json <<'JSON'
{
  "name": "main-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "bypass_actors": [
    { "actor_id": 273533031, "actor_type": "User", "bypass_mode": "always" }
  ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "xfail-first check" },
          { "context": "regression-test check" },
          { "context": "unit-tests" },
          { "context": "Playwright E2E" },
          { "context": "QA report present (UI PRs)" }
        ]
      }
    }
  ]
}
JSON

gh api repos/harukainguyen1411/strawberry-app/rulesets \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  --input /tmp/main-ruleset.json

rm /tmp/main-ruleset.json
```

### 3.2 Verify

```bash
# Ruleset exists and is active
gh api repos/harukainguyen1411/strawberry-app/rulesets \
  --jq '.[] | {id, name, enforcement, target}'

# Full ruleset detail (substitute RULESET_ID from previous output)
gh api repos/harukainguyen1411/strawberry-app/rulesets/<RULESET_ID>

# Classic protection endpoint still returns 404 (expected — rulesets live on a different endpoint)
gh api repos/harukainguyen1411/strawberry-app/branches/main/protection || echo "expected 404"

# Smoke: open a throwaway PR from a branch and confirm it cannot merge without checks and review
gh pr create --base main --head throwaway-rs-test --title "chore: ruleset smoke" --body "verify protection"
# Expect: "Merging is blocked. Required statuses must pass. 1 approving review is required."
```

### 3.3 Rollback

```bash
# Remove the ruleset (restores no-protection state)
gh api repos/harukainguyen1411/strawberry-app/rulesets/<RULESET_ID> -X DELETE
```

## 4. Security posture note

- `harukainguyen1411` 2FA status cannot be queried directly by agents (`two_factor_authentication` field on `GET /users/{username}` is not publicly exposed; it is only visible via `GET /user` when authenticated as that user). The repo's `two_factor_requirement_enabled` field is `null`. **Blocker question Q4 below.**
- Giving bypass to an account without 2FA on a public repo is a meaningful risk: any credential compromise on that account can force-push, delete history, or merge malicious changes to `main`. The bypass configuration proposed here is security-appropriate **only** if `harukainguyen1411` has 2FA enabled. Duong must confirm before executing §3.1.
- The fine-grained PAT used by agent sessions under `Duongntd` has `repo` scope. Rotate on a schedule (quarterly minimum) and store only via `secrets/encrypted/*.age`.
- `delete_branch_on_merge: true` is already on — good. `required_signatures` is off — fine; orthogonal to this plan.

## 5. Open questions for Duong

- **Q1 — Status check scope.** The 2026-04-17 plan required five contexts. PR #47 ran ten. Do you want to require only the original five (rules 12/13/14/15/16 enforcement) or add the four-to-five more that are currently green on every PR (`validate-scope`, `Lint + Test + Build (affected)`, `check-no-hardcoded-slugs`, MyApps vitest, MyApps Playwright)? Recommendation: keep to the five until there is an explicit CLAUDE.md rule backing each added context. Requiring informational checks causes red PRs without corresponding discipline gain.
- **Q2 — Bypass mode.** `bypass_mode: "always"` lets `harukainguyen1411` push directly to `main`. `"pull_request"` forces a PR but skips reviews/checks on that PR. Which do you want for routine shepherding? Recommendation: `"always"` — the whole point is frictionless owner shepherding.
- **Q3 — Signed commits.** Out of scope per 2026-04-17 §10 ("signed commits requirement. Orthogonal; handle separately if at all"). Not included. Confirm you do not want it added now.
- **Q4 — 2FA confirmation for `harukainguyen1411`.** Required before §3.1 executes. If 2FA is off, enable it first.
- **Q5 — Script update.** `scripts/setup-branch-protection.sh` in strawberry-app still uses the classic-protection API with `enforce_admins: true`. That conflicts with the owner-bypass goal. Should a follow-up rewrite that script to apply the ruleset above (and the executor of this recipe additionally author that rewrite), or leave the script as the break-glass "nuclear" protection and apply this ruleset separately? Recommendation: rewrite the script to apply the ruleset, deprecate the classic-protection path. The rewrite is outside this plan's scope — file a follow-up.

## 6. Non-goals

- CODEOWNERS file — deferred, same reasoning as 2026-04-17 §10.
- Merge queue — overkill.
- Protection on non-`main` branches — out of scope.
- Updating the private `Duongntd/strawberry` repo's protection — this plan covers strawberry-app only.
