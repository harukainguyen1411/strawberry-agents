---
status: proposed
owner: camille
date: 2026-04-19
title: Split the strawberry-reviewers identity into per-agent lanes (ADR)
---

# Split the strawberry-reviewers identity into per-agent lanes

## Context

Senna and Lucian both post PR reviews via `scripts/reviewer-auth.sh`, which
authenticates as a single GitHub account, `strawberry-reviewers`. Verified from
the script source (grep `AGE_FILE=.*reviewer-github-token.age`,
`scripts/reviewer-auth.sh:25`) and from the agent defs (grep
`scripts/reviewer-auth.sh`, `.claude/agents/senna.md:48,53-55`,
`.claude/agents/lucian.md:49,54-56`): both personas share one bot identity.

GitHub models "latest review state from user X on PR Y" as a single slot.
When two agents share one identity and post opposing review states within a
short window, the later submission overwrites the earlier one in the PR's
overall decision display.

### Incident: PR #45 (today, 2026-04-19)

Senna submitted `CHANGES_REQUESTED` with a real critical-bug finding. Thirteen
seconds later Lucian submitted `APPROVED`. Because both authenticated as
`strawberry-reviewers`, the PR's overall decision collapsed to `APPROVED` and
Senna's critical finding was hidden from the merge gate. This is not a race we
can fix inside the shared identity — the collision is structural in GitHub's
review-state model.

### Remediation

Duong has provisioned a second reviewer account, `strawberry-reviewers-2`
(email `duongntd99+strawberryreviewers@gmail.com`). Lane assignment:

| Agent   | Lane identity               | Encrypted PAT path                                      |
|---------|-----------------------------|---------------------------------------------------------|
| Lucian  | `strawberry-reviewers`      | `secrets/encrypted/reviewer-github-token.age` (existing, unchanged) |
| Senna   | `strawberry-reviewers-2`    | `secrets/encrypted/reviewer-github-token-senna.age` (new)           |

Lucian stays on the existing account + existing encrypted blob so we do not
perturb the happy-path identity or invalidate any in-flight reviews. Senna
moves to the new lane.

## Decision

Introduce a per-agent lane parameter to `scripts/reviewer-auth.sh` that
selects the encrypted PAT to decrypt. Provision a second PAT on
`strawberry-reviewers-2`, encrypt it to the existing recipient key under the
new filename, and update `senna.md` to invoke the Senna lane while leaving
`lucian.md` on the default (backwards-compatible) invocation.

### Script shape — evaluation and recommendation

Two shapes considered.

**Option A — `--lane <name>` flag on the existing script.** One entry point,
one file to audit for Rule 6 compliance, clean extension path if a third lane
ever appears. Downside: one extra arg in every invocation, and the existing
invocations in `senna.md` / `lucian.md` change shape.

**Option B — sibling script `scripts/reviewer-auth-senna.sh`.** Zero-diff for
Lucian's invocations. Downside: duplicates the Rule 6 decryption path, and
every future change to the decryption contract has to be made in N places. If
we ever add a third reviewer we add a third script. Rule-6 audit surface
scales linearly.

**Recommendation: Option A.** Single audit surface for Rule 6 is the deciding
factor. Keep backwards compatibility by making `--lane` optional with a
default that points at `reviewer-github-token.age` (Lucian's lane), so
`lucian.md` needs no invocation change — only `senna.md` needs the `--lane
senna` flag added.

Concretely the script gains a prefix arg-parse block:

```sh
LANE="default"
if [[ "${1:-}" == "--lane" ]]; then
    LANE="$2"
    shift 2
fi
case "$LANE" in
    default) AGE_FILE="$REPO_ROOT/secrets/encrypted/reviewer-github-token.age" ;;
    senna)   AGE_FILE="$REPO_ROOT/secrets/encrypted/reviewer-github-token-senna.age" ;;
    *)       echo "reviewer-auth.sh: unknown lane '$LANE'" >&2; exit 2 ;;
esac
```

Rest of the script (`tools/decrypt.sh --exec`, the leading-`gh` strip, the
`AGE_FILE` existence guard) is unchanged. No raw `age -d`. No plaintext in the
parent shell. POSIX-portable bash (Rule 10).

## Scope

In scope:
- Provision, encrypt, and wire up a second PAT for `strawberry-reviewers-2`.
- Parameterize `scripts/reviewer-auth.sh` on lane.
- Update `.claude/agents/senna.md` (Evelynn only — harness restriction,
  learning 2026-04-09) to invoke the Senna lane.
- Invite `strawberry-reviewers-2` as collaborator on the two repos.
- Instate `required_pull_request_reviews` on strawberry-app (and
  strawberry-agents where applicable) with
  `required_approving_review_count: 2`, now that two distinct reviewer
  identities make this structurally enforceable.

Out of scope:
- A third reviewer lane. Design accommodates it; we are not adding one now.
- Retiring the shared identity. Lucian stays on it.

## Implementation steps

### Phase 1 — PAT provisioning (Duong, manual)

1. Sign into GitHub as `strawberry-reviewers-2`
   (`duongntd99+strawberryreviewers@gmail.com`).
2. Audit the existing `strawberry-reviewers` PAT scope so the new one matches.
   From a shell that already has the existing token:
   ```sh
   scripts/reviewer-auth.sh gh api user --jq .login   # sanity: strawberry-reviewers
   scripts/reviewer-auth.sh gh api -H "Accept: application/vnd.github+json" \
     /user --include  # read X-OAuth-Scopes / x-accepted-github-permissions headers
   ```
   Fine-grained PATs do not expose their permission set via `gh api user`; if
   the existing token is fine-grained, read its permissions from the
   GitHub UI (Settings → Developer settings → Personal access tokens →
   Fine-grained tokens → `strawberry-reviewers PAT`) and mirror exactly.
3. Mint a fine-grained PAT on `strawberry-reviewers-2`:
   - Resource owner: `harukainguyen1411`.
   - Repository access: only `harukainguyen1411/strawberry-app` and
     `harukainguyen1411/strawberry-agents`.
   - Repository permissions (read+write):
     `pull_requests`, `contents`, `issues`.
   - No account permissions beyond default.
   - Expiration: match or undercut the existing PAT's expiration.
4. Copy the token into an ephemeral file under `secrets/` (gitignored),
   e.g. `secrets/reviewer-github-token-senna.txt`. Do not paste into chat,
   shell history, or any committed file (Rule 2).
5. **Validation gate before encryption**, per learning
   `2026-04-19-pat-rotation-validation-gate`:
   ```sh
   GH_TOKEN=$(cat secrets/reviewer-github-token-senna.txt) \
     gh api user --jq .login
   ```
   MUST print `strawberry-reviewers-2`. If it prints anything else, stop —
   do not proceed to encryption.

### Phase 2 — age-encrypted secret (Duong, manual)

Recipient key unchanged: `age16zn6u722syny7sywep0x4pjlqudfm6w70w492wmqa69zw2mqwujsqnxvwm`.

```sh
age -r age16zn6u722syny7sywep0x4pjlqudfm6w70w492wmqa69zw2mqwujsqnxvwm \
    -o secrets/encrypted/reviewer-github-token-senna.age \
    secrets/reviewer-github-token-senna.txt

shred -u secrets/reviewer-github-token-senna.txt   # or `rm -P` on macOS
```

Verify round-trip without leaking plaintext into the parent shell:

```sh
scripts/reviewer-auth.sh --lane senna gh api user --jq .login
# expected: strawberry-reviewers-2
```

(Requires Phase 3 script change already landed, so sequence this after.)

The existing `reviewer-github-token.age` is **not** renamed. Do not touch it.

### Phase 3 — script change

Edit `scripts/reviewer-auth.sh` to accept optional `--lane <name>` as
described under "Script shape" above. Keep `tools/decrypt.sh --exec` as the
sole decryption path (Rule 6). Keep the "strip leading `gh`" behavior.
POSIX-portable bash (Rule 10). No `--no-verify` on commit.

### Phase 4 — dry-run test on a throwaway PR

Before updating `senna.md`, verify the new lane end-to-end on a disposable PR
(e.g. a no-op docs PR in `strawberry-agents`):

```sh
scripts/reviewer-auth.sh --lane senna gh api user --jq .login
# must print: strawberry-reviewers-2

scripts/reviewer-auth.sh --lane senna gh pr review <throwaway-pr> \
    --repo harukainguyen1411/strawberry-agents \
    --comment --body "lane-split dry run — Senna"
```

Confirm in the PR's review list that the reviewer identity on the new comment
is `strawberry-reviewers-2`, not `strawberry-reviewers`.

Also re-run the default lane to confirm no regression:

```sh
scripts/reviewer-auth.sh gh api user --jq .login
# must still print: strawberry-reviewers
```

### Phase 5 — agent def updates (Evelynn session only)

Per the 2026-04-09 harness-restriction learning, `.claude/agents/*.md` edits
may only originate from a top-level Evelynn session. Updates required:

- `.claude/agents/senna.md` — change `scripts/reviewer-auth.sh gh pr review`
  references (lines 48, 53-55) to `scripts/reviewer-auth.sh --lane senna gh
  pr review ...`. Update the preflight line (55) to expect
  `strawberry-reviewers-2`.
- `.claude/agents/lucian.md` — explicitly document that Lucian is on the
  default lane (`scripts/reviewer-auth.sh` without `--lane`, expected
  identity `strawberry-reviewers`). No invocation change, but make the
  identity expectation explicit so future readers don't assume both agents
  share.

### Phase 6a — repo invitation (Duong, manual)

From a session authenticated as `Duongntd` (repo owner):

```sh
gh api -X PUT repos/harukainguyen1411/strawberry-app/collaborators/strawberry-reviewers-2 \
    -f permission=<match-existing>
gh api -X PUT repos/harukainguyen1411/strawberry-agents/collaborators/strawberry-reviewers-2 \
    -f permission=<match-existing>
```

`<match-existing>` = whatever permission level `strawberry-reviewers` holds
today. Check first:

```sh
gh api repos/harukainguyen1411/strawberry-app/collaborators/strawberry-reviewers/permission \
    --jq .permission
```

Then `strawberry-reviewers-2` must accept the invitation (one-time, from that
account's Notifications page or via `gh api user/repository_invitations`).

### Phase 7 — Branch protection: 2-approval gate

**Sequencing precondition.** Do not apply this phase until Phases 1–6a and
all validation gates (1–7 below) have passed. Turning on
`required_approving_review_count: 2` while Senna and Lucian still share the
`strawberry-reviewers` identity would block every PR indefinitely — a shared
identity cannot supply two *distinct* approving reviewers.

**Current state (grep/API-verified earlier today,** see
`agents/camille/learnings/2026-04-19-branch-protection-probe-and-rulesets.md`
**and the stale-green plan at `plans/approved/2026-04-19-stale-green-merge-gap.md`):**
`harukainguyen1411/strawberry-app`'s branch-protection payload on `main`
does **not** carry a `required_pull_request_reviews` block at all. This
phase instates it — it is net-new policy, not a modification of an existing
rule.

**Settings (strawberry-app `main`):**

```sh
gh api -X PUT repos/harukainguyen1411/strawberry-app/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON'
{
  "required_status_checks": { "...": "preserve existing — read-modify-write" },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 2,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

Key knobs — decisions and rationale:

- `required_approving_review_count: 2` — the whole point. With Senna on
  `strawberry-reviewers-2` and Lucian on `strawberry-reviewers`, GitHub
  counts them as two distinct approvers and Rule 18's
  "non-author-approver" gate becomes enforceable at the platform level, not
  just behaviorally.
- `dismiss_stale_reviews: false` — **recommended off.** If this is on, any
  new push after Senna's approval dismisses her review. In the typical
  cascade where Lucian re-approves after a small author fixup, we do not
  want Senna's earlier LGTM invalidated; that would silently drop us back
  to one approval and block the merge. Keeping this `false` preserves the
  two-lane signal across late pushes. Trade-off: a substantive rework after
  Senna's approval won't force her re-review. We accept that; agents can
  self-dismiss if the rework is material.
- `require_code_owner_reviews: false` — **recommended off for now.** We do
  not have a mature `CODEOWNERS` file in either repo (not verified in
  scope of this plan; flag to re-audit). Turning this on without a
  correct `CODEOWNERS` would block merges pointing at paths with no code
  owner. Revisit in a follow-up once `CODEOWNERS` is authored.
- `require_last_push_approval: false` — off. Would require the approver to
  have approved *after* the most recent push, which combined with
  `dismiss_stale_reviews: false` creates a confusing policy. Keep off.
- Read-modify-write on `required_status_checks`. Fetch current payload
  first, preserve `contexts` and `strict`, then submit — do not clobber
  the existing status-check contract.

**Scope: strawberry-app only.** This phase is applied to `strawberry-app`
only. `strawberry-agents` is a private repo on GitHub Free, which does not
expose classic branch-protection rules (`required_pull_request_reviews`) via
the API — that capability requires GitHub Pro or the repo being public. The
2-approval gate on `strawberry-agents` therefore remains agent-discipline-only
until the repo is upgraded to Pro or goes public.

### Known limitation: strawberry-agents

GitHub Free does not grant access to branch-protection API endpoints for
private repos. Attempts to apply `required_pull_request_reviews` to
`harukainguyen1411/strawberry-agents` (private, Free tier) return a 403 or
silently drop the rule. This was discovered during Phase 7 execution on
2026-04-19. See ekko's learning for full details:
`agents/ekko/learnings/2026-04-19-branch-protection-github-pro-required.md`.

Until `strawberry-agents` is either made public or the org/account is upgraded
to GitHub Pro, the two-approval gate there is enforced by agent discipline
(Rule 18) rather than platform policy.

**Order within this phase:**

1. Fetch current protection payload for `strawberry-app`, save to
   `secrets/branch-protection-pre-rollout.json` (gitignored) for rollback
   reference.
2. Apply to `strawberry-app`.

### Phase 6b — Duong-opens test PR on strawberry-app (validation)

After Phase 7 lands on `strawberry-app`, Duong opens a throwaway PR there and verifies:

- PR merge button is **blocked** with "At least 2 approving reviews required"
  until both lanes approve.
- One lane approving alone is insufficient — GitHub still shows the merge
  blocked.
- After both Senna (`strawberry-reviewers-2`) and Lucian
  (`strawberry-reviewers`) approve, the merge button unblocks.
- A subsequent author-push does **not** dismiss the earlier approvals (
  `dismiss_stale_reviews: false` verification).

## Migration order (safe sequence)

1. Phase 1 — mint PAT, validate `.login` → `strawberry-reviewers-2`.
2. Phase 6a — invite `strawberry-reviewers-2` on both repos and accept.
   (Must precede Phase 4; the account needs push-reviews permission to
   submit a review comment.)
3. Phase 2 — encrypt to `secrets/encrypted/reviewer-github-token-senna.age`,
   shred plaintext.
4. Phase 3 — script change, commit with `chore:` prefix.
5. Phase 4 — dry-run on throwaway PR. Do not proceed if any gate fails.
6. Phase 5 — agent def updates in an Evelynn session. Commit with `chore:`.
7. Phase 7 — apply branch-protection 2-approval gate to strawberry-app only
   (strawberry-agents is private on GitHub Free; branch-protection API
   unavailable — see "Known limitation: strawberry-agents" under Phase 7).
8. Phase 6b — Duong opens test PR to validate the gate.

Do not flip live reviews to the new lane until Phase 4 is green. Do not
apply Phase 7 until Phases 1–6a + validation gates 1–7 are all green —
enabling 2-approvals under a shared identity would block every PR.

### Rollback — branch-protection phase

If Phase 7 causes unexpected blocking (e.g. legitimate single-reviewer
Dependabot flow has no second-lane reviewer configured):

1. Re-apply the pre-rollout payload captured in
   `secrets/branch-protection-pre-rollout.json` via
   `gh api -X PUT .../branches/main/protection --input <file>` to restore
   the prior state (no `required_pull_request_reviews` block).
2. Rollback does **not** require unwinding Phases 1–5; the lane split is
   value-positive on its own (prevents PR #45-style masking) even without
   the 2-approval gate.

## Rollback

Fast-rollback path if the Senna lane misbehaves:

1. Revert `senna.md` to drop the `--lane senna` flag (one commit, `chore:`).
   Senna reverts to the shared `strawberry-reviewers` identity, colliding
   with Lucian again — but Senna remains functional. This is the
   emergency-only state; only use while diagnosing.
2. Keep the script's `--lane` support in place (no behavior change when the
   flag is absent). No need to revert Phase 3.
3. Keep `reviewer-github-token-senna.age` committed. The encrypted blob is
   inert without an invoker.
4. If the PAT itself is compromised, revoke from `strawberry-reviewers-2`
   Settings → Developer settings → delete the PAT. Script will then fail
   closed on `--lane senna` (bad-credentials from `gh`).

## Validation gates — definition of done

1. `scripts/reviewer-auth.sh gh api user --jq .login` → `strawberry-reviewers`.
2. `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` →
   `strawberry-reviewers-2`.
3. `scripts/reviewer-auth.sh --lane bogus gh api user --jq .login` exits
   non-zero with an "unknown lane" message (no decryption attempted).
4. A throwaway PR in `strawberry-agents` shows a review comment authored by
   `strawberry-reviewers-2` when invoked with `--lane senna`, and authored by
   `strawberry-reviewers` when invoked without the flag.
5. `senna.md` and `lucian.md` both reflect their lane assignment; grep for
   `reviewer-auth.sh` in `.claude/agents/` returns only correctly-scoped
   invocations.
6. No plaintext PAT on disk outside `secrets/` (grep for the token prefix in
   the repo returns no matches).
7. Pre-commit and pre-push hooks pass on every commit in this plan (no
   `--no-verify`, Rule 14).
8. Re-simulate the PR #45 scenario on a test PR: Senna
   `CHANGES_REQUESTED` then Lucian `APPROVED` within 30s. GitHub's PR
   decision must now show both states (one per reviewer) rather than
   collapsing to the later one.
9. (Post-Phase 7) Test PR opened by Duong on `strawberry-app` cannot be
   merged until two approvals land from two **distinct** identities.
   Confirmed under the merge-button hover-text and/or `gh pr checks`.
   (strawberry-agents branch-protection gate not verifiable — GitHub Free
   paywall; see "Known limitation: strawberry-agents" under Phase 7.)
10. (Post-Phase 7) An author-push after the first approval does **not**
    dismiss it (verifies `dismiss_stale_reviews: false`).

## Dependencies flagged

- Branch-protection `required_pull_request_reviews` is net-new on
  `strawberry-app` (verified missing today; see Phase 7). It is folded into
  this plan rather than deferred, because the identity split is precisely
  the enabler — without two distinct identities, 2-approvals is
  unenforceable.
- `CODEOWNERS` is not in scope here. A follow-up plan should author
  `CODEOWNERS` in both repos and, once stable, revisit
  `require_code_owner_reviews: true`.
- Dependabot / bot-authored PRs: verify they can still merge under a
  2-approval gate. Likely requires both lanes approving, which is
  acceptable; agents can approve Dependabot PRs like any other. If this
  becomes a bottleneck, a narrow auto-approval ruleset is a possible
  follow-up, but explicitly out of scope here.

## Duong-manual steps (explicit checklist)

- [ ] Mint fine-grained PAT on `strawberry-reviewers-2` (Phase 1).
- [ ] Validate `GH_TOKEN=… gh api user --jq .login` prints
      `strawberry-reviewers-2` (Phase 1 gate).
- [ ] Invite `strawberry-reviewers-2` to both repos; accept the invites
      (Phase 6a).
- [ ] `age`-encrypt the PAT to the new filename; shred plaintext (Phase 2).
- [ ] Open test PR on `strawberry-app` after Phase 7 to validate 2-approval
      gate (Phase 6b). (strawberry-agents branch-protection not applicable —
      GitHub Free; see Phase 7 known limitation.)

All other steps (script edit, agent def edit, dry-run, commits) are
agent-executable under Evelynn's routing.

## Notes on current state (grep-verified 2026-04-19)

- `scripts/reviewer-auth.sh:25` hardcodes
  `secrets/encrypted/reviewer-github-token.age` — single-lane.
- `secrets/encrypted/` listing confirms `reviewer-github-token.age` is the
  only reviewer PAT blob today; no `-senna` / `-lucian` variants exist.
- `.claude/agents/senna.md:48,53-55` and `.claude/agents/lucian.md:49,54-56`
  both invoke `scripts/reviewer-auth.sh gh pr review ...` with no lane
  distinction and both expect `strawberry-reviewers` as the preflight
  identity.
- Rule 6 compliance confirmed in existing script: `tools/decrypt.sh --exec`
  is the only decryption call; no raw `age -d`.
