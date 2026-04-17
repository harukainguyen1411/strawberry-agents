---
date: 2026-04-17
author: jayce
task: P1.0
plan: plans/in-progress/2026-04-17-deployment-pipeline-tasks.md
---

# Deploy Script Audit — P1.0

## 1. `scripts/deploy.sh` — current behaviour

`scripts/deploy.sh` is a **VPS deployment script for the Discord relay**, not a Firebase deploy script. It is designed to run as the `runner` user on the Hetzner VPS (`37.27.192.25`). It performs four operations in order: (1) creates runtime data directories under `/home/runner/data/` for Discord event queuing; (2) runs `git pull --ff-only` from `/home/runner/strawberry`; (3) runs `npm install --production` in `apps/discord-relay`; (4) restarts PM2 processes via `ecosystem.config.js` with `pm2 start ... || pm2 restart` and saves the process list for reboot persistence. There is no Firebase CLI invocation, no test gate, no env decrypt, and no audit log — the script belongs entirely to the VPS/PM2 infrastructure layer.

**Callers across the repo:**

| File | Reference | Nature |
|------|-----------|--------|
| `architecture/infrastructure.md:66` | `scripts/deploy.sh — pull + install + PM2 restart.` | Documentation |
| `assessments/2026-04-08-protocol-leftover-audit.md:69` | `scripts/deploy.sh` listed as a VPS infra script to keep | Assessment |
| `plans/implemented/2026-04-09-protocol-migration-detailed.md:884` | `scripts/deploy.sh` listed as a VPS script in the protocol migration | Implemented plan doc |
| `agents/_retired/pyke/inbox/20260403-2320-evelynn-info.md:9` | Instruction to run `deploy.sh` to bring up PM2 processes | Archived agent inbox |
| `agents/_retired/pyke/inbox/20260403-2311-evelynn-info.md:9` | Original task to create `scripts/deploy.sh` as PM2 restart script | Archived agent inbox |

No active workflow YAML or live script references `scripts/deploy.sh` directly — it is invoked manually on the VPS, not from CI.

**What breaks if renamed/removed:** Nothing in CI or any automated path. The only impact is the VPS deploy procedure — if renamed, the infrastructure doc and any VPS-side automation calling the script by name would need updating. The `architecture/infrastructure.md` "Deploy" section references it by name.

---

## 2. `scripts/composite-deploy.sh` — current behaviour

`scripts/composite-deploy.sh` is a **Vite/Firebase Hosting assembler**. It assembles all Vite app `dist/` outputs into a single `deploy/` directory at the repo root, structured for multi-app Firebase Hosting with path-based routing. It handles three slots: (1) the portal app at the root (looking first at `apps/portal/dist`, falling back to `apps/myapps/dist` in "transition" mode); (2) standalone sub-apps under `apps/myApps/<slug>/dist` (with a case-insensitive fallback for `apps/myapps/<slug>`); (3) separate apps under `apps/yourApps/<slug>/dist`. The script is purely an assembler — it does not invoke `firebase deploy`; the final line is a `To deploy: npx firebase-tools deploy --only hosting` print statement, not an actual invocation. No test gate, no env decrypt.

**Callers across the repo:**

| File | Reference | Nature |
|------|-----------|--------|
| `package.json:17` | `"deploy": "bash scripts/composite-deploy.sh"` | npm script, root package |
| `.github/workflows/release.yml:60` | `run: bash scripts/composite-deploy.sh` | Active CI workflow (deploy-portal job) |
| `.github/workflows/preview.yml:43` | `run: bash scripts/composite-deploy.sh` | Active CI workflow (PR preview job) |
| `plans/archived/2026-04-13-deploy-pipeline-hardening.md:52` | References adding a smoke step to it | Archived plan |
| `plans/approved/2026-04-13-deployment-pipeline-architecture.md:411,432` | References version.json generation addition | Approved (superseded) plan |
| `plans/approved/2026-04-12-darkstrawberry-deployment-architecture.md:70,279,391,407,409` | Designed and documented this script | Approved plan |
| Multiple `agents/evelynn/transcripts/` entries | Session logs discussing the script | Transcripts |

**What breaks if deleted now:** The `release.yml` deploy-portal CI job and the `preview.yml` PR preview CI job would fail immediately — both explicitly invoke `bash scripts/composite-deploy.sh`. The `npm run deploy` command in `package.json` would also break.

---

## 3. Proposed dispositions

### `scripts/deploy.sh` → rename to `scripts/deploy-discord-relay-vps.sh`

**Justification:** The existing file has no Firebase logic and must not be silently overwritten by P1.2's new dispatcher. Renaming it to `scripts/deploy-discord-relay-vps.sh` makes its scope explicit in the filename, preserves all its behaviour, and frees the `scripts/deploy.sh` path for the new canonical Firebase dispatcher. Viktor (P1.1) should also update `architecture/infrastructure.md` to reference the new name.

### `scripts/composite-deploy.sh` → carry forward dormant, do not delete

**Justification:** Two active CI workflows (`release.yml` and `preview.yml`) call this script directly. Deleting it now would break those workflows. Phase 1/2 of the ADR does not include Vite/Hosting surfaces, so the script is not invoked in the new pipeline — but it remains a valid artifact for the existing Hosting deploy path. The correct disposition is to leave it as-is and add a deprecation notice at the top (a single comment: `# Vite/Hosting assembler — superseded by the deploy/functions.sh path for Firebase Functions. Retained for preview.yml and release.yml until a web-surface ADR lands.`). Viktor (P1.1) should add that comment. Deletion is deferred until a future ADR explicitly migrates or decommissions the Hosting surface.

---

## 4. Path discrepancy — where do Bee Firebase Functions actually live?

**ADR assumption:** `plans/in-progress/2026-04-17-deployment-pipeline.md` §1 states the in-scope surface as "Firebase Cloud Functions under `apps/functions/`" and P1.4 creates test files under `apps/functions/src/__tests__/`.

**Actual filesystem state:**

- `apps/functions/` exists and contains: `src/`, `lib/`, `package.json` (name: `darkstrawberry-functions`), `tsconfig.json`. This is the Cloud Functions source. **There is no `firebase.json` here.**
- `apps/myapps/firebase.json` exists and configures `firestore.rules`, `storage.rules`, and Firebase Hosting. It does **not** reference Functions — no `"functions"` key is present.
- The repo root has no `firebase.json`.

**Finding:** The Bee Firebase Functions code lives at `apps/functions/` as the ADR assumed. However, the `firebase.json` that governs Firestore rules and Storage rules (which are also ADR in-scope surfaces) lives at `apps/myapps/firebase.json` — not `apps/functions/firebase.json`. There is no `firebase.json` governing Functions deployment at either location; the existing CI workflow (`release.yml` functions-deploy job) deploys Functions by running `npx firebase-tools@latest deploy --only functions --project $FIREBASE_PROJECT_ID` from the repo root, relying on the firebase-tools CLI to locate the functions source via an implicit or missing config.

**Discrepancy to reconcile:** The ADR's §1a.3 states "each deployable app owns its own `firebase.json`." Currently:
- `apps/functions/` has no `firebase.json` — Firebase CLI must be relying on a project-level default or a root-level file that isn't committed.
- `apps/myapps/firebase.json` covers Hosting + Firestore/Storage rules, not Functions.

**Recommendation for Kayn/Evelynn:** Before P1.8 (`scripts/deploy/functions.sh`) is built, the ADR's `apps/functions/` path assumption needs a `firebase.json` to be added there (governing `"functions": { "source": "." }`) so per-app isolation holds per §1a.3. Alternatively, confirm whether Functions should be deployed from `apps/myapps/` context (where the project-level `firebase.json` lives), and amend the ADR's `apps/functions/` path reference accordingly. This is a blocker for P1.2's `_lib.sh` env-decrypt path, which needs to know which `firebase.json` governs the Functions surface.

---

## 5. Net result — what P1.1 (Viktor) needs to do

Based on this audit, P1.1's scope is:

| Action | File | Details |
|--------|------|---------|
| Rename | `scripts/deploy.sh` → `scripts/deploy-discord-relay-vps.sh` | Preserves VPS behaviour; frees path for new dispatcher |
| Update | `architecture/infrastructure.md` | Change "Deploy" section reference from `deploy.sh` to `deploy-discord-relay-vps.sh` |
| Add comment | `scripts/composite-deploy.sh` line 2 | Deprecation notice pointing to the Functions-first ADR; no functional change |
| No change | `package.json`, `.github/workflows/release.yml`, `.github/workflows/preview.yml` | Callers of `composite-deploy.sh` remain valid — Hosting surface is outside P1/P2 scope |

**What the ADR Phase-1 script layout needs to reconcile before P1.2/P1.8:**

1. Add `apps/functions/firebase.json` with a `"functions": { "source": "." }` block, OR confirm Functions deploy runs from `apps/myapps/` and amend the ADR to say so.
2. Clarify whether the in-scope Storage rules surface uses `apps/myapps/storage.rules` (current location) or a future `apps/functions/storage.rules`. The existing `firebase.json` at `apps/myapps/` governs both Storage and Hosting — splitting them requires either a new `firebase.json` for functions-only or accepting the current layout.
3. The ADR §2 env file path convention (`secrets/env/<project>.env.age`) is clean and not contradicted by the filesystem — no discrepancy there.
