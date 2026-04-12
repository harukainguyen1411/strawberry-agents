---
status: approved
owner: syndra
created: 2026-04-11
title: Bee Rearchitect — GitHub Issues Instead of Firestore Queue
---

# Bee Rearchitect — GitHub Issues as Job Queue

## Goal

Replace Bee's Firestore-based job queue with GitHub issues, making it structurally identical to coder-worker. Sister submits a question (with optional docx attachment) through the existing myapps website, it becomes a GitHub issue, bee-worker picks it up, runs `claude -p`, and posts the answer back. Issues are auto-closed when answered.

## Why

- **Structural parity with coder-worker.** One pattern to maintain, one mental model. Today bee-worker polls Firestore snapshots, coder-worker polls GitHub issues. Converging on GitHub issues means Duong maintains one polling/label-swap pattern.
- **Visibility.** GitHub issues are inspectable, searchable, have built-in audit trail. Firestore jobs are opaque without a custom UI.
- **Simplicity.** The worker becomes a thinner fork of coder-worker.

## Decisions (confirmed by Duong)

1. **Docx support retained.** Sister can still upload a `.docx` file. The file is stored temporarily in Firebase Storage (same as today), referenced by URL in the GitHub issue body. Bee-worker downloads it, processes it, uploads the result docx back to Storage, and posts a download link in the issue comment. Storage files are deleted after the job completes.
2. **Same monorepo.** Bee issues live in `strawberry` with a `bee` label to distinguish from coder-worker's `myapps` label. Bee-worker moves from `apps/bee-worker/` to `apps/private-apps/bee-worker/`.
3. **Auto-close.** When the bot posts the answer, it auto-closes the issue.
4. **No Telegram.** Website input only.

## Architecture Overview

```
Sister (myapps website)
    │
    ├── question text → GitHub issue body
    └── optional .docx → Firebase Storage (temp) → URL in issue body
    │
    ▼
GitHub Issue (labels: bee, ready)
    │
    ▼
bee-worker (polls for bee+ready issues)
    │
    ├── label swap: ready → bot-in-progress
    ├── if docx URL in issue body: download from Storage
    ├── claude -p with question + docx content + style-rules
    ├── if docx: inject comments → upload result.docx to Storage
    ├── post answer as issue comment (with download link if docx)
    ├── delete temp Storage files (input + result)
    ├── label swap: bot-in-progress → done
    └── close issue
```

## Input Channel

The existing Bee UI at `apps.darkstrawberry.com` (the MyApps Vue app). Sister logs in with Google, submits her question in the existing BeeHome/BeeJob views. The change is what happens after submit: instead of writing a Firestore job doc, the frontend uploads the docx to Storage (if present), then calls a Cloud Function that creates a GitHub issue containing the question text and a Storage download URL for the docx. The answer flows back from GitHub issue comments into the UI.

## Detailed Changes

### Phase 1: Move bee-worker to private-apps

1. `git mv apps/bee-worker apps/private-apps/bee-worker`
2. Update any references (NSSM service path, README, scripts).

### Phase 2: Rearchitect bee-worker (backend)

Replace Firestore job queue with GitHub issue polling. Keep Storage for docx file transfer.

**Files to change in `apps/private-apps/bee-worker/`:**

1. **Delete:** `src/firestore.ts` — no longer needed for job queue.
2. **Keep (modify):** `src/storage.ts` — retain for docx upload/download, but add a `deleteFile()` function for post-job cleanup.
3. **Keep:** `src/docx.ts` — OOXML comment injection stays.
4. **New:** `src/github.ts` — fork from `apps/coder-worker/src/github.ts`, simplified:
   - `fetchReadyIssues()` — fetch open issues labeled `bee` + `ready`, exclude `bot-in-progress`.
   - `atomicLabelSwap()` — same as coder-worker.
   - `commentOnIssue()` — post the answer as a comment.
   - `closeIssue()` — close the issue after posting the answer.
   - No `createPr()` — bee does not produce PRs.
5. **Rewrite:** `src/worker.ts` — new flow:
   - Claim issue (label swap ready -> bot-in-progress).
   - Parse issue body: extract question text and optional Storage URL for the docx.
   - If docx URL present: download input.docx from Storage.
   - Run `claude -p` with the question + style-rules as system prompt (+ docx content if present).
   - If docx: inject OOXML comments into docx, upload result.docx to Storage, get download URL.
   - Post Claude's answer as an issue comment. If docx, include the result download link.
   - Delete temporary Storage files (input docx, result docx).
   - Label swap bot-in-progress -> done.
   - Close the issue.
   - On failure: label back to ready, post error comment in Vietnamese.
6. **Rewrite:** `src/index.ts` — switch from Firestore snapshot listener to a `setInterval` poll loop (same as coder-worker).
7. **Rewrite:** `src/config.ts` — drop Firestore config (keep Storage config for docx), add GitHub token + repo config.
8. **Modify:** `src/claude.ts` — keep docx-aware prompting but remove Firestore job references.
9. **Keep:** `src/runlock.ts`, `src/log.ts` — unchanged.
10. **Update:** `package.json` — remove `firebase-admin` Firestore deps (keep Storage). Add `@octokit/rest`.
11. **Update:** `.env.example` — new env vars: `GITHUB_TOKEN`, `GITHUB_REPO` (e.g., `duong/strawberry`), `BEE_POLL_INTERVAL_MS` (default 30000). Keep `FIREBASE_STORAGE_BUCKET`.

### Phase 3: Rewire existing Bee UI (myapps frontend)

The existing BeeHome.vue and BeeJob.vue views in `apps/myapps/` currently submit jobs to Firestore and poll Firestore for results. Rewire them to use GitHub issues instead.

1. **Modify `useBee.ts` composable:**
   - On submit: if docx is attached, upload to Storage first (keep existing upload logic), get the Storage URL.
   - Call Cloud Function `createBeeIssue` with `{ question: string, docxStorageUrl?: string }`.
   - Store returned issue number for status polling.
2. **New Cloud Function:** `functions/createBeeIssue` — receives `{ question, docxStorageUrl? }`, creates GitHub issue with labels `bee` + `ready`. Issue body format:
   ```
   <question text>

   ---
   docx: <storage-url>   (if present)
   ```
   Returns `{ issueNumber, issueUrl }`. Gated by Firebase Auth (sister's UID). ~40 lines.
3. **New Cloud Function:** `functions/getBeeStatus` — receives `{ issueNumber }`, returns issue labels + comments via GitHub API. Frontend polls this every 10 seconds.
4. **Modify BeeJob.vue** — instead of subscribing to a Firestore doc for status, poll `getBeeStatus`. Display the answer when the `done` label appears. If the answer comment contains a docx download link, show a download button.
5. **Modify BeeHistory.vue** — list sister's past issues via `functions/listBeeIssues` (GitHub API filtered by `bee` label, closed issues). Show question (issue body) and answer (first bot comment).
6. **Keep docx upload UI** — the upload form stays, but the file goes to Storage with a temporary path (e.g., `bee-temp/{uid}/{timestamp}/input.docx`). The worker deletes it after processing.

### Phase 4: Cleanup

1. Remove Firestore collections/rules related to bee jobs (keep Storage rules for temp docx).
2. Update `apps/private-apps/bee-worker/README.md`.
3. Update NSSM service config for new path (`apps/private-apps/bee-worker`) and new env vars.
4. Verify Storage cleanup: confirm temp files are deleted after job completion.

## What Does NOT Change

- `style-rules.md` — still injected as system prompt context.
- `prompts/` directory — still used for prompt templates.
- NSSM service on Windows — bee-worker still runs as a service, just polls GitHub instead of Firestore.
- `runlock.ts` — shared lock with coder-worker remains.
- Docx upload/download UX for the sister — she still uploads a docx and gets one back.
- Firebase Storage — retained for docx file transfer (temporary storage only).

## Issue Body Format

The GitHub issue body follows a simple parseable format:

```
Em co mot cau hoi ve bai nay...

---
docx: gs://bucket/bee-temp/uid123/1712345678/input.docx
```

If no docx is attached, the `---` and `docx:` line are omitted. The worker parses this with a simple regex.

## Storage Lifecycle

1. **Upload:** Frontend uploads docx to `bee-temp/{uid}/{timestamp}/input.docx`.
2. **Download:** Worker downloads it during processing.
3. **Upload result:** Worker uploads `bee-temp/{uid}/{timestamp}/result.docx`.
4. **Post link:** Worker posts the result Storage URL (or a signed download URL) in the issue comment.
5. **Cleanup:** Worker deletes both `input.docx` and `result.docx` from Storage after posting the answer. The sister has already downloaded via the link in the UI.

Note: if the sister needs the result later, BeeHistory could re-generate or we could defer deletion by 7 days. For v1, immediate deletion is acceptable.
