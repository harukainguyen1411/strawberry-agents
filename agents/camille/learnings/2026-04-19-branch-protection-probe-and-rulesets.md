# 2026-04-19 — Branch protection probe and ruleset-vs-classic bypass model

## Context
Ekko's probes on `harukainguyen1411/strawberry-app` `main` returned "no protection configured" — contradicting migration memory that claimed protection had been applied. Verified independently and authored restoration recipe.

## Findings

1. **No protection, no rulesets, nothing.** Three independent probes (REST branches/protection, GraphQL branchProtectionRules, REST rulesets) all returned empty / 404. The migration plan §4 step 3.4 (Caitlyn's branch-protection apply) was never executed; `.github/branch-protection.json` and `scripts/setup-branch-protection.sh` are staged but the `PUT` call never happened.

2. **Three distinct protection APIs.** Always probe all three before concluding state:
   - `GET /repos/{o}/{r}/branches/{b}/protection` — classic branch protection.
   - GraphQL `branchProtectionRules` — same data, different surface. Same empty result when classic is unset.
   - `GET /repos/{o}/{r}/rulesets` — separate system. Does NOT surface on classic endpoints. A repo with rulesets-only will return 404 on the classic endpoint while being fully protected.

3. **Classic protection vs ruleset bypass models.**
   - Classic: `enforce_admins: bool` is the only bypass knob. All-or-nothing for admins. Works today if the bypass target is admin and the non-bypass target is non-admin, but fragile: any future admin promotion silently grants bypass.
   - Rulesets: `bypass_actors[]` is explicit per actor ID with `bypass_mode: "always" | "pull_request"`. Role-change-resilient and auditable.
   - **Prefer rulesets for any config where per-actor bypass asymmetry matters.**

4. **Required status context strings must match the `job.name:` exactly, not the workflow name.** Cross-check against a recent PR's `statusCheckRollup` — workflow name and job name frequently differ (e.g. `TDD Gate` workflow, `xfail-first check` job). The 2026-04-17 enforcement plan §1 got this right; the MyApps test suite is a good example where one workflow emits two job-name contexts (`Unit tests (Vitest)`, `E2E tests (Playwright / Chromium)`).

5. **2FA status is not agent-queryable.** `GET /users/{username}` does NOT include `two_factor_authentication` in the public response. It only appears on `GET /user` when authenticated as that user. For security gating on "does user X have 2FA?", this must be a human-confirmation step, not automated.

6. **Ruleset payload gotchas.**
   - `required_linear_history` rule object conflicts with CLAUDE.md rule 11 (never rebase, always merge). Leave it out of the rules array.
   - `required_signatures` is not in the enforcement plan — don't smuggle it in.
   - Status checks go in `rules[].parameters.required_status_checks[]` as objects with `context` key, not bare strings.

## Applied to
- `plans/proposed/2026-04-19-branch-protection-restore.md`
