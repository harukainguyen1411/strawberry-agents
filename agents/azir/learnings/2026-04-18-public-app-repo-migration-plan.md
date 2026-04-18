# Azir session — public app-repo migration plan

## Task
Draft migration plan to split strawberry into private agent-infra + public `strawberry-app` for unlimited GitHub Actions minutes. Phase-1-exit blocker: 3000/3000 minutes exhausted, 13 dual-green PRs stuck.

## Output
- `plans/proposed/2026-04-19-public-app-repo-migration.md`
- Commit SHA: `c1a0311821ec2b2db57f18805cf5ada9eaeefd53`

## Structure delivered
- 2 repos: `Duongntd/strawberry` (private, agent-infra only) + `Duongntd/strawberry-app` (public, apps/dashboards/workflows/scripts)
- 7 phases, 2-4 hour budget, Ekko + Caitlyn executors
- Each phase has an explicit rollback point
- 15-row risk register, 17-secret provisioning table, grep-sweep audit list

## Key design decisions
1. **Squash history, not filter-repo path-preserve** — accept SHA loss, treat old strawberry as archival. Filter-repo leaves confusing half-empty commits and ships past-secret-near-misses into permanent public history.
2. **Strawberry keeps its name** — don't rename. Public repo is `-app`. Split is spatial, not nominal.
3. **Plans stay in strawberry, PRs move to strawberry-app** — §7 cross-repo conventions.
4. **Phase 6 (purge of code paths from strawberry) is delayed 7 days** — rollback window for Firebase binding, CI greenness, agent-memory drift catch.
5. **§8 lists 7 open decisions for Duong** — repo name, LICENSE, history strategy, marketing stance, Phase 0 admin-merge override, bee-worker placement, `architecture/` triage disputes. Plan must not be promoted to `approved/` until these are captured.

## Secrets guard gotcha
First commit attempt blocked by `pre-commit-secrets-guard` Guard 4 (plaintext match against decrypted secret values). Culprit: the Firebase project ID embedded in `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` secret name when written out in full — almost certainly the project ID is stored as a plaintext secret blob. Per CLAUDE.md rule 6, I did NOT decrypt to confirm; I just rewrote the reference in the plan from a literal project-ID string to a pointer at `apps/myapps/firebase.json`. Commit then passed.

**Takeaway for future plans:** concrete Firebase project IDs, GCP project IDs, and bucket names in plain text are landmines for Guard 4. Always reference them indirectly (via path to the config file) in documents that go to `plans/` or `agents/`.

## Outbound risks flagged in plan
- R1 gitleaks history audit — treat any real finding as migration-pause event
- R4 Firebase binding cutover is the only pseudo-irreversible step before 7-day window
- R14 `apps/coder-worker/system-prompt.md` hardcodes repo slug — autonomous agents will commit to wrong repo if not rewritten
- R15 current `.github/branch-protection.json` requires only 2 contexts, not the 5 per branch-protection-enforcement.md — must be synced before re-applying

## Handoff
- Ekko + Caitlyn read the plan, execute if Duong approves
- Plan cannot start until §8 decisions captured; decisions should be written into the plan before `plan-promote.sh` moves it to approved/
- No implementation by Azir.
