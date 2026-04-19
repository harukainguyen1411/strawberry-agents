---
status: in-progress
owner: camille
date: 2026-04-19
slug: pr-review-identity-gap
title: PR review identity gap — unblocking Rule 18 for agent-authored PRs
---

# PR review identity gap — unblocking Rule 18 for agent-authored PRs

## Problem

Every Sonnet executor (Jayce, Viktor, Ekko, Seraphine, Yuumi, Vi, Akali, Skarner) and every Opus reviewer (Senna, Lucian) authenticates to GitHub as the same account: **`Duongntd`**. When an executor opens a PR on `harukainguyen1411/strawberry-app` and a reviewer posts an approval, GitHub collapses both actions to the same identity and treats the approval as self-approval. Branch protection returns `reviewDecision: REVIEW_REQUIRED` and the merge is blocked.

CLAUDE.md Rule 18 requires (b) "one approving review from an account other than the PR author" and simultaneously forbids `gh pr merge --admin`. With a single agent identity, these two clauses cannot both be satisfied by any combination of agents. Today (2026-04-19) that structural gap forced `harukainguyen1411` (the human) to click approve on PR #51 (Jayce) and PR #48 before merge. The manual bypass worked once; it will not scale as agent PR throughput grows, and it defeats the point of spawning reviewer agents (Senna, Lucian) at all.

Identity reconciliation note: `agents/camille/memory/MEMORY.md` line 14 says agents run as `harukainguyen1411`. The branch-protection task context and the 2026-04-17 branch-protection plan §2 both assert `Duongntd` is the agent account and `harukainguyen1411` is the human owner/second account. `gh auth status` shows both logged in with `Duongntd` active. **This plan uses the task-provided model: agents = `Duongntd`, human owner = `harukainguyen1411`, gap = no independent reviewer identity.** Memory will be corrected during execution.

## 1. Option analysis

### A. Second dedicated agent GitHub account for reviewers only

Create a new GitHub account (e.g. `strawberry-reviewer-bot` or `Duongntd-reviewer`). Mint a fine-grained PAT scoped to `strawberry-app` + `strawberry-agents` with `contents: read`, `pull_requests: write`, `metadata: read`. Invite as a collaborator with `Write` permission (needed to post reviews). Agent sessions running reviewer roles (Senna, Lucian) authenticate under this account via `GH_TOKEN` env switching.

- **Pros.** Fully satisfies Rule 18 letter and spirit. Reviews visibly attributed to a distinct identity in PR history. No branch-protection change required — `required_approving_review_count: 1` with the default "author cannot approve" rule just works. Scales: the reviewer account can review hundreds of PRs/day.
- **Cons.** GitHub account creation requires a unique email, phone-verified in 2026 for any account with write access to a repo with branch protection bypass privileges. PAT rotation burden (Option A.1 below mitigates). Agent-network protocol must add a "which token for which role" rule. Two `gh` auth contexts on each host (laptop + GCE VM).
- **Cost.** Free. No paid line items.

### B. Single reviewer bot account (both Senna and Lucian use it) vs one account per reviewer

- **B1. One shared reviewer account.** Senna and Lucian both authenticate as the same second account. Reviews attributed to that one identity; the Senna-vs-Lucian distinction lives in the review body ("— Senna" / "— Lucian" sign-off) and the agent's commit metadata if it also commits. Simplest to operate: one PAT, one rotation cycle.
- **B2. One account per reviewer (Senna-bot, Lucian-bot).** Cleaner audit trail — you can see which reviewer persona approved at a glance in the GitHub UI. More PATs to manage. More GitHub accounts to verify, each needing a unique email + phone. No structural benefit over B1 for Rule 18 satisfaction.

Recommendation within A: **B1 (single shared reviewer account)**. Two accounts is already the threshold change; adding a third is cost without proportional benefit.

### C. Split commit identity: authors commit as `Duongntd`, reviewers auth as second account

This is a refinement of (A/B1) rather than an alternative. Executors keep the existing auth (open PRs as `Duongntd`); only reviewer agents (Senna, Lucian) switch `GH_TOKEN` to the second account when posting `gh pr review --approve`. No `git config user.email` changes — commits stay attributed to the author identity, reviews attributed to the reviewer identity. This is the **preferred execution model for (A)** because it minimizes surface area: only the reviewer agent profile loads the second PAT.

### D. Relax branch protection to "1 review, author allowed" + soft social enforcement

Configure `required_pull_request_reviews.required_approving_review_count: 1` but leave out the "author cannot approve" setting (or rely on GitHub's default plus a weaker config). Rely on CLAUDE.md alone to prevent self-approval.

- **Pros.** Zero infrastructure change. No second account, no PAT, no token juggling.
- **Cons.** Trades the whole point of Rule 18. The reason Rule 18 exists is that the branch-protection plan §6 retrospective showed agents will `--admin`-merge their own work when there's no hard gate. A soft-enforced rule is exactly the state that produced PR #117's admin-bypass. **Rejected.**

### E. GitHub merge queue + CODEOWNERS patterns

Merge queue serializes merges and re-runs required checks on the rebased-against-base commit. It does not change who must approve; it sits downstream of approval. CODEOWNERS can force specific reviewers per path, but the reviewer pool is still GitHub identities — a CODEOWNERS entry for `@harukainguyen1411` just reproduces the current human-bottleneck model. Neither mechanism solves the identity problem. **Not useful for this gap.**

### F. Admit Rule 18 is aspirational — formalize `harukainguyen1411` as mandatory approver

Keep the status quo: every agent-authored PR waits for the human. Document it explicitly in CLAUDE.md and the agent protocol.

- **Pros.** Zero implementation cost. Honest about what the system actually does.
- **Cons.** Caps agent PR throughput at human review bandwidth (realistically 2–5 PRs/day during active windows, zero during sleep/work hours). Defeats the autonomous-pipeline direction of the 2026-04-09 autonomous-pr-lifecycle plan. Makes reviewer agents (Senna, Lucian) ceremonial — they produce assessments that cannot gate merges. **Rejected** unless (A) turns out to be infeasible on cost/operational grounds.

## 2. Recommendation

**Option A + B1 + C: create one additional GitHub account dedicated to reviewer agents (Senna, Lucian), shared between them, used only to post reviews.** Executors keep `Duongntd`. No branch-protection relaxation.

Justification:

- Solves Rule 18 structurally, not by social convention.
- Minimal footprint: one new account, one PAT, one auth-switch codepath in reviewer agent profiles.
- Preserves the Senna/Lucian audit trail via review-body sign-off; GitHub UI attribution is a single "reviewer-bot" but the agent persona is always named in the review content.
- Matches the direction the 2026-04-17 branch-protection plan §2 already anticipated ("option (a) second-account approval … a small addition to the agent-network protocol"). That plan was written when the second-account was `harukainguyen1411` (human); this plan completes the idea by making the second account a non-human reviewer bot so the human owner is not on the critical path.
- Free tier. No paid line items.

## 3. Migration steps

Ordering is strict; each step must complete cleanly before the next.

1. **Duong creates the new GitHub account.** Unique email (e.g. `duong.nguyen.thai+reviewer@missmp.eu` if Gmail-style `+` aliasing accepted, else a fresh alias). Phone verify. Username proposal: `strawberry-reviewer` (short, clearly non-human). Duong to confirm username before execution — see Open Question Q1.
2. **Invite as collaborator to both repos.** On `harukainguyen1411/strawberry-app`: invite `strawberry-reviewer` with `Write` role (required to submit reviews; GitHub rejects `Read` reviewers on private/protected PRs). On `harukainguyen1411/strawberry-agents`: invite with `Read` role only — reviewer agents should not push to the infra repo. Accept invites from the new account.
3. **Mint a fine-grained PAT on `strawberry-reviewer`.**
   - Scope: `harukainguyen1411/strawberry-app` only (reviewer role does not need agent-infra access for review posting).
   - Permissions: `pull_requests: write`, `contents: read`, `metadata: read`, `issues: read`. Nothing else — no `contents: write`, no `workflows`, no `administration`.
   - Expiry: 90 days. Calendar reminder at day 80 for rotation.
4. **Encrypt the PAT at rest.** Store under `secrets/reviewer-github-token.age`, encrypted to the existing age recipient used by `tools/decrypt.sh`. Never commit plaintext. `.gitignore` already excludes `secrets/` — confirm `.age`-encrypted files are retained per the existing secrets pipeline convention (see `secrets/` README if present, else ratify with Duong). <!-- orianna: ok -->
5. **Add reviewer-auth helper script.** New file `scripts/reviewer-auth.sh` (POSIX-portable bash per Rule 10) that: <!-- orianna: ok -->
   - Calls `tools/decrypt.sh` to surface the reviewer PAT into a child process env (`GH_TOKEN`) only — never `echo`'d, never written to disk in plaintext, per Rule 6.
   - Runs the provided `gh` subcommand under that env and exits.
   - Usage: `scripts/reviewer-auth.sh gh pr review <PR> --approve --body "— Senna"`. <!-- orianna: ok -->
   This keeps the plaintext PAT confined to one subprocess and makes the reviewer-account codepath auditable as a single script.
6. **Update reviewer agent profiles.** Edit `.claude/agents/senna.md` and `.claude/agents/lucian.md` (and any other reviewer-role agents discovered during implementation) to:
   - Document that `gh pr review --approve` MUST be invoked via `scripts/reviewer-auth.sh`, not raw `gh`. <!-- orianna: ok -->
   - Forbid posting reviews as `Duongntd` on PRs authored by `Duongntd`.
   - Include a short preflight: `gh api user --jq .login` under the reviewer env should return the reviewer username before any review action.
7. **No changes to executor agent profiles.** Jayce, Viktor, Ekko, Seraphine, Yuumi, Vi, Akali, Skarner continue to auth as `Duongntd`. Explicitly document (in each profile's "Boundaries" section, or centrally in `agents/memory/agent-network.md`) that executors must NEVER load the reviewer PAT — it is a reviewer-only credential.
8. **Branch protection — verify, do not relax.** Current config on `harukainguyen1411/strawberry-app` main (per memory line 10 and recent commits `ba1def9`/`03d9305`) already requires `required_approving_review_count: 1`. Verify via `gh api repos/harukainguyen1411/strawberry-app/branches/main/protection` that the reviewer restriction still excludes PR authors by default. No change to the `bypass_actors` list — the reviewer bot is NOT a bypass actor, it is an ordinary reviewer. Under no circumstance add `strawberry-reviewer` to bypass actors.
9. **CLAUDE.md clarification (additive, not a rule change).** Add a short paragraph under Rule 18 body (or in a new "Agent Identity" subsection of `architecture/git-workflow.md`) stating: executors authenticate as `Duongntd`; reviewer agents switch to the reviewer bot identity for approval submission via `scripts/reviewer-auth.sh`; the human owner `harukainguyen1411` is reserved for break-glass only. Rules 1–18 remain unchanged in wording. <!-- orianna: ok -->
10. **Smoke test.** Open a throwaway PR from a feature branch on `strawberry-app` authored by an executor agent (`Duongntd`). Spawn a Senna session; have Senna run `scripts/reviewer-auth.sh gh pr review <N> --approve --body "— Senna (smoke test)"`. Confirm `gh pr view <N> --json reviewDecision` returns `APPROVED` and required-checks path can proceed to merge. Close the PR without merging. Document the smoke test in an `assessments/` note. <!-- orianna: ok -->
11. **Agent-network protocol update.** Add a short section to `agents/memory/agent-network.md` describing the two-identity model (executor = `Duongntd`, reviewer bot = `strawberry-reviewer`) and which agents use which. Evelynn references this when routing.
12. **Camille memory correction.** Fix `agents/camille/memory/MEMORY.md` line 14 to reflect the authoritative identity model (agents = `Duongntd`, human owner = `harukainguyen1411`, reviewer bot = `strawberry-reviewer`). This cleans up the current ambiguity captured in MEMORY.md line 19.

## 4. Secrets & auth hygiene

- **PAT scopes.** Fine-grained, single-repo (`strawberry-app`), minimum permissions (`pull_requests: write`, `contents: read`, `metadata: read`, `issues: read`). Reject any permission not explicitly required to submit a review.
- **At rest.** `secrets/reviewer-github-token.age`, age-encrypted, gitignored. No plaintext variant anywhere on disk. <!-- orianna: ok -->
- **In use.** `tools/decrypt.sh` invocation inside `scripts/reviewer-auth.sh` surfaces the PAT as `GH_TOKEN` into the child `gh` process env only. Never echoed, never logged, never in shell history (the script must not accept the token as an argument). <!-- orianna: ok -->
- **Rotation.** 90-day expiry matching the PAT. Calendar-based human task for Duong: day 80 reminder, mint replacement, re-encrypt, commit the new `.age` file. Old PAT revoked on GitHub after one successful review under the new PAT.
- **No GitHub Secret storage.** This PAT lives in the agent-infra repo only. Don't copy it into `strawberry-app` GitHub Actions secrets — that would expose it to workflow code paths that shouldn't need it.
- **Rule 6 compliance.** `scripts/reviewer-auth.sh` must never `cat`, `echo`, or pipe the decrypted value; only `export GH_TOKEN` inside a subshell and `exec gh "$@"`. <!-- orianna: ok -->
- **Audit.** Every reviewer-bot review produces a GitHub API audit log entry visible to `harukainguyen1411`. Periodic (monthly) human review of reviewer-bot activity catches misuse.

## 5. Impact on existing agents

Reviewer-only change. Executors untouched.

- **Reviewer agents (profiles must update).**
  - `.claude/agents/senna.md`
  - `.claude/agents/lucian.md`
  - Any other `.claude/agents/*.md` whose role includes `gh pr review --approve`. Executor implementer discovers these via `grep -lE 'pr review --approve|reviewer|approval' .claude/agents/*.md`.
- **Executor agents (no profile change, but must be explicitly told not to load the reviewer PAT).**
  - `.claude/agents/{jayce,viktor,ekko,seraphine,yuumi,vi,akali,skarner}.md` — add a one-line boundary statement: "Do not source `scripts/reviewer-auth.sh`. This agent authenticates as `Duongntd` only." <!-- orianna: ok -->
- **Coordinator agents.** `agents/evelynn/CLAUDE.md` and `agents/camille/` profiles may reference the routing rule (executor → reviewer requires identity switch) but their own auth is unchanged.
- **Memory files.** `agents/camille/memory/MEMORY.md` line 14 corrected per §3 step 12.
- **No changes to `scripts/setup-agent-git-auth.sh`.** That script locks git auth to the agent token for push/pull operations on this repo; reviewer-bot only posts reviews and does not push. Leave setup-agent-git-auth alone.

## 6. Open questions for Duong

Answer these before execution kicks off.

1. **Reviewer bot username.** Proposal: `strawberry-reviewer`. Alternatives: `Duongntd-reviewer`, `duongntd-bot`. Confirm preference. (Cannot be changed cheaply post-creation because it appears in every review attribution.)
2. **Email alias for the new account.** Is the `+reviewer@` alias acceptable to Duong's email provider, or should a distinct mailbox be used? Affects account-recovery ergonomics.
3. **Repo role for `strawberry-reviewer`.** `Write` is the minimum for review submission per GitHub's 2026 rules, but it grants more than reviewing — it also allows pushing to non-protected branches. Acceptable? Or should we investigate whether a `Triage` role is sufficient in the current GitHub permissions model (it was not, circa 2024 — may have changed).
4. **Rotation cadence.** 90 days proposed. Shorter (30/60)? Longer?
5. **Reviewer-body signing.** Sign reviews `— Senna` / `— Lucian` in the body, or drop the persona attribution and let the reviewer agent name live only in agent journals? Preference affects how Duong reads PR history.
6. **Scope of the change.** Should this plan also address the 2026-04-17 branch-protection plan §9 open question "Agent session auth — how Evelynn orchestrates send-this-PR-to-the-second-account-session-for-review"? Arguably in scope (same system), arguably a follow-up. My lean: include a one-paragraph Evelynn-orchestration sketch in §3 step 11 during execution.
7. **Fallback for reviewer-bot outage.** If the PAT expires unnoticed or GitHub suspends the account, who approves? Proposed: document `harukainguyen1411` as the sole fallback; do NOT grant a second break-glass reviewer identity.
8. **Does this plan supersede, amend, or coexist with `plans/approved/2026-04-17-branch-protection-enforcement.md` §2?** That plan named `harukainguyen1411` as the required second approver; this plan proposes `strawberry-reviewer` instead. Needs an amendment note on the approved plan or a formal supersede.

## 7. Non-goals

- Bot infrastructure (GitHub App). Out of scope — a GitHub App is the "right" long-term shape for automated reviewers but requires app registration, webhook handling, and installation management. Defer until a second reviewer-use-case appears.
- CODEOWNERS. Not useful with a two-identity model; single-reviewer path already deterministic.
- Merge queue. Overkill, same as 2026-04-17 plan §10.
- Changing Rule 18 wording. The rule is correct; the system has been structurally unable to satisfy it. This plan makes the system able.
- Retroactive re-review of already-merged PRs (#48, #51). History is frozen; forward-only enforcement.

## 8. Risks

- **Account suspension.** GitHub suspends bot-like accounts that look automated. Mitigation: use a plausible name (`strawberry-reviewer` rather than `sennabot42`), keep review volume reasonable (no burst of 50 approvals in 30 seconds), sign reviews with human-readable prose.
- **PAT leak.** Age-encryption at rest and Rule-6-compliant subprocess handling mitigate, but a compromised laptop means the attacker has the decryption key (memory of the age recipient) and could decrypt. Same risk as every other agent PAT today — not worse. Rotation cadence limits blast radius.
- **Scope creep.** Once a second identity exists, the temptation is to route everything through it (e.g. executors' workflow-dispatch calls). Resist. Reviewer bot is for `gh pr review` only. Enforce via the single-script indirection (`scripts/reviewer-auth.sh` has `gh pr review` in its name / does input validation on the subcommand) — executor implementer to decide. <!-- orianna: ok -->
- **Smoke test false-pass.** The smoke test can pass while a subtle misconfiguration (e.g. bot has `admin` role instead of `Write`) leaves a latent bypass. Mitigation: after smoke test, run `gh api repos/harukainguyen1411/strawberry-app/collaborators/strawberry-reviewer/permission` and assert `permission == "write"`, not `"admin"`.

## Decisions

Duong's answers to the §6 open questions (recorded 2026-04-19):

- **Reviewer bot username:** `strawberry-reviewers`
- **Email alias:** `harukainguyen1411+strawberryreviewers@gmail.com` (gmail plus-addressing — mail routes to harukainguyen1411's inbox)
- **PAT rotation cadence:** 90 days
- **Scope vs 2026-04-17-branch-protection-enforcement.md:** chains after — this plan executes once the branch-protection plan is fully landed; do not amend or supersede the earlier plan
