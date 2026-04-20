---
status: proposed
owner: syndra
revised: 2026-04-08
created: 2026-04-09
title: Sister Research Agent (Bee) — Personal .docx Research Companion
---

# Sister Research Agent — Bee

> Rough plan. Originally consolidated from briefs by Syndra / Swain / Bard (2026-04-08 evening). **Rewritten 2026-04-08 night** after two compounding pivots: (1) Max ToS research verdict ruled out routing a third-party user's requests through Duong's Max OAuth on a cloud VM, and (2) Duong's follow-up directive to use Google infrastructure with his Windows computer as a queue worker rather than a server. The prior cloud-VM and the subsequent Cloudflare-Tunnel + local-FastAPI revisions are both obsolete — see §11 changelog.
>
> **Rule 7 applies.** No self-implementation. Implementer assignment is Evelynn's call after approval — this plan does not name implementers. `owner: syndra` is authorship-only.

## 1. Context — what Duong asked for

A dedicated Claude-powered research companion for Duong's sister. Personal product, single user, Vietnamese-language. Two workflows:

1. **Comment-on-doc** — she uploads a `.docx` + prompt; the agent web-searches per her prompt and returns the *same* `.docx` with inline comments added, each linking to the source that informed it.
2. **Research-and-generate** — she submits a research prompt (canonical example: "assess the impact of new banking regulations in Vietnam"); the agent researches Vietnamese market/news sources and generates a fresh `.docx` report from scratch.

The agent is dedicated to her, has persistent memory, and **learns from her feedback over time** — style, depth, source preferences all adapt.

## 2. Frozen decisions (post 2026-04-08 night pivot)

- **File format:** `.docx` upload/download. Not Google Docs native.
- **Claude mode:** **local** Claude Code CLI on Duong's always-on **Windows computer**, logged in interactively under Duong's own Max account. NOT the Anthropic API, NOT a cloud VM, NOT a shared-to-third-parties OAuth. The Windows computer runs `claude -p` locally as if Duong himself were invoking it.
- **Hosting:** **Firebase** (Hosting + Auth + Firestore + Storage) on the free tier. Zero cloud-hosted Claude. Windows computer is the queue worker — it makes **zero inbound connections**, only outbound to Firebase.
- **Public reach:** `bee.web.app` (free Firebase subdomain). No domain purchase for v1. No tunnel, no inbound surface on the Windows computer.
- **Auth:** Firebase Auth (Google sign-in preferred, email magic link fallback). The shared-password approach from all prior revisions is **killed**.
- **Language:** Vietnamese output. Vietnamese source preference for Vietnamese-banking research.
- **Memory model:** active refinement — the agent adapts its style/depth based on her feedback, not just journaling interactions.
- **Cross-platform:** Worker side is **Windows-only** (Duong's always-on machine). Frontend is browser-universal (mobile-responsive from v1).

## 3. Codename — Bee

Codename is **Bee**. The sister can override at first contact.

## 4. Agent architecture — the memory-as-personalization pattern

Local Claude Code CLI on the Windows computer has no fine-tuning surface. Personalization lives entirely in files the agent reads on startup. Flat markdown, mirrors the Strawberry pattern, simplified for single-user.

**Root path (Windows):** `%USERPROFILE%\bee\`
**Git Bash view:** `/c/Users/<duong>/bee/`

```
%USERPROFILE%\bee\
  CLAUDE.md                    # project instructions, Vietnamese output, startup sequence
  profile.md                   # identity, never edited by the agent
  memory\
    bee.md                     # stable operational facts (her field, register, topics) <50 lines
    style-rules.md             # THE active-refinement file — numbered explicit rules
    feedback-log.md            # append-only raw feedback events (audit trail)
    last-session.md            # rolling handoff
  learnings\
    index.md
    YYYY-MM-DD-<topic>.md      # longer-form topic notes
  feedback-queue.md            # inbound feedback awaiting distillation
  jobs\<job-id>\               # ephemeral per-job working dir, also mirrored under %TEMP%\bee\
    input.docx
    prompt.txt
    out\
      result.docx
      transcript.md
  tools\
    comments.py                # OOXML comment injection helper
    docx_gen.py                # fresh .docx generation
  secrets\
    firebase-admin.json        # service account creds (NTFS ACL: Duong Full Control only)
```

**How "learning from feedback" actually works:**

1. She can reply to any delivery with plain text ("quá dài", "cite the specific article", "more bullets less prose"). That reply is written to Firestore `feedback-log` and the worker appends it to `memory\feedback-log.md` on disk.
2. A post-job refinement pass (same local CLI) reads the log, proposes a new numbered rule or edits an existing one in `style-rules.md`, and writes a tentative marker.
3. Tentative rules graduate to permanent after two reinforcing interactions; they auto-expire after ~10 sessions if never reinforced. Placeholder thresholds; tune after real usage.
4. `style-rules.md` is injected verbatim as a "House Rules" block in Bee's system prompt on every CLI invocation. The ruleset IS the personalization mechanism.
5. `style-rules.md` is human-readable — Duong or the sister can edit it manually in Cursor. The agent owns the file but doesn't gatekeep it.

**Session model:** fresh Claude CLI session per job. Memory files are the single source of state. Matches Strawberry's own protocol.

**Workflow routing:** two explicit slash commands in Bee's scope — `/comment <docx> <prompt>` and `/research <prompt>`. Bare prompts get a one-line clarifier in Vietnamese ("Chị muốn em bình luận tài liệu hay viết bài nghiên cứu mới?") instead of letting the LLM guess on a 20-minute task.

**Vietnamese enforcement:** three layers — (1) system-prompt hard rule, (2) final-pass self-check step in each skill, (3) Vietnamese-first search query expansion with English sources paraphrased back into Vietnamese when coverage is thin.

## 5. Infrastructure — Firebase queue-worker

**Topology at a glance:**

```
sister browser
   │  (HTTPS)
   ▼
Firebase Hosting (Next.js) ──► Firebase Auth (Google)
   │
   ├──► Firestore  (jobs queue + state + feedback-log)
   │        ▲
   │        │ snapshot listener (outbound)
   │        │
   └──► Firebase Storage (docx I/O)
            ▲
            │ outbound only
            │
   Duong's Windows computer (always-on)
     NSSM-supervised worker (Node, Firebase Admin SDK)
        └─► claude -p  (local, Duong's Max login)
```

**The Windows computer opens ZERO inbound ports.** All traffic is outbound to Firestore and Storage. Same traffic shape as a Discord Gateway client or any desktop sync app. From Anthropic's perspective this is indistinguishable from Duong's own personal automation.

### 5.1 Frontend — Firebase Hosting + Next.js

- Next.js App Router deployed to Firebase Hosting at `bee.web.app`. `*.web.app` is free — no domain purchase for v1.
- Mobile-responsive from day one.
- Routes:
  - `/comment` — docx upload + prompt → live job status → download result
  - `/research` — prompt-only → live job status → download result
  - `/history` — prior jobs for this user with download links
- Client-side uses **Firebase Web SDK directly** — no intermediate API server. Writes job docs to Firestore, uploads source docx directly to Storage via signed URL, subscribes to the job doc for live status updates.
- Vietnamese locale hardcoded, no i18n framework.

### 5.2 Auth — Firebase Auth

- Google sign-in preferred (the sister already has Gmail). Email magic link as fallback.
- Duong provisions her Firebase Auth UID once, out-of-band, by having her sign in to the deployed app one time. He then records her UID in a small `allowlist` config (either a Firestore `users/{uid}` doc or a hardcoded env var read by security rules).
- **Firestore security rules (spec):**
  - `jobs/{jobId}` — write allowed only when `request.auth.uid == resource.data.userId` AND the UID is on the allowlist. Read same. Worker authenticates via Admin SDK and bypasses these rules.
  - `feedback-log/{entryId}` — same rule.
  - `users/{uid}` allowlist — read-only from client, writable only from Firebase console.
  - Default deny on everything else.
- **No shared password, no password.hash file, no custom session middleware, no auth chain section.** Firebase Auth is the entire gate.

### 5.3 Job queue + state — Firestore

- Collection `jobs/{jobId}`:
  ```
  {
    userId: string           // Firebase Auth UID
    type: "comment" | "research"
    status: "queued" | "running" | "done" | "failed"
    prompt: string
    sourceStorageUri: string | null    // gs:// path, null for research type
    resultStorageUri: string | null
    transcriptStorageUri: string | null
    errorMessage: string | null
    createdAt: timestamp
    startedAt: timestamp | null
    completedAt: timestamp | null
    tokenCost: number | null           // reported at end of run
    toolCalls: number | null
  }
  ```
- Worker snapshot-listens on `jobs` where `status == "queued"` ordered by `createdAt`.
- Frontend subscribes to the specific job doc for live status.
- Firestore free tier (50k reads, 20k writes per day) covers hundreds of jobs per day with room to spare. One user will never come close.

### 5.4 File I/O — Firebase Storage (GCS under the hood)

- Bucket layout: `bee/{userId}/{jobId}/input.docx`, `bee/{userId}/{jobId}/result.docx`, `bee/{userId}/{jobId}/transcript.md`.
- Sister uploads the source docx **directly from her browser** using a Firebase SDK signed upload — no proxying through any backend.
- Worker downloads the source via Admin SDK, processes locally, uploads the result via Admin SDK.
- Storage security rules mirror Firestore rules (owner UID only on read/write, worker bypasses via Admin SDK).
- Storage free tier (5 GB) covers months of jobs at realistic volume.

### 5.5 Worker — Windows computer, NSSM, Firebase Admin SDK

- Long-lived Node process on Duong's always-on **Windows computer**. (Node over Python because `proper-lockfile` + Firebase Admin SDK + Next.js tooling share a toolchain; Python only shows up for the docx helpers invoked as subprocesses.)
- Supervised by **NSSM** (Non-Sucking Service Manager) as a Windows service running **as Duong's user account** so it survives reboots without an interactive login and so `%USERPROFILE%\.claude\` OAuth credentials resolve correctly. Same supervisor pattern that the now-dead Discord local-box design selected; reuse the rationale.
- Authenticates to Firebase via a **service account JSON credential** stored at `%USERPROFILE%\bee\secrets\firebase-admin.json`. NTFS ACL: **Full Control for Duong only**, strip inherited `Users` and `Everyone` entries. A scaffolding helper `scripts/windows/init-bee-dirs.ps1` creates the directory tree and applies the ACL.
- Uses Firebase Admin SDK's Firestore `onSnapshot` listener on `jobs` where `status == "queued"` ordered by `createdAt`.

**Worker loop on a new job:**

1. Atomic transaction: re-read the job doc, verify `status == queued`, set `status=running, startedAt=serverTimestamp()`. If the transaction fails (another listener instance got it first — shouldn't happen with one worker, but belt-and-suspenders), skip.
2. Acquire the shared runlock at `%USERPROFILE%\.claude-runlock\claude.lock` via `proper-lockfile`. See `architecture/claude-runlock.md` for the contract. If stale, follow the recovery policy. If held by another process, wait with a bounded retry.
3. Download source docx (if any) from Storage to `%TEMP%\bee\{jobId}\input.docx`. Create the working directory.
4. Assemble the prompt: Bee's system prompt + `memory\style-rules.md` as a "House Rules" block + the user's prompt. Invoke `claude -p` locally with `--add-dir %USERPROFILE%\bee` and `--add-dir %TEMP%\bee\{jobId}`.
5. Post-process: for `/comment`, feed Claude's annotated output through `tools\comments.py` to inject OOXML comments into the original docx. For `/research`, feed the generated markdown through `tools\docx_gen.py` to produce a fresh docx.
6. Upload `result.docx` and `transcript.md` to Storage under `bee/{userId}/{jobId}/`.
7. Update the Firestore job doc: `status=done, completedAt=serverTimestamp(), resultStorageUri, transcriptStorageUri, tokenCost, toolCalls`.
8. Post-job refinement pass (same local CLI, separate invocation): read `feedback-queue.md`, propose style-rule edits, write tentative markers. Update `memory\bee.md` and `learnings\` as needed.
9. Release the runlock. Clean `%TEMP%\bee\{jobId}\`. Return to listening.
10. On failure at any step: set `status=failed, errorMessage=<Vietnamese explanation>, completedAt=serverTimestamp()`. Release the runlock. Continue.

**Hard 25-minute kill timer** per job. If `claude -p` exceeds it, SIGKILL, mark failed, release lock.

**Serial execution only.** One user, parallelism equals quota self-DoS. The runlock enforces this against the pipeline worker as well.

**Windows specifics:**
- Per-user Node install (not system-wide) so the worker runs under Duong's profile and `%USERPROFILE%\.claude\` OAuth credentials resolve when NSSM launches it.
- Per-user Python install for the docx helper subprocesses.
- Per CLAUDE.md Rule 17: the core worker loop is written POSIX-portable (runs under Git Bash or native Node on Windows). Windows-specific helpers (NSSM install script, ACL setup, service restart) live under `scripts/windows/`.

### 5.6 Compliance posture — Layer A / B / C

Under the Firebase queue-worker shape, referencing the 2026-04-08 Max ToS research brief delivered by claude-code-guide:

- **Layer A (client identity).** Real Claude Code CLI under **Duong's Max login**, on Duong's own Windows computer. Not a shared OAuth, not a proxied session. **Green.**
- **Layer B (traffic profile).** The Windows computer makes **zero inbound connections**. All traffic is outbound: Firestore snapshot listener (websocket/long-poll outbound), Storage downloads/uploads (HTTPS outbound). Residential IP, interactive single-job invocations triggered by human clicks. No "this machine is serving requests" signal at any level. **This is strictly stronger than the Cloudflare Tunnel + local FastAPI revision**, which still presented a listener-shaped surface. **Green on technical traffic profile.**
- **Layer C (policy — household use).** Sister is family, single concurrent user at a time, no monetization, no public sign-up. Firestore is "just a transport" for what is fundamentally "Duong runs local Claude Code on behalf of a household member who asked him to." This is the same grey zone Duong already lives in when he runs his Max account across multiple personal machines. **Grey but defensible.**

**Net:** the 2026-04-08 night pivot resolves the hardest part of the original gating question (the cloud-VM-as-backend shape). What remains is the household-use policy argument, which is survivable and explicitly not a technical violation.

**Reference:** the research brief from claude-code-guide (2026-04-08 night) is the source of the verdict and should be attached / linked when this plan is presented to Duong for approval.

### 5.7 Shared Claude runlock — Bee owns the contract doc

Bee now owns `architecture/claude-runlock.md`. See that file for the full contract. Summary:

- **Canonical path:** `%USERPROFILE%\.claude-runlock\claude.lock` (Git Bash: `/c/Users/<duong>/.claude-runlock/claude.lock`).
- **Contract:** any process that wants to invoke `claude` on this Windows computer must acquire this lock first and release after. Serial execution across all participants.
- **Participants:** Bee worker + autonomous-delivery-pipeline worker. **Discord is NO LONGER a participant** — the Discord bot was rewritten to use Gemini and never invokes `claude`.
- **Acquisition library:** `proper-lockfile` for Node workers, MSYS `flock(1)` for POSIX shell helpers. Both target the same NTFS file.
- **Stale-lock recovery and timeout policy:** defined in `architecture/claude-runlock.md`.
- This plan scaffolds the doc as part of takeover. The autonomous-delivery-pipeline plan will reference it in its next revision.

### 5.8 Data flow — end-to-end for a typical job

1. Sister opens `bee.web.app`, signs in via Firebase Auth (Google).
2. She uploads `input.docx` and types a prompt. Browser uploads the docx directly to Storage at `bee/{uid}/{newJobId}/input.docx`, then writes a Firestore job doc with `status=queued, type=comment, sourceStorageUri, prompt, userId, createdAt=serverTimestamp()`.
3. Browser navigates to `/jobs/{newJobId}` and subscribes to that doc.
4. Windows worker's snapshot listener fires. Worker claims the job atomically (`status=running`).
5. Worker acquires the runlock, downloads `input.docx` to `%TEMP%\bee\{jobId}\`, invokes `claude -p` locally with the House Rules + prompt.
6. `claude -p` runs web search, writes annotated output. Worker runs `comments.py` to produce `result.docx`.
7. Worker uploads `result.docx` + `transcript.md` to Storage. Marks Firestore `status=done` with the result URIs and token cost.
8. Browser's subscription fires. UI shows a download button pointing at a Storage download URL (signed via SDK).
9. She downloads `result.docx`, reviews, optionally types a reply ("quá dài"). The reply becomes a Firestore write to `feedback-log/{entryId}` tagged with the job ID.
10. Worker's post-job refinement pass picks up the feedback entry, updates `memory\style-rules.md`, marks the rule tentative.

## 6. Tooling — the hard problems

### 6.1 `.docx` inline comments — python-docx + raw OOXML helper

`python-docx` does NOT support Word comments. Open limitation for years. Workaround: python-docx as the base, plus a ~100-line `tools\comments.py` helper that reaches into `doc.part` / `doc.element` via `lxml` and manually:

- Adds `word/comments.xml` part
- Registers content type `application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml` in `[Content_Types].xml`
- Adds relationship in `word/_rels/document.xml.rels`
- Inserts `w:commentRangeStart` / `w:commentRangeEnd` / `w:commentReference` inline markers
- Tracks unique integer comment IDs
- Handles Word's aggressive run-splitting via fuzzy-match on `{quote, comment}` pairs
- Vietnamese-specific: `xml:space="preserve"`, explicit `w:rFonts` on comment runs (Calibri or Times New Roman — Aptos misrenders Vietnamese diacritics on older Word)

**Generating `.docx` from scratch** (workflow 2): `python-docx` handles this natively via `tools\docx_gen.py`. Set `document.styles['Normal'].font.name = 'Times New Roman'` (Vietnamese banking report convention), enable `w:eastAsia` font attribute for older Word compatibility.

### 6.2 Web search — built-in + Tavily + tiny custom VN-news MCP

Local Claude Code CLI includes `WebSearch` and `WebFetch` out of the box in `-p` mode. Vietnamese-language search quality is okay but skews English; some VN news sites (cafef.vn, vietstock.vn) are JS-rendered and WebFetch gets stubs.

**Recommended stack:**

- Built-in `WebSearch` + `WebFetch` (in-scope of the CLI)
- **Tavily MCP** or Exa MCP — better semantic search for non-English, cheap API tier, `include_domains` whitelisting for VN sources
- **Tiny custom VN-news MCP** (~150 lines) wrapping cafef.vn / vietstock.vn / ndh.vn / vnexpress.net/kinh-doanh with site-specific extractors
- Playwright MCP only as JS-rendered fallback if WebFetch proves insufficient

Skip SerpAPI/Google Search MCP — expensive, Tavily covers the same ground.

Canonical sources in `memory\bee.md`: SBV (sbv.gov.vn), VnEconomy, CafeF, ThoiBaoNganHang, VietnamBiz.

**Reference material from Duong:** there is an excellent worked example of the comment-on-doc workflow in `XHTD XEM XET 2 - DA RA SOAT.docx`, and a playbook in `workspace/docx-legal-review-playbook.md`. Both should be ingested as reference inputs when designing the comment-injection prompt and the comment-pair fuzzy-match logic in Phase 1.

## 7. Phasing

### Phase 1 — agent core + docx features (local, no Firebase)

Runs on the Windows computer directly. Builds the agent brain and validates the two workflows end-to-end before touching any cloud infrastructure.

Scope: `%USERPROFILE%\bee\` directory tree, `CLAUDE.md` + profile + memory seed files, `tools\comments.py`, `tools\docx_gen.py`, a tiny local dispatcher (shell script) that invokes `claude -p` directly with canonical test inputs. One canonical `.docx` test input and one canonical research prompt. No frontend, no Firebase, no Auth — just filesystem + `claude -p` + docx helpers.

**Exit criteria:** both workflows produce a believable Vietnamese `.docx` output from the canonical inputs, invoked from a shell script on the Windows computer.

### Phase 2 — Firebase infrastructure + worker

Real infrastructure work. Not glue-light.

Scope:
- Create the Firebase project (`bee-prod` or similar)
- Enable Hosting, Auth (Google provider), Firestore, Storage
- Write Firestore security rules per §5.2 spec
- Write Storage security rules (mirror Firestore)
- Deploy a minimal Next.js skeleton to Hosting (no real UI — just a `/healthz` route and a test job-submit button)
- Provision the service account, download `firebase-admin.json`
- Run `scripts/windows/init-bee-dirs.ps1` to create `%USERPROFILE%\bee\` and apply NTFS ACLs
- Implement the worker process (Node, Firebase Admin SDK, `proper-lockfile`)
- Write the worker as a POSIX-portable script under the main Bee tree, with an NSSM install helper under `scripts/windows/install-bee-worker.ps1`
- Scaffold `architecture/claude-runlock.md` (Bee owns this — see §5.7)
- Register the worker as an NSSM Windows service under Duong's user account
- Smoke test: submit a test Firestore job doc from the Firebase console, confirm the worker picks it up, runs `claude -p` with a trivial prompt, uploads a result file to Storage, marks the job done

**Exit criteria:** a test job created via Firebase console is picked up by the Windows worker, runs end-to-end, and updates Firestore + Storage. NSSM survives a Windows reboot and the worker comes back cleanly.

### Phase 3 — the actual UI

Next.js App Router with `/comment`, `/research`, `/history` screens. Vietnamese locale. Mobile-responsive. Direct Firestore + Storage SDK usage from the client. Rate limit enqueue to ~10 jobs/hour per UID via Firestore security rule checks or a small Cloud Function (only if rules can't express it cleanly).

Duong tests with his own Google account first, then provisions his sister's UID to the allowlist and hands her the URL.

**Exit criteria:** the sister completes one comment-on-doc and one research-and-generate workflow end-to-end from her own browser, on both mobile and desktop.

### Phase 4 — refinement loop

Feedback capture UI (reply box on job result page), post-job refinement pass invocation on the worker, tentative-rule graduation logic, `feedback-queue.md` processing, daily Firestore export to a Storage backup bucket for memory durability.

**Exit criteria:** at least one rule in `style-rules.md` graduates from tentative to permanent based on real feedback from the sister.

## 8. Open questions

### Resolved (2026-04-08, across two sessions)

- **Q1 — Max subscription ToS for automated cloud backend use.** Resolved tonight by the claude-code-guide research brief: routing a third-party user's requests through Duong's Max OAuth on a cloud VM is disallowed and enforced. **Collapsed the cloud-VM path entirely.** Pivoted to the Firebase queue-worker design in §5, which runs `claude -p` locally on Duong's Windows computer under his own Max login. Layer-A/B/C compliance posture in §5.6 — green on A, green on B, grey-but-defensible on C.
- **Q2 — Max quota contention with autonomous-delivery-pipeline.** Resolved: `%USERPROFILE%\.claude-runlock\claude.lock` semaphore (see §5.7 and `architecture/claude-runlock.md`). Serial execution across Bee + pipeline. Accept the risk and monitor; revisit if quota actually bites.
- **Q3 — Hosting cost.** Resolved: **$0.** Firebase free tier covers Hosting + Auth + Firestore + Storage at single-user volume. Compute is Duong's own Windows computer, already always-on. No domain purchase for v1 — `bee.web.app` is free.
- **Q4 — Multi-turn refinement inside a single job.** Previously resolved: one-shot per job. No session persistence, no conversation window. Revisit only if the sister complains.
- **Q5 — Mobile-responsive or desktop-only for v1.** Previously resolved: **both** from day one.
- **Q6 — Bee personality.** Previously resolved: character-forward. Bee presents as a friendly Vietnamese secretary — warm, helpful, lightly personable.
- **Q7 — feedback-log.md privacy boundary.** Previously resolved: out of the public Strawberry repo. Under the new architecture the durable store is Firestore, not a GitHub mirror — see Q10 below for the replacement backup strategy.
- **Q9 — Vietnamese source thinness fallback.** Previously resolved: degrade to English paraphrased back in Vietnamese, note the gap, offer English sources as fallback.

### Still open

1. **Q10 — Firestore backup strategy.** The old design had a cron `git push` of `/opt/sister-agent/` to a private GitHub repo for durability. With memory now split between Firestore (feedback log, job history) and local disk on the Windows computer (`%USERPROFILE%\bee\memory\`), we need a replacement. Proposal: daily scheduled Firestore export to a separate Storage bucket (`bee-backup`), plus a weekly zip of `%USERPROFILE%\bee\memory\` to the same bucket from the worker. Not gating for Phase 1; decide before Phase 4.
2. **Q11 — Windows computer uptime and ISP reliability.** The whole design assumes the Windows computer is always-on with working internet. What is Duong's realistic uptime, and is there a fallback for planned outages (ISP work, power)? Not gating for Phase 1 but affects the sister's UX expectations. The UI should surface a "worker offline" state gracefully when the Firestore listener hasn't touched a `heartbeat` doc in the last N minutes.
3. **Q12 — Sister's Firebase Auth UID provisioning flow.** How does Duong get her UID into the allowlist the first time? Cleanest path: she signs in once on the deployed app, Duong reads her UID from the Firebase console, adds it to `users/{uid}` via the console. One-time manual step. Documented in the Phase 3 exit checklist. Not gating.
4. **Q13 — Heartbeat doc for worker liveness.** Should the worker write a `workers/windows/heartbeat` Firestore doc every N seconds so the UI can detect downtime? Cheap, small design addition. Decide in Phase 2.

### Non-gating

- Tentative-rule graduation threshold (2 confirmations, 10-session expiry) is a guess. Ship with defaults and tune.

## 9. What this plan does NOT do

- Does not specify Tailwind / component library / exact UI framework details. Phase 3 territory.
- Does not write `comments.py`. That's a Phase 1 implementation job.
- Does not name an implementer. Evelynn's call after Duong approves per Rule 8.
- Does not design the feedback UI. Phase 4 territory.
- Does not design the VN-news MCP scraper selectors. Phase 2 territory.
- Does **not** provision a cloud VM. Gone.
- Does **not** host Claude anywhere except locally on Duong's Windows computer.
- Does **not** open any inbound port on the Windows computer. No tunnel, no FastAPI, no Caddy, no public HTTPS endpoint on the Windows side.
- Does **not** bill Anthropic's API. No API keys involved at any layer.
- Does **not** buy a domain. `bee.web.app` is free and sufficient for v1.
- Does **not** use a shared password. Firebase Auth only.
- Does not touch the autonomous-delivery-pipeline plan's shape directly — shared-runlock coupling is documented via `architecture/claude-runlock.md`, and the pipeline plan will reference it in its next revision.

## 10. Cross-references

- `architecture/claude-runlock.md` — runlock contract, scaffolded as part of this plan
- `plans/proposed/2026-04-08-autonomous-delivery-pipeline.md` — shared runlock participant (§5.7)
- `plans/proposed/2026-04-03-discord-cli-integration.md` — Bard's parallel rewrite, no longer a runlock participant (Discord migrated to Gemini)
- `plans/proposed/2026-04-09-operating-protocol-v2.md` — Bee lives outside Strawberry's coordination fabric; standalone product
- `plans/approved/2026-04-08-skills-integration.md` — `/comment` and `/research` skills follow the format defined there
- Claude Code Guide research brief (2026-04-08 night) — Max ToS verdict, source of Q1 resolution

## 11. Changelog

- **2026-04-08 night — Firebase queue-worker pivot (this rewrite).** Two compounding pivots in one evening: (1) claude-code-guide research brief ruled out routing a third-party user through Duong's Max OAuth on a cloud VM (Max ToS violation, actively enforced), collapsing the dedicated GCE VM design; (2) Duong's follow-up directive to use Google infrastructure and treat the Windows computer as a queue worker, not a server. Full ground-up rewrite of §5. The interim Cloudflare-Tunnel + local-FastAPI + shared-password revision that briefly lived between the two pivots was also discarded — this plan goes straight from the cloud-VM HEAD to the Firebase queue-worker shape. Frontmatter owner switched to `syndra` (authorship) with `revised: 2026-04-08`. Bee now owns `architecture/claude-runlock.md` (Discord dropped it when the Discord bot migrated to Gemini).
- **2026-04-08 evening — original draft.** Dedicated GCE VM in Singapore, Cloud Run Next.js frontend, shared-password auth, private GitHub mirror for agent memory, serial worker on the VM. Superseded by the night pivot.
