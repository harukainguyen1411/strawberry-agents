---
status: approved
owner: syndra
created: 2026-04-09
title: Bee MVP Build Plan — Sequenced Tasks for Executor Delegation
---

# Bee MVP Build Plan

> Tactical build plan. Architecture is frozen in `plans/approved/2026-04-09-sister-research-agent-karma.md` — do not re-litigate decisions here. This file is a sequenced task list an executor can follow step by step once delivery-pipeline frees the queue.
>
> **Rule 7/8:** no implementer assignments. Evelynn delegates. `owner: syndra` is authorship only.

## 1. MVP scope lock (v1)

**Ships in v1:**

- **Comment-mode only.** Sister uploads `.docx` + Vietnamese prompt, gets the same `.docx` back with inline OOXML comments, each citing a source.
- **Google sign-in** via Firebase Auth. Single allowlisted UID (sister).
- **Static** `style-rules.md` in Vietnamese, hand-written by Duong, injected verbatim as a "House Rules" block. No active refinement.
- **Bee lives inside `apps/myapps/`** as a fourth route in the existing Vue 3 + Vite SPA (sibling to read tracker, portfolio tracker, task list). One build, four routes.
- **Bee worker** is a new sibling app at `apps/bee-worker/`, mirroring `apps/coder-worker/` shape, polling Firestore instead of GitHub issues.
- **Deploy target:** `https://myapps-b31ea.web.app/bee` (existing Firebase Hosting site, new route). No subdomain for v1.
- **Worker host:** Duong's always-on Windows computer, NSSM-supervised, local `claude -p` under Duong's Max login.

**Deferred to v2:**

- Research-mode report generation (`/research`).
- VN-news custom MCP scraper (cafef, vietstock, etc.).
- Feedback loop — `feedback-queue.md`, tentative-rule graduation, post-job refinement pass.
- Active `style-rules.md` editing by the agent itself.
- Multi-turn session context.
- Firestore backup job and `workers/windows/heartbeat` doc (nice-to-have; deferred).

## 2. File layout

### 2.1 Frontend (inside existing `apps/myapps/`)

```
apps/myapps/src/
  router/index.ts                 # add /bee route
  views/bee/
    BeeHome.vue                   # upload + prompt form
    BeeJob.vue                    # live status + download
    BeeHistory.vue                # prior jobs for current UID
  composables/
    useBee.ts                     # job submission + Firestore subscription
    useFirebase.ts                # EXISTING — reuse, do not rewrite
  components/bee/
    DocxUpload.vue
    JobStatusCard.vue
```

### 2.2 Worker (NEW sibling app)

```
apps/bee-worker/
  package.json                    # mirror apps/coder-worker/package.json
  tsconfig.json
  README.md
  system-prompt.md                # hard-scoped Bee system prompt (Vietnamese)
  style-rules.md                  # starter Vietnamese style rules, static in v1
  src/
    index.ts                      # entrypoint, boot + snapshot listener
    worker.ts                     # job claim loop, orchestration
    claude.ts                     # claude -p invocation wrapper
    firestore.ts                  # Admin SDK init, job transactions
    storage.ts                    # docx download/upload helpers
    runlock.ts                    # proper-lockfile wrapper, mirrors coder-worker
    docx.ts                       # execa wrapper around tools/comments.py
    log.ts                        # audit log writer (path outside writable tree)
    config.ts                     # env var loading + validation
  tools/
    comments.py                   # OOXML comment injector (python-docx + lxml)
    requirements.txt              # python-docx, lxml
  prompts/
    comment-system.md             # Vietnamese comment-mode system prompt block

scripts/windows/
  install-bee-worker.ps1          # NSSM install, NTFS ACL, mirrors install-coder-worker.ps1
```

## 3. Firestore schema — `jobs/{jobId}`

Exact field contract. Frontend writes these on create; worker writes status transitions.

```
jobs/{jobId} {
  userId:              string        // Firebase Auth UID, must equal request.auth.uid on create
  type:                "comment"     // v1 only accepts this literal
  status:              "queued" | "running" | "done" | "failed"
  prompt:              string        // Vietnamese user prompt
  sourceStorageUri:    string        // gs://myapps-b31ea.appspot.com/bee/{uid}/{jobId}/input.docx
  resultStorageUri:    string | null
  transcriptStorageUri:string | null
  errorMessage:        string | null // Vietnamese explanation on failure
  createdAt:           timestamp     // serverTimestamp()
  startedAt:           timestamp | null
  completedAt:         timestamp | null
  tokenCost:           number | null
  toolCalls:           number | null
}
```

**Claim transaction (worker):** re-read, assert `status == "queued"`, set `status="running", startedAt=serverTimestamp()`. Abort on mismatch.

## 4. Firestore security rules spec

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isBeeUser() {
      return request.auth != null
             && request.auth.uid == "SISTER_UID_PLACEHOLDER";
    }

    match /jobs/{jobId} {
      allow read:   if isBeeUser() && resource.data.userId == request.auth.uid;
      allow create: if isBeeUser()
                    && request.resource.data.userId == request.auth.uid
                    && request.resource.data.status == "queued"
                    && request.resource.data.type == "comment";
      allow update, delete: if false; // worker uses Admin SDK, bypasses rules
    }
  }
}
```

Duong fills `SISTER_UID_PLACEHOLDER` after sister signs in once (Q12 in architecture plan). Existing MyApps rules for other collections must be preserved — this block is additive.

## 5. Firebase Storage layout + rules

**Bucket paths** (default bucket `myapps-b31ea.appspot.com`):

```
bee/{userId}/{jobId}/input.docx
bee/{userId}/{jobId}/result.docx
bee/{userId}/{jobId}/transcript.md
```

**Storage rules (additive):**

```
match /bee/{userId}/{jobId}/{file} {
  allow read:   if request.auth != null
                && request.auth.uid == userId
                && request.auth.uid == "SISTER_UID_PLACEHOLDER";
  allow write:  if request.auth != null
                && request.auth.uid == userId
                && request.auth.uid == "SISTER_UID_PLACEHOLDER"
                && file == "input.docx"
                && request.resource.size < 10 * 1024 * 1024
                && request.resource.contentType == "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
}
```

Result + transcript writes are worker-only via Admin SDK.

## 6. Worker environment variables

Loaded from `%USERPROFILE%\bee\secrets\bee-worker.env` (NTFS ACL: Duong Full Control only).

| Var | Purpose | Source |
|---|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | Firebase Admin SDK service account JSON path | `%USERPROFILE%\bee\secrets\firebase-admin.json` |
| `BEE_FIREBASE_PROJECT_ID` | `myapps-b31ea` | secrets file |
| `BEE_STORAGE_BUCKET` | `myapps-b31ea.appspot.com` | secrets file |
| `BEE_WORK_DIR` | `%TEMP%\bee` — ephemeral job scratch | secrets file |
| `BEE_CLAUDE_BIN` | Path to `claude.cmd` (Claude Code CLI) | secrets file |
| `BEE_PYTHON_BIN` | Path to per-user Python | secrets file |
| `BEE_RUNLOCK_PATH` | `%USERPROFILE%\.claude-runlock\claude.lock` | secrets file |
| `BEE_AUDIT_LOG_DIR` | `%USERPROFILE%\bee-audit\` — **outside** worker writable tree | secrets file |
| `BEE_JOB_TIMEOUT_MS` | `1500000` (25 min hard kill) | secrets file |
| `BEE_SISTER_UID` | Sister's Firebase UID (for defense-in-depth filter) | secrets file |

Firebase Admin SDK credentials are read from the JSON file pointed to by `GOOGLE_APPLICATION_CREDENTIALS`, not from env directly.

## 7. Pyke security guardrails (from `assessments/2026-04-09-delivery-pipeline-security.md` REV 3 §11)

Bake these in from day one. No optional/later.

1. **Hard-scoped Claude system prompt.** `apps/bee-worker/system-prompt.md` is Vietnamese, explicitly denies shell/FS escape, denies re-invoking `claude`, forbids touching anything outside the job working dir. Injected via `claude -p --system-prompt-file` or equivalent.
2. **NTFS ACL lockdown.** `%USERPROFILE%\bee\secrets\` and `%USERPROFILE%\bee-audit\` — Full Control Duong only, strip `Users` and `Everyone`. Applied by `install-bee-worker.ps1`.
3. **Audit log outside writable tree.** `BEE_AUDIT_LOG_DIR` is `%USERPROFILE%\bee-audit\`, not under `apps/bee-worker/`. Worker has write access; Claude subprocess does not (not in `--add-dir`).
4. **Runlock required.** Every `claude -p` invocation acquires `%USERPROFILE%\.claude-runlock\claude.lock` via `proper-lockfile`. See `architecture/claude-runlock.md`.
5. **Drop `Bash` tool from allowed tools.** Comment injection is a controlled `execa` call from the worker (Node side), not from inside Claude. Claude's allowed tools list for Bee = `WebSearch`, `WebFetch`, `Read`, `Write` (scoped to job dir). No `Bash`, no `Edit` outside job dir.
6. **Per-service env var scoping.** Bee worker reads only `BEE_*` vars; never inherits coder-worker or pipeline vars. NSSM service definition sets env explicitly.
7. **Job input size cap** enforced both client-side (Vue) and in Storage rules (<10 MB, docx MIME only).
8. **25-minute hard kill** on `claude -p` subprocess via `BEE_JOB_TIMEOUT_MS`. SIGKILL, mark failed, release lock.

## 8. Task breakdown

Ten PRs. Each small enough for one executor in one pass. Difficulty S/M/L.

| ID | Title | Description | Paths | Deps | Size |
|---|---|---|---|---|---|
| **B1** | `bee-worker` scaffold | Clone `apps/coder-worker/` shape into `apps/bee-worker/`. package.json, tsconfig, empty src files, README. Wire runlock + log + config modules identically (copy from coder-worker with path/name swaps). No Firestore yet. | `apps/bee-worker/**` | — | S |
| **B2** | Firestore + Storage Admin SDK wiring | Implement `firestore.ts` (Admin SDK init, snapshot listener on `jobs` where `status=="queued"` and `type=="comment"`, claim transaction) and `storage.ts` (download input.docx, upload result.docx + transcript.md). Wire config.ts env loading. Unit tests with emulator if easy, otherwise manual. | `apps/bee-worker/src/firestore.ts`, `storage.ts`, `config.ts` | B1 | M |
| **B3** | `comments.py` OOXML helper | Python script: takes `input.docx`, JSON list of `{quote, comment, source_url}` pairs, emits `result.docx` with inline Word comments. Handles run-splitting via fuzzy match. Vietnamese font fix (Times New Roman, xml:space=preserve). Reference `XHTD XEM XET 2 - DA RA SOAT.docx` and `workspace/docx-legal-review-playbook.md` for worked examples. | `apps/bee-worker/tools/comments.py`, `requirements.txt` | — | L |
| **B4** | `claude.ts` invocation wrapper | Spawn `claude -p` with: `--system-prompt-file prompts/comment-system.md`, `--add-dir <jobDir>`, user prompt composed of House Rules (`style-rules.md`) + sister's prompt + reference to input.docx. Parse stdout for the JSON comment list. 25-min kill timer. Token cost capture. | `apps/bee-worker/src/claude.ts`, `prompts/comment-system.md`, `style-rules.md` | B1 | M |
| **B5** | `worker.ts` orchestration loop | Put it together: listen → claim → acquire runlock → download input → invoke claude → run comments.py via docx.ts → upload result + transcript → mark done → release lock → cleanup. Failure paths mark `status=failed` with Vietnamese errorMessage. | `apps/bee-worker/src/worker.ts`, `docx.ts`, `index.ts` | B2, B3, B4 | M |
| **B6** | `install-bee-worker.ps1` | NSSM install as `bee-worker` service under Duong's user. Creates `%USERPROFILE%\bee\secrets\`, `%USERPROFILE%\bee-audit\`, applies NTFS ACL (Full Control Duong, strip Users/Everyone). Writes env file template. Idempotent. Mirrors `install-coder-worker.ps1`. | `scripts/windows/install-bee-worker.ps1` | B1 | S |
| **B7** | Firestore + Storage security rules | Additive rules block (see §4, §5). Preserve existing MyApps rules. `SISTER_UID_PLACEHOLDER` sentinel. Deploy via `firebase deploy --only firestore:rules,storage`. | `firebase/firestore.rules`, `firebase/storage.rules` (whichever paths MyApps already uses) | — | S |
| **B8** | Vue frontend — `/bee` route + upload flow | New route `/bee` in `apps/myapps/src/router`. `BeeHome.vue` — Google sign-in gate, docx file input (<10MB, docx MIME), prompt textarea, submit button. On submit: upload to Storage, write Firestore job doc, navigate to `/bee/job/:id`. Reuse existing `useFirebase` composable. | `apps/myapps/src/router/index.ts`, `views/bee/BeeHome.vue`, `composables/useBee.ts`, `components/bee/DocxUpload.vue` | B7 | M |
| **B9** | Vue frontend — live job status + download | `BeeJob.vue` subscribes to `jobs/{jobId}`, renders status badge, shows Vietnamese errorMessage on fail, shows download button (signed URL) on done. `BeeHistory.vue` lists prior jobs for current UID. Vietnamese copy throughout. Mobile-responsive. | `apps/myapps/src/views/bee/BeeJob.vue`, `BeeHistory.vue`, `components/bee/JobStatusCard.vue` | B8 | M |
| **B10** | End-to-end smoke + starter `style-rules.md` | Hand-written Vietnamese `style-rules.md` starter (Duong supplies content, executor commits). Full manual smoke: sister UID allowlisted, sign-in, upload canonical `XHTD XEM XET 2` docx + prompt, worker picks up, produces commented docx, download works. Document any failures, open follow-up issues. | `apps/bee-worker/style-rules.md`, smoke test log | B5, B6, B9 | M |

**Rough execution time** (single executor, sequential): B1 2h, B2 4h, B3 6h, B4 4h, B5 4h, B6 2h, B7 1h, B8 4h, B9 4h, B10 3h. **~34 hours total**, roughly 4-5 focused working days. With parallelism (B3 + B7 + B8 alongside worker track) compresses to ~3 days wall-clock.

## 9. Dependency graph + execution order

```
B1 ─┬─► B2 ─┐
    ├─► B4 ─┼─► B5 ─┐
    └─► B6  │       │
            │       ├─► B10
B3 ─────────┘       │
B7 ─► B8 ─► B9 ─────┘
```

**Three parallel tracks once B1 lands:**

- **Worker track:** B1 → B2/B4/B6 (parallel) → B5
- **Python track:** B3 (independent, can start immediately, no Node deps)
- **Frontend track:** B7 → B8 → B9 (independent of worker until B10)

**B10 is the join point** — requires B5, B6, B9 all green.

## 10. Open questions for Duong

1. **Firebase project reuse.** Plan assumes Bee reuses `myapps-b31ea`. Confirm — or spin up a dedicated `bee-prod` project? Reuse is cheaper and the Hosting site already exists; isolation argument is weak for single-user household use. **Recommendation: reuse.**
2. **Sister's Google email for UID provisioning.** Duong needs to tell her to sign in once at `https://myapps-b31ea.web.app/bee`, then read the UID from Firebase console and patch `SISTER_UID_PLACEHOLDER` in both rules files. What email address will she use? Gating B10.
3. **MyApps nav entry.** Does Bee get a tile on the MyApps home screen, or is it hidden behind a direct URL only the sister knows? Privacy-by-obscurity vs discoverability. **Recommendation: hidden direct URL for v1.** Can add nav later.
4. **`style-rules.md` starter content.** Duong needs to hand-write the initial Vietnamese style rules (register, length preferences, citation format, font). Gating B10. Syndra can draft a skeleton if Duong provides 3-5 bullets of intent.
5. **Existing MyApps Firebase rules file location.** Plan references `firebase/firestore.rules` and `firebase/storage.rules`; confirm actual paths in the repo so B7 edits the right files.
6. **Service account reuse.** Does Bee worker use the existing `firebase-hosting-deployer` SA, or a new dedicated `bee-worker` SA scoped to Firestore + Storage read/write? **Recommendation: new SA** — least privilege, separate blast radius from CI/CD. One-time Duong creates it in console.

## 11. Cross-references

- `plans/approved/2026-04-09-sister-research-agent-karma.md` — architecture source of truth
- `architecture/claude-runlock.md` — runlock contract
- `assessments/2026-04-09-delivery-pipeline-security.md` REV 3 §11 — security patterns ported here
- `apps/coder-worker/` — structural reference for `apps/bee-worker/`
- `scripts/windows/install-coder-worker.ps1` — template for `install-bee-worker.ps1`
