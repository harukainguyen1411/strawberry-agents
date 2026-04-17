---
status: proposed
owner: azir
date: 2026-04-17
title: Deployment Pipeline ADR — Firebase surfaces, TDD gates, seam for monitoring
---

# Deployment Pipeline ADR

Architecture-level plan for how the strawberry monorepo deploys. Scope is deliberately narrow: make the currently-shipping surfaces (Bee on Firebase project `myapps-b31ea`) deployable with discipline, while leaving clean seams for future services and a monitoring dashboard. Implementation tasks are for Kayn/Aphelios to break out after approval — this plan does not write scripts.

---

## 1. Scope

**In scope today:**

- **Firebase Cloud Functions** under `apps/functions/` (TypeScript, Node 20, entry `lib/index.js`) targeting project `myapps-b31ea`.
- **Firebase Storage rules** (project `myapps-b31ea`).
- A single "deploy surface" abstraction so adding more surfaces later doesn't require redesigning the pipeline.

**Seams to leave (not built now):**

- Additional Firebase projects (second env, or a sibling project).
- Additional surfaces per project (Firestore rules, Hosting, additional Functions codebases).
- Non-Firebase targets (Cloud Run, GCE, static hosting).
- CI execution on GitHub Actions (the same scripts must work there).
- A monitoring dashboard consuming a structured deploy audit log.

**Deliberately out of scope:**

- The autonomous Discord-driven delivery loop (`plans/proposed/2026-04-08-autonomous-delivery-pipeline.md`). That plan *consumes* this one's scripts; it does not replace them.
- Preview environments / per-PR channels. Separate plan.
- Production rollback UX beyond calling the provider's native rollback.
- Multi-project secret rotation.

---

## 2. Environment and secrets strategy

**Problem today.** `apps/functions/.env.myapps-b31ea` is missing. It must contain `GITHUB_TOKEN`, `BEE_GITHUB_REPO=Duongntd/strawberry`, `BEE_SISTER_UIDS=0DJzc86i5MP74jAwwT4YjvbcAub2`, `DISCORD_WEBHOOK_URL`. Functions deploy is blocked until it exists.

**Principle.** Encrypted ciphertext in git; plaintext only materialized at deploy time, into a child process env, never into a committed file and never into shell history.

**Layout (proposed):**

| Path | Purpose | Committed? |
|------|---------|-----------|
| `secrets/env/<project>.env.age` | Age-encrypted dotenv per Firebase project | yes (ciphertext) |
| `secrets/env/<project>.env.example` | Template with keys, no values, doc-only | yes |
| `apps/functions/.env.<project>` | Plaintext dotenv, decrypted on demand | no (gitignored) |
| `secrets/age-key.txt` | Age private key | no (gitignored) |

**Flow.**

1. Duong edits ciphertext via the existing `tools/encrypt.html` flow (or a new `tools/edit-env.sh` that decrypts, opens `$EDITOR`, re-encrypts, and shreds the temp file).
2. Deploy entrypoint invokes `tools/decrypt.sh` to materialize plaintext into the child process environment. It does **not** write `.env` to disk unless `firebase deploy` explicitly needs a file on disk — in which case the file is written to a path inside the gitignored `apps/functions/` tree, never committed, and removed on exit via a `trap`.
3. Rule 6 hard-enforced: no raw `age -d`, no `cat` on plaintext, no piping of the age key. Pre-commit hook already blocks this; deploy scripts must honor it too.

**Project selection.** The Firebase project is the deploy-time axis. One encrypted env file per project, named by the Firebase project ID (not by environment semantics like "prod" / "staging"). Staging gets its own project ID, its own encrypted env, its own deploy invocation. No magic env-var toggles at deploy time.

**Bootstrapping the missing env now.** The immediate unblock is to create `secrets/env/myapps-b31ea.env.age` from Duong's known values. A dedicated bootstrap task (Kayn's to break out) handles this — it is **not** part of the pipeline design itself, just its first payload.

---

## 3. Test gates — TDD discipline

**Rule: a surface does not deploy if its tests don't pass locally first.** The pipeline enforces this by running tests before the provider CLI is invoked, and bailing on failure. No `--force`, no skip flag.

**Per-surface test matrix:**

| Surface | Unit framework | Integration framework | Required before deploy |
|---------|---------------|----------------------|------------------------|
| Cloud Functions (`apps/functions/`) | Vitest (recommended) or Jest | `firebase-functions-test` + Firebase emulator suite | unit + integration both green |
| Firebase Storage rules | `@firebase/rules-unit-testing` driving the Firebase emulator | (integration is the unit here) | rules-unit-testing suite green |

Rationale for Vitest over Jest for Functions: faster, native TS, lighter config, and it composes cleanly with the existing `tsconfig.json`. Jest is acceptable if Kayn/Aphelios prefer it for ecosystem reasons — tradeoff is ~2x slower cold start and a heavier config surface. Pick one, do not mix.

**TDD workflow the pipeline assumes:**

1. Write a failing test before changing production code.
2. Make it pass.
3. Run the full surface test suite (`pnpm --filter functions test` or equivalent) locally.
4. Deploy entrypoint re-runs that same suite as the gate. Same command, same config — the local and gate runs must be identical so "works on my machine" cannot smuggle broken code past the gate.

**Commands (shape only, Kayn to bind to concrete tools):**

- `scripts/test-functions.sh` — runs functions unit + integration tests; exits non-zero on any failure. POSIX bash, works on macOS and Git Bash.
- `scripts/test-storage-rules.sh` — boots the Firebase emulator, runs rules-unit-testing, tears down the emulator. Same portability contract.
- `scripts/test-all.sh` — invokes every `scripts/test-*.sh` entrypoint. Used by CI and by agents before opening PRs.

**Non-negotiables.**

- Tests run against the Firebase emulator, never against the live `myapps-b31ea` project. The emulator ports live in `firebase.json` (to be created/amended in the implementation phase).
- No mocking of the Firebase Admin SDK in integration tests. Mocks are for unit tests only. Integration tests hit the emulator.
- Flaky tests are bugs, not tolerances. A flaky test gets fixed or quarantined with an issue tracking it — it does not get an automatic retry in the gate.

---

## 4. Deploy command and script layout

**Shape: one thin entrypoint per surface, one orchestrator per project, one top-level deploy script.**

```
scripts/
  deploy.sh                      # existing; becomes the top-level dispatcher
  deploy/
    _lib.sh                      # shared helpers: decrypt env, log audit event, check clean tree
    project.sh                   # deploy ALL surfaces for a given project
    functions.sh                 # deploy Cloud Functions for a given project
    storage-rules.sh             # deploy Storage rules for a given project
  test-functions.sh
  test-storage-rules.sh
  test-all.sh
```

**Contracts.**

- `scripts/deploy.sh <project> [<surface>]` — top-level. If surface omitted, deploys all surfaces for that project. Examples: `scripts/deploy.sh myapps-b31ea`, `scripts/deploy.sh myapps-b31ea functions`.
- Each surface script takes exactly one positional arg: the Firebase project ID. No flags for MVP.
- Each surface script is responsible for: (1) running its own test gate, (2) materializing env via `tools/decrypt.sh`, (3) invoking the Firebase CLI with `--project <id>` and the minimal `--only` scope, (4) emitting an audit event.
- **Every script is POSIX bash, works identically on macOS and Git Bash on Windows** (Rule 10). Platform-specific affordances (e.g., opening a browser to view logs) live under `scripts/mac/` or `scripts/windows/` and are optional hooks, never required for deploy correctness.

**Preconditions enforced by `_lib.sh`:**

- Working tree is clean (or `--allow-dirty` is explicitly passed, which is off by default and off in CI always).
- On `main` branch unless `--allow-branch` is passed.
- Required env keys present after decrypt.
- Firebase CLI logged in with an account that has deploy rights on the target project.

**Interaction with existing `scripts/deploy.sh` and `scripts/composite-deploy.sh`.** Both exist today and their current semantics need to be reconciled. Kayn's breakdown must include an audit pass: keep, rename, or absorb. The names above reserve `scripts/deploy.sh` as the new canonical dispatcher — if the existing file does something incompatible, rename the old one first and do not silently overwrite.

---

## 5. Local vs CI

**Today: local only.** Duong's machine runs the deploy scripts. No GitHub Actions involvement.

**Design constraint: the same scripts must run unchanged in CI later.** Concretely:

- No interactive prompts. Any confirmation required in local mode must be skippable via an explicit flag (e.g., `--yes`) that CI always sets.
- No dependency on `$EDITOR`, `open`, `pbcopy`, or other interactive tools in the critical path. Those belong in `scripts/mac/` helpers.
- Secrets in CI come from the same encrypted-env pattern: the age key is a GitHub Actions secret, decrypted on the runner at job start, used to decrypt the project env. No plaintext secrets in workflow YAML.
- `firebase deploy` uses a service-account token via `GOOGLE_APPLICATION_CREDENTIALS` in CI, or the user's logged-in CLI locally. The deploy scripts detect which mode they're in by checking for the service-account env var first and falling back to CLI auth.

**Seam for CI.** A future `.github/workflows/deploy.yml` invokes `scripts/deploy.sh <project>` after tests pass on `main`. No additional pipeline logic lives in YAML — the workflow is a thin trigger around the same scripts.

**Explicit non-goal for now.** No GitHub Actions workflow gets authored as part of this plan's implementation. The design just guarantees it's a drop-in later.

---

## 6. Observability hook — interface for the future dashboard

The monitoring dashboard is a separate future plan. This ADR defines only the **interface** the dashboard will read from, so nothing we build now has to be retrofitted.

**Two observability streams:**

1. **Deploy audit log** — structured JSONL file, append-only, written by every deploy invocation.
   - Path: `logs/deploy-audit.jsonl` (gitignored — it's per-machine history, not shared state).
   - One record per deploy attempt, written at start and updated at end (or two records: `deploy.started`, `deploy.finished`, following the event-spine style already used elsewhere in the system).
   - Schema (minimum viable fields):
     ```json
     {
       "ts": "2026-04-17T10:00:00Z",
       "event": "deploy.finished",
       "project": "myapps-b31ea",
       "surface": "functions",
       "git_sha": "abc1234",
       "actor": "duong@local",
       "status": "success" | "failure" | "skipped",
       "duration_ms": 12345,
       "test_results": { "unit": "pass", "integration": "pass" },
       "error": null | "string"
     }
     ```
   - Dashboard contract: **read this file, do not write to it.** Anything that mutates the audit log is a bug.

2. **Firebase function logs** — already emitted by the runtime. Dashboard reads via `firebase functions:log` or the Cloud Logging API. No pipeline work needed to enable this; just note it as an input.

**Why JSONL on local disk and not Firestore / Cloud Logging for the audit log.** Local disk is the lowest-complexity venue that survives the "local-only deploy" phase and the "CI-added later" phase equally well — CI can stream its audit log to a bucket, local keeps it on disk, and both expose the same schema to the dashboard via a small reader abstraction later. Writing audit data into Firestore would entangle the deploy pipeline with the product data plane, which is the wrong direction.

**The seam the dashboard will plug into:**

- `scripts/deploy/_lib.sh` owns the audit-log append. Dashboard reads `logs/deploy-audit.jsonl`. That's the entire contract.
- No other component of the pipeline touches the audit log. If the dashboard needs richer data later, the schema grows additively (new fields are safe; removing fields is a breaking change).

---

## 7. Explicit non-goals

- No autonomous / agent-driven deploy trigger. Deploys are initiated by a human running a script.
- No multi-project orchestration. Each deploy invocation targets exactly one Firebase project.
- No blue/green, canary, or traffic-splitting logic. `firebase deploy` ships all-at-once; rollback is `firebase hosting:rollback` / redeploy previous revision.
- No rollback automation — documenting the manual rollback command per surface is enough for now.
- No secret rotation tooling. Rotating a secret means Duong edits the ciphertext and redeploys. Automation comes later.
- No monitoring dashboard. Only the audit-log interface is defined here.
- No preview channels. Separate plan.
- No test suites for surfaces we don't deploy today.
- No migration of existing `scripts/deploy.sh` behavior without an explicit audit step in the breakdown.

---

## 8. Open questions for Duong

1. **Vitest or Jest for Cloud Functions tests?** Recommendation: Vitest (faster, native TS, lighter config). Confirm or override.
2. **Encrypted dotenv vs. Firebase Functions "secret params" (`defineSecret`).** Firebase v2 Functions support first-class secret params stored in Google Secret Manager; the Firebase CLI wires them in at deploy time. Tradeoff: secret params are cleaner operationally (Google manages rotation, IAM, versioning) but lock secrets into Firebase and skip the git-tracked ciphertext audit trail. Ciphertext-in-git matches your existing `tools/decrypt.sh` pattern and works for non-Firebase surfaces later. Recommendation: ciphertext-in-git for `GITHUB_TOKEN`, `DISCORD_WEBHOOK_URL`, and any value shared across surfaces; Firebase secret params only if a future surface specifically benefits from Google-managed rotation. Confirm.
3. **Where does the encrypted env file live — `secrets/env/<project>.env.age` or `apps/functions/.env.<project>.age`?** The former centralizes secrets and scales to non-Functions surfaces cleanly; the latter co-locates with the consuming app. Recommendation: centralize in `secrets/env/` so Storage rules, future Hosting, future Cloud Run, etc. all follow one pattern.
4. **Deploy from `main` only, or any branch with `--allow-branch`?** Recommendation: `main` only by default; `--allow-branch` for explicit hotfixes and experimental deploys, never in CI.
5. **Audit log retention.** `logs/deploy-audit.jsonl` grows forever. Recommendation: no rotation now (deploy frequency is low), revisit when the dashboard lands.
6. **Firebase CLI auth for local deploys — your personal Google account, or a project-scoped service account stored encrypted?** Personal account is simpler today. Service account is stricter, required for CI. Recommendation: personal account locally, service account in CI — the scripts detect which.
7. **`firebase-functions-test` offline mode vs emulator-backed integration — both, or only emulator?** Recommendation: emulator-backed only. Offline mode is faster but diverges from production behavior enough that the divergence has bitten teams before. One integration path, one truth.
8. **Do we reconcile `scripts/deploy.sh` and `scripts/composite-deploy.sh` as part of this plan's first implementation task, or ship the new layout alongside them and retire the old ones in a later pass?** Recommendation: reconcile up-front — two deploy entrypoints invites confusion.

---

## Cross-references

- `plans/approved/2026-04-13-deployment-pipeline-architecture.md` — prior deployment-pipeline thinking; this ADR supersedes any parts that conflict and must be reconciled during breakdown.
- `plans/proposed/2026-04-08-autonomous-delivery-pipeline.md` — the autonomous Discord loop that will eventually *call* these deploy scripts. This plan defines the scripts' contract so that loop has something stable to invoke.
- `CLAUDE.md` Rule 6 — secrets discipline, `tools/decrypt.sh` usage.
- `CLAUDE.md` Rule 10 — POSIX-portable bash requirement.
- `architecture/key-scripts.md` — to be updated by the breakdown with the new script inventory.
