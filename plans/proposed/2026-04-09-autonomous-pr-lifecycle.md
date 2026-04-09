---
title: Autonomous PR Lifecycle — Open, Review, Merge Without Duong
status: proposed
owner: pyke
created: 2026-04-09
---

# Autonomous PR Lifecycle

> Pyke, author. Rule 7 applies — this is a plan, not an execution. Evelynn assigns implementers after Duong approves.
>
> Goal: Duong never touches a PR. Agents open them, agents review them, agents merge them. The only human loop is the plan approval gate (which is upstream of this system — by the time code reaches this pipeline, the plan is already in `plans/approved/`).

---

## 1. Problem

GitHub will not allow a user to approve or merge their own pull request when branch protection requires a review. Today, every Strawberry commit that goes through a PR is authored, pushed, and reviewed by the single identity `harukainguyen1411`. That means either:

- branch protection is off (current state on `main`) and any agent can merge anything, which defeats the whole point of a review gate; or
- branch protection is on with "required reviews = 1" and the pipeline deadlocks because the author can't self-approve.

We need at least **two distinct GitHub identities** in the loop, and a structured review protocol so "approved" means something.

---

## 2. Two-Identity Architecture

### 2.1 Options considered

| Option | Author identity | Reviewer/merger identity | Verdict |
|---|---|---|---|
| A. Second personal GitHub account + classic PAT | `harukainguyen1411` | `strawberry-bot` (new account) | **Recommended.** Cheapest, lowest ceremony, fits existing PAT flow. |
| B. GitHub App installed on repo | `harukainguyen1411` | App bot (`strawberry-bot[bot]`) | Cleaner attribution, scoped permissions, but requires hosting the App manifest, signing webhooks, and handling installation tokens. Over-engineered for one repo. |
| C. CodeRabbit as the approver | `harukainguyen1411` | `coderabbitai[bot]` | CodeRabbit does not cast **approving** reviews that satisfy branch-protection "required reviews" — it posts comments. Cannot be the merge gate on its own. Keep as an **additional** check, not the approver. |
| D. Duong's personal account as reviewer | agents | `Duongntd` | Violates the goal ("Duong will not touch PRs"). Rejected. |

**Recommendation: Option A.** Create a dedicated `strawberry-bot` GitHub account. Agents push and open PRs as `harukainguyen1411`. `strawberry-bot` reviews, approves, and merges. CodeRabbit runs in parallel as an automated quality check and is required-but-non-blocking-on-taste.

### 2.2 Identity responsibilities

**`harukainguyen1411` — the Worker.**
- Pushes commits from agents (current behavior, unchanged).
- Opens PRs via `gh pr create`.
- Requests reviews from `strawberry-bot` and triggers CodeRabbit.
- Cannot approve its own PRs. Cannot merge into `main`.

**`strawberry-bot` — the Gatekeeper.**
- Receives review requests.
- Runs Lissandra and Syndra review skills headlessly under its credentials.
- Posts the structured review report as a PR comment.
- Casts a formal GitHub `APPROVE` review only if the structured checklist passes.
- Triggers merge via `gh pr merge --auto --squash` once all required checks are green.
- Is the only identity allowed to merge to `main` (enforced by branch protection, see §3).

**`coderabbitai[bot]` — the Linter.**
- Runs automatically on PR open/update.
- Its completion is a required status check (see §3).
- Its verdict is advisory on style/taste but blocking on security findings. Operationally: if CodeRabbit flags a security issue, the review protocol (§5) fails regardless of Lissandra/Syndra.

### 2.3 Account provisioning

`strawberry-bot` is a real GitHub account, not a fake. It needs:

1. A real email address Duong controls (Gmail "+alias" on `harukainguyen1411@gmail.com` is fine: `harukainguyen1411+strawberrybot@gmail.com`).
2. 2FA enabled — TOTP, not SMS. Seed stored encrypted in `secrets/encrypted/` (see §4).
3. Invited as a **collaborator** on `Duongntd/strawberry` with **write** access. Not admin — admin can bypass branch protection and we want the bot pinned to the same rules as agents.
4. A classic PAT with scope `repo` only (fine-grained PATs still have gaps for collaborator repos — previously-learned lesson in `pyke.md`).
5. The PAT is stored in `secrets/encrypted/strawberry-bot-pat.age`.

---

## 3. Branch Protection on `main`

Branch protection is configured via the GitHub API (or `gh api`) and committed as code in `ops/github/branch-protection.json` so it can be re-applied idempotently.

Required rules for `main`:

- **Require a pull request before merging**: yes
- **Required approving reviews**: **1**
- **Dismiss stale reviews on new commits**: yes
- **Require review from Code Owners**: no (we use the structured protocol, not CODEOWNERS)
- **Restrict who can dismiss reviews**: `strawberry-bot` only
- **Require approval of the most recent reviewable push**: yes (closes the "push after approval" hole)
- **Require status checks to pass before merging**: yes
  - `coderabbitai` — blocking
  - `validate-scope` (existing GHA)
  - `auto-label-ready` (existing GHA)
  - Any future CI added to the repo — blocking by default
- **Require branches to be up to date before merging**: yes
- **Require conversation resolution before merging**: yes
- **Require signed commits**: deferred (Pyke still wants this — tracked as a follow-up, not a blocker for this plan)
- **Require linear history**: yes (we already ban rebase, and squash-merge produces linear)
- **Restrict who can push to matching branches**: `harukainguyen1411`, `strawberry-bot`, `Duongntd` (emergency break-glass only)
- **Allow force pushes**: **no** — Pyke will personally drown anyone who enables this
- **Allow deletions**: no
- **Do not allow bypassing the above settings**: yes (applies to admins too — the bot has write not admin, so this is for Duong's own account)

### 3.1 Applying and auditing

Ship a script `scripts/apply-branch-protection.sh` that:

1. Reads `ops/github/branch-protection.json`.
2. Calls `gh api -X PUT repos/Duongntd/strawberry/branches/main/protection --input -` with the JSON.
3. Follow-up: a Pyke-owned scheduled check (weekly) that diffs live protection against the committed JSON and alerts via Evelynn if they drift.

---

## 4. Token and Secret Management

All secrets follow the existing age-encrypted pattern from `plans/implemented/2026-04-08-...-encrypted-secrets...` (Evelynn's plan that I reviewed on 2026-04-08). No new mechanism.

Files to add under `secrets/encrypted/`:

- `strawberry-bot-pat.age` — classic PAT, `repo` scope only
- `strawberry-bot-totp-seed.age` — TOTP seed for 2FA recovery (break-glass)
- `strawberry-bot-email-password.age` — email password for the alias inbox (break-glass)

Usage discipline:

- Agents needing the bot PAT call `tools/decrypt.sh strawberry-bot-pat` which follows the `exec env GH_TOKEN=... -- gh ...` pattern. Plaintext never lands in chat context, never in `cat`, never on argv.
- The PAT is **only** used by the review/merge pipeline. Worker agents pushing commits continue to use `harukainguyen1411`'s existing credentials. Two tokens, two flows, no crossover.
- Rotation: every 90 days, Pyke rotates the PAT. Rotation is a chore: generate new PAT in GitHub UI, re-encrypt, commit, revoke old.
- Compromise playbook: revoke at GitHub first, rotate, then re-encrypt. Git history keeps the old `.age` blob forever, so provider-side revocation is the source of truth.
- `secrets/encrypted/README.md` gets a new section documenting these three files and the rotation cadence.

Pre-commit guard: `scripts/pre-commit-secrets-guard.sh` already blocks raw `age -d`; add a grep for `ghp_[A-Za-z0-9]{36}` patterns in staged files as a belt-and-braces PAT leak check.

---

## 5. Structured Review Protocol

This is the meat of "more structured". A PR can be merged only if all three reviewers return green against a fixed checklist. The checklist is committed as `ops/review/checklist.md` and the protocol is enforced by a single skill, `/review-pr-structured`, that `strawberry-bot` runs.

### 5.1 The three reviewers

**CodeRabbit (automated, runs on PR open):**
- Style, obvious bugs, dead code, secret leaks, dependency issues.
- Output: inline comments + summary. Treated as blocking on anything it labels `security` or `bug`; advisory on `style`/`nit`.

**Lissandra (logic review, Sonnet):**
- Does the diff do what the plan says it does?
- Are the edge cases handled?
- Are there tests for the changed behavior and do they actually exercise the change?
- Are there any silent behavior changes in unrelated code?
- Output: a pass/fail verdict against the checklist plus inline notes.

**Syndra (architecture review, Opus):**
- Does the diff respect the architectural constraints in `architecture/`?
- Does it introduce any new cross-agent dependency, MCP, or skill that wasn't in the plan?
- Does it match the style and layering of existing code?
- Does it regress any platform-parity rule (rule 17)?
- Output: a pass/fail verdict against the checklist plus a short architectural note.

Syndra is Opus and therefore — per rule 7 — she plans and coordinates rather than executes. Review is coordination-adjacent (non-mutating analysis + advisory output) and is explicitly inside her remit. She does not touch code during review; she writes a verdict.

### 5.2 The checklist (committed to `ops/review/checklist.md`)

A passing review means every item below is a `yes` or an explicit, documented `n/a`:

**Scope & Plan Fidelity**
1. The PR references an approved plan file in `plans/approved/` or `plans/in-progress/`.
2. Every file changed is within the scope declared by that plan.
3. The commit messages use `chore:` or `ops:` prefix (rule 10).

**Correctness**
4. CodeRabbit has no unresolved `security` or `bug` findings.
5. Lissandra's logic review is green (no unresolved questions about intent, edge cases, or test coverage).
6. All required status checks are green on the latest commit.

**Architecture**
7. Syndra's architecture review is green (no unapproved new dependencies, MCPs, skills, or cross-agent couplings).
8. Platform parity (rule 17) is preserved — no macOS-only affordances introduced outside `scripts/mac/`.

**Security**
9. No new secret added outside `secrets/encrypted/` with documented rotation.
10. No change to `.github/workflows/`, branch-protection config, or auth plumbing without an explicit Pyke review requested in the PR.
11. No `git rebase`, no force-push, no history rewrite.

**Hygiene**
12. `README.md` or architecture docs updated if the change touches architecture, MCP tools, or user-facing features (rule existing PR Rules).
13. Agent memory files not committed on a feature branch (they go direct to `main` per existing policy).

### 5.3 Flow

1. Worker agent (as `harukainguyen1411`) opens PR. Request reviews from `strawberry-bot`, label `ready-for-review`.
2. Auto-triggers:
   - CodeRabbit runs.
   - `strawberry-bot` is notified (webhook or polling via a small watcher — see 5.4).
3. `strawberry-bot` runs `/review-pr-structured <pr-number>`:
   - Spawns a Lissandra subagent to execute the logic-review portion of the checklist.
   - Spawns a Syndra subagent to execute the architecture-review portion.
   - Waits for CodeRabbit to finish.
   - Aggregates all three into a single PR comment titled `Structured Review — <pass|fail>` with the full checklist table.
4. If all green: `strawberry-bot` submits a formal `APPROVE` review, then runs `gh pr merge <n> --squash --auto`. GitHub handles the rest when the last status check turns green.
5. If anything fails: `strawberry-bot` submits a `REQUEST_CHANGES` review with the failing checklist items, labels the PR `needs-changes`, and notifies Evelynn via inbox so she can re-dispatch the worker agent to address the findings.

### 5.4 How `strawberry-bot` actually runs

`strawberry-bot` is not a living agent with its own iTerm window. It is:

- A Windows-side scheduled job (`nssm` service or Task Scheduler, consistent with the delivery-pipeline REV 3 architecture) that runs every N minutes.
- The job polls `gh pr list --label ready-for-review --search "review:none"` under the bot's credentials.
- For each PR found, it shells into `claude -p '/review-pr-structured <n>'` under the bot identity with `GH_TOKEN` set from the decrypted PAT.
- Output is logged to `~/.strawberry/ops/review-bot.log`.
- A kill-switch file (`~/.strawberry/ops/review-bot.disable`) stops the loop — consistent with the kill-switch pattern from the delivery-pipeline assessment.

Running under `claude -p` means the bot uses Duong's Claude Max subscription, not API. Same rule as the rest of the autonomous stack: subscription seat only, never API (per Duong's agent-runtime dual-mode memory).

---

## 6. What needs to be built

Implementer assignment is Evelynn's call, not mine. Listing the work items only:

1. **Provision** `strawberry-bot` GitHub account, email alias, 2FA, collaborator invite, classic PAT.
2. **Encrypt** PAT and secondary secrets into `secrets/encrypted/` and update `secrets/encrypted/README.md`.
3. **Commit** `ops/github/branch-protection.json` with the §3 rules.
4. **Ship** `scripts/apply-branch-protection.sh` and run it once to enforce on `main`.
5. **Commit** `ops/review/checklist.md` with the §5.2 checklist.
6. **Write** the `/review-pr-structured` skill that orchestrates CodeRabbit + Lissandra + Syndra and emits the aggregated comment + formal review.
7. **Write** the `strawberry-bot` poller (`scripts/windows/review-bot-loop.sh` or `.ps1`), NSSM service definition, and disable-switch handling.
8. **Weekly drift audit** job that compares live branch protection to the committed JSON and files an inbox message to Pyke if they differ.
9. **Rotate** the PAT into a 90-day calendar reminder (Evelynn's scheduling domain).
10. **Document** the whole flow in `architecture/pr-lifecycle.md` so future agents know the rules without reading this plan.

---

## 7. Risks and Open Questions

- **Review fatigue, automated edition.** If Lissandra and Syndra become pro-forma rubber stamps, the review gate is theater. Mitigation: log every review verdict; Pyke audits randomly-sampled reviews weekly and flags any where the agents approved something they shouldn't have. Adds to the "List".
- **`strawberry-bot` compromise.** If the bot's PAT leaks, attacker can merge arbitrary code to `main`. Mitigation: PAT scope is `repo` only (no `admin:org`, no `workflow`), rotation every 90 days, branch protection rules block force-push and deletion even for the bot.
- **CodeRabbit going offline.** If CodeRabbit's required status check hangs, nothing merges. Mitigation: add a manual-override label `coderabbit-down` that `strawberry-bot` respects only when Duong or Evelynn has set it in the last hour.
- **Cost of a second account.** Free. GitHub allows multiple personal accounts as long as they're real humans using them; a collaborator bot for a personal repo is within ToS.
- **Open question for Duong:** Does he want a *hard* security gate where Pyke must be a fourth required reviewer on any PR touching `.github/workflows/`, `ops/github/`, `secrets/`, or `scripts/pre-commit-*`? I recommend yes. It would be a CODEOWNERS entry plus a required-review-from-code-owners flag scoped to those paths. Trivial to add but it changes the "three reviewers" story to "three plus Pyke on security-sensitive diffs", so flagging it rather than baking it in silently.
- **Open question for Duong:** Should the bot also be permitted to **close** stale PRs that fail review and sit idle for N days? Keeps the queue clean but introduces a destructive action under the bot's identity. Default off, enable later if the queue gets noisy.

---

## 8. Success criteria

The system is working when:

- Duong has not clicked "Merge" in the GitHub UI for 14 consecutive days.
- Every merged PR on `main` in that window has a `Structured Review — pass` comment from `strawberry-bot` and a formal `APPROVE` review from the same.
- Zero merges by `harukainguyen1411` on `main` in the same window.
- Branch protection drift audit returns clean for the whole window.
- No PAT rotation overdue.

---

## 9. Explicit non-goals

- This plan does not replace the plan-approval gate. Duong still approves plans in `plans/proposed/` → `plans/approved/`. We are only automating the step *after* a plan exists.
- This plan does not change how agents author code or push commits. Worker flow is untouched.
- This plan does not introduce a GitHub App. Option B is left open as a future upgrade path if the personal-account approach becomes limiting.
- This plan does not alter the existing `Duongntd` owner bypass — that remains as the break-glass account for emergencies and is explicitly listed in branch-protection push restrictions.
