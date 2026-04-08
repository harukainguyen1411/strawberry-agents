---

## status: proposed

owner: evelynn
created: 2026-04-09
title: Sister Research Agent (Bee) — Personal .docx Research Companion

# Sister Research Agent — Bee

> Rough plan. Consolidates briefs from Syndra (agent design), Swain (infra/architecture), and Bard (plumbing/tools) commissioned by Duong 2026-04-08 evening. Shape, constraints, tradeoffs, open questions. No step-by-step. Detailed execution spec comes later per phase after Duong approves.
>
> **Rule 7 applies.** Evelynn wrote this as coordinator. No self-implementation. Implementer assignment is Evelynn's call after approval — this plan does not name implementers.

## 1. Context — what Duong asked for

A dedicated Claude-powered research companion for Duong's sister. Personal product, single user, Vietnamese-language. Two workflows:

1. **Comment-on-doc** — she uploads a `.docx` + prompt; the agent web-searches per her prompt and returns the *same* `.docx` with inline comments added, each linking to the source that informed it.
2. **Research-and-generate** — she submits a research prompt (canonical example: "assess the impact of new banking regulations in Vietnam"); the agent researches Vietnamese market/news sources and generates a fresh `.docx` report from scratch.

The agent is dedicated to her, has persistent memory, and **learns from her feedback over time** — style, depth, source preferences all adapt.

## 2. Frozen decisions (from Duong's 2026-04-08 session)

- **File format:** `.docx` upload/download. Not Google Docs native.
- **Claude mode:** subscription CLI on a cloud VM, tied to Duong's Max plan. NOT the Anthropic API. No API keys anywhere.
- **Language:** Vietnamese output. Vietnamese source preference for Vietnamese-banking research.
- **Memory model:** active refinement (option b from the design pass) — the agent adapts its style/depth based on her feedback, not just journaling interactions.
- **Cross-platform:** Mac + Windows parity for any local dev/ops affordances. VM is Linux-only (production).

## 3. Codename — Bee

Syndra's 3-candidate pass surfaced Janna, Karma, and Sona (Karma was her pick on Ionian resonance + warmth-with-precision balance). Duong overrode the shortlist directly: the codename is **Bee**. Rough plan, no deeper backstory needed — it's Duong's call.

The sister can override this name at first contact — it's Bee internally unless she renames.

## 4. Agent architecture — the memory-as-personalization pattern

Subscription Claude Code CLI has no fine-tuning surface. Personalization lives entirely in files the agent reads on startup. Five-file layout, flat markdown, mirrors the Strawberry pattern, simplified for single-user:

```
/opt/sister-agent/
  CLAUDE.md                    # project instructions, Vietnamese output, startup sequence
  bee/
    profile.md                 # identity, never edited by the agent
    memory/
      bee.md                   # stable operational facts (her field, register, topics) <50 lines
      style-rules.md           # THE active-refinement file — numbered explicit rules
      feedback-log.md          # append-only raw feedback events (audit trail)
      last-session.md          # rolling handoff
    learnings/
      index.md
      YYYY-MM-DD-<topic>.md    # longer-form topic notes
    feedback-queue.md          # inbound feedback awaiting distillation
  jobs/<job-id>/
    input.docx                 # if upload mode
    prompt.txt
    out/
      result.docx
      transcript.md
  tools/
    comments.py                # OOXML comment injection helper
    docx_gen.py                # fresh .docx generation
```

There should be a skill that the agent track its usage like token and tool call cost etc and report (MUST) when ending session

**How "learning from feedback" actually works:**

1. She can reply to any delivery with plain text ("quá dài", "cite the specific article", "more bullets less prose"). That reply appends to `feedback-log.md`.
2. A post-job refinement pass (same subscription CLI, triggered by the dispatcher) reads the log, proposes a new numbered rule or edits an existing one in `style-rules.md`, and writes a tentative marker.
3. Tentative rules graduate to permanent after two reinforcing interactions; they auto-expire after ~10 sessions if never reinforced. Thresholds are placeholders — tune after a few weeks of real usage.
4. `style-rules.md` is injected verbatim as a "House Rules" block in Bee's system prompt on every CLI invocation. The ruleset IS the personalization mechanism.
5. `style-rules.md` is human-readable — Duong or the sister can edit it manually in Cursor. The agent owns the file but doesn't gatekeep it.

**Session model:** fresh Claude CLI session per job. Memory files are the single source of state. Rationale: only fresh-per-request exercises the memory-load path, so refinements made mid-session actually get tested instead of living only in the ephemeral process context. Matches Strawberry's own protocol.

**Workflow routing:** two explicit slash commands in Bee's scope — `/comment <docx> <prompt>` and `/research <prompt>`. Bare prompts get a one-line clarifier in Vietnamese ("Chị muốn em bình luận tài liệu hay viết bài nghiên cứu mới?") instead of letting the LLM guess on a 20-minute task.

**Vietnamese enforcement:** three layers — (1) system-prompt hard rule, (2) final-pass self-check step in each skill ("scan for non-Vietnamese prose before delivering"), (3) Vietnamese-first search query expansion with English sources paraphrased back into Vietnamese when coverage is thin.

## 5. Infrastructure shape

### 5.1 Hosting — dedicated GCE VM, not shared with autonomous-pipeline

`e2-small` in `asia-southeast1` (Singapore), Debian 12, ~$13/mo always-on. One Claude Code CLI logged in interactively once with Duong's Max account.

**Duong flagged cost — explore cheaper options before committing to GCE.** Open alternatives to evaluate in Phase 2 planning:

- **Host on her own computer** as the always-on machine (zero infra cost, but uptime is whatever her laptop uptime is, and it changes the network/auth shape — needs a tunnel or local-only access).
- **Google Gemini Pro plan ($20/mo)** — Duong already pays for this. Open question: does the Gemini Pro / Google One AI Pro subscription include any GCP credits that could cover the VM + Cloud Run + Firestore footprint? Needs a real read of current entitlements before pricing this plan.
- Smaller GCE shape (`e2-micro` free tier) or Cloud Run-only with no persistent VM if the dispatcher can be made stateless.

**Added to §8 open questions.**

**Do NOT share the VM with `plans/proposed/2026-04-08-autonomous-delivery-pipeline.md`'s GCE VM.** Three reasons: (1) quota blast radius — a runaway overnight pipeline run would 429 the sister's morning sessions; (2) security isolation — sister surface has public OAuth endpoint + untrusted `.docx` uploads + filesystem-and-web Claude, while pipeline has repo-write + delivery credentials; (3) operational churn — pipeline plan is still in flux, sister app uptime should not couple to that.

Quota contention at the Max-plan level is NOT fixed by VM isolation. Mitigation: pipeline pauses 07:00–22:00 local; if that's unacceptable or insufficient, buy a second Max seat for the pipeline. **See §8 open questions.**

### 5.2 Frontend — Next.js on Cloud Run (same GCP project)

Next.js App Router with server actions for `.docx` upload/download, OAuth, allowlist, signed GCS URL issuance, job polling via Firestore client SDK.

Cloud Run over Vercel specifically because Vercel's function timeout and body-size limits will bite on `.docx` upload and long Claude runs. Cloud Run gives 60-minute request timeouts, 32MB bodies, scale-to-zero, same GCP project as VM + GCS bucket (one IAM boundary, one billing line).

UI is three screens: upload-with-prompt, research-prompt, job history with download links. Vietnamese locale hardcoded, no i18n framework.

### 5.3 Auth — single shared password

**Duong directive: skip OAuth, use a password.** This is a one-user app; the OAuth + allowlist machinery is overkill.

Single shared password stored as a bcrypt/argon2 hash in GCP Secret Manager (or env var on Cloud Run). Login screen takes the password, server compares against the hash, issues a short-lived signed JWT cookie (HttpOnly, Secure, SameSite=Lax) on success. Same cookie check enforced in Next.js middleware for all `/api/`* and `/app/*` routes. Rate-limit login attempts (~~5/min per IP) and the enqueue endpoint (~~10 jobs/hour) so a leaked cookie can't burn quota.

No Google OAuth, no NextAuth, no allowlist email config, no Cloud IAP.

### 5.4 Storage — three homes for three concerns

1. `**.docx` files (transient):** GCS bucket, same region. `jobs/<job-id>/input.docx`, `jobs/<job-id>/output.docx`. 30-day lifecycle delete. Signed URLs for download. Pennies per month.
2. **Job state + conversation history:** Firestore (Native) in the same project. Collections `jobs` and `conversations`. Free tier covers her entire usage forever.
3. **Agent memory + learnings:** VM local disk at `/opt/sister-agent/`, mirrored to a **private GitHub repo** via cron `git push` every hour and on every job completion. Git is the durable backup + diffable history; VM disk is the hot path. Do NOT put memory in Firestore — Claude Code CLI is a filesystem citizen, fighting that loses the learning loop's auditability.

### 5.5 Data flow

```
Browser (Next.js)
  ├─ Password login → signed session cookie
  ├─ Upload(.docx + prompt) → Cloud Run server action
  │    ├─ Write to GCS: jobs/<id>/input.docx
  │    ├─ Create Firestore job doc: status=queued
  │    ├─ POST to VM dispatcher: {job_id}
  │    └─ Return job_id, redirect to /jobs/<id>
  └─ Poll Firestore (client SDK, allowlist-scoped rules)

VM (dedicated e2-small):
  systemd service "dispatcher" — FastAPI on localhost, Caddy front with
  mTLS or shared-secret header, firewall allows only Cloud Run egress.

  dispatcher({job_id}):
    1. Fetch job doc from Firestore
    2. Pull input.docx from GCS → /tmp/jobs/<id>/
    3. Enqueue to file-based job queue (SQLite or dir-of-JSON)
    4. Serial worker picks up, invokes:
         claude -p "..." --add-dir /opt/sister-agent/bee --add-dir /tmp/jobs/<id>
    5. Agent reads CLAUDE.md → bee/profile.md → bee/memory/*.md →
       style-rules.md injected as House Rules → executes the workflow
    6. Agent writes output.docx to /tmp/jobs/<id>/out/
    7. Worker uploads output to GCS, updates Firestore status=done
    8. On failure: Firestore status=error with Vietnamese explanation
    9. Post-job: refinement pass reads feedback-queue.md, updates
       style-rules.md + learnings/ + memory/bee.md
   10. Cron git-pushes /opt/sister-agent/ to private GitHub mirror
```

**Serial worker, not parallel** — one user, parallelism equals quota self-DoS. File-based queue, not Pub/Sub or Cloud Tasks — one user, no ops budget.

**REST wrapping shell, not direct exec from Cloud Run** — Cloud Run → VM HTTP is the clean seam. Cloud Run never touches `claude` directly.

**Async everywhere for long runs** — research jobs take 10–25 minutes; never hold an HTTP connection open across a Claude run. Dispatcher returns `job_id` immediately; everything else is Firestore polling. Worker has a hard 25-minute kill timer.

## 6. Tooling — the hard problems

### 6.1 `.docx` inline comments — python-docx + raw OOXML helper

`**python-docx` does NOT support Word comments.** Open limitation for years. Workaround: python-docx as the base, plus a ~100-line `comments.py` helper that reaches into `doc.part` / `doc.element` via `lxml` and manually:

- Adds `word/comments.xml` part
- Registers content type `application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml` in `[Content_Types].xml`
- Adds relationship in `word/_rels/document.xml.rels`
- Inserts `w:commentRangeStart` / `w:commentRangeEnd` / `w:commentReference` inline markers
- Tracks unique integer comment IDs
- Handles Word's aggressive run-splitting via fuzzy-match on `{quote, comment}` pairs
- Vietnamese-specific: `xml:space="preserve"`, explicit `w:rFonts` on comment runs (Calibri or Times New Roman — Aptos misrenders Vietnamese diacritics on older Word)

**Generating `.docx` from scratch** (workflow 2): `python-docx` handles this natively. Set `document.styles['Normal'].font.name = 'Times New Roman'` (Vietnamese banking report convention), enable `w:eastAsia` font attribute for older Word compatibility.

### 6.2 Web search — built-in + Tavily + tiny custom VN-news MCP

Subscription Claude Code CLI includes `WebSearch` and `WebFetch` tools out of the box in `-p` mode — no API key, counts against the subscription. Vietnamese-language search quality is *okay* but skews English; some VN news sites (cafef.vn, vietstock.vn) are JS-rendered and WebFetch gets stubs.

**Recommended stack:**

- Built-in `WebSearch` + `WebFetch` (free, in-scope of subscription)
- **Tavily MCP** or Exa MCP — better semantic search for non-English, cheap API tier, `include_domains` whitelisting for VN sources
- **Tiny custom VN-news MCP** (~150 lines) wrapping cafef.vn / vietstock.vn / ndh.vn / vnexpress.net/kinh-doanh with site-specific extractors. Worth building because banking/market research IS the use case.
- Playwright MCP only as JS-rendered fallback if WebFetch proves insufficient. Heavy — add only if needed.

Skip SerpAPI/Google Search MCP — expensive, Tavily covers the same ground.

Sources canonical in `memory/bee.md`: SBV (sbv.gov.vn), VnEconomy, CafeF, ThoiBaoNganHang, VietnamBiz.

**Reference material from Duong:** there is an excellent worked example of the comment-on-doc workflow in `XHTD XEM XET 2 - DA RA SOAT.docx`, and a playbook in `workspace/docx-legal-review-playbook.md`. Both should be ingested as reference inputs when designing the comment-injection prompt and the comment-pair fuzzy-match logic in Phase 1. Locate and copy these into the plan's reference set before kicking off implementation.

### 6.3 Auth chain web → CLI

Password login (see §5.3) verified server-side against the hashed credential in Secret Manager. On success, issue short-lived signed session cookie (HttpOnly, Secure, SameSite=Lax). Job enqueue checks cookie → job tagged with the single fixed owner identity → worker trusts queue post-enqueue. Result download checks cookie before serving the signed GCS URL. One-user app, so owner-match is trivial — the cookie is the entire gate.

## 7. Phasing

### Phase 1 — local prototype, no cloud

Runs on Duong's Mac or Windows box. Builds the agent core and validates the two workflows end-to-end before touching GCP.

Scope: Bee's `/opt/sister-agent/` structure, `CLAUDE.md` + profile + memory seed files, `comments.py` helper, `docx_gen.py`, a tiny local dispatcher (Python `-m http.server` class or FastAPI on localhost), one canonical `.docx` test input and one canonical research prompt. No web frontend, no OAuth, no GCS, no Firestore — just filesystem + `claude -p` shelled by the local dispatcher.

Exit criteria: both workflows produce a believable Vietnamese `.docx` output from the canonical inputs on Duong's machine.

### Phase 2 — cloud infrastructure

Dedicated GCE VM (or whichever host wins from §8.3), Cloud Run Next.js shell (no UI yet, just the dispatcher-proxy endpoint), Firestore project, GCS bucket, Secret Manager holding the shared password hash. VM → Cloud Run auth via shared secret. End-to-end job submission via `curl` against Cloud Run with a test session cookie.

Exit criteria: a job POSTed from `curl` lands on the VM, runs, uploads output to GCS, updates Firestore, and is downloadable via signed URL.

### Phase 3 — the actual UI

Next.js App Router with upload-with-prompt, research-prompt, and job history screens. Vietnamese locale. Rate limiting. Duong tests with the shared password himself, then hands the password to his sister.

Exit criteria: the sister completes one comment-on-doc and one research-and-generate workflow end-to-end from her own browser.

### Phase 4 — refinement loop

Feedback capture UI, post-job refinement pass, tentative-rule graduation, `feedback-queue.md` processing, private GitHub mirror of `/opt/sister-agent/`. This is the "learns from feedback" layer — shipped last because it only has value after real usage.

Exit criteria: at least one rule in `style-rules.md` graduates from tentative to permanent based on real feedback from the sister.

## 8. Open questions — gating

Numbered so Duong can answer in one shot.

1. **Max subscription ToS for automated cloud backend use — real blocker.** All three advisors (Syndra, Swain, Bard) independently flagged this. Running `claude -p` from a cloud VM as an end-user-facing backend is a grey zone — Anthropic's Max terms are ambiguous on "automated use" vs "personal CLI use." Needs a real read of the current Max ToS before we build anything on this constraint. **If this is a no-go, the whole "subscription not API" direction collapses and we rebuild on API** — not the end of the world, but a different plan.
2. **Max quota contention with autonomous-delivery-pipeline.** Shared Max account = shared quota pool. Mitigation options: (a) pipeline pauses 07:00–22:00 local, (b) second Max seat for pipeline, (c) accept the risk and monitor. Which?
3. **Hosting cost — cheaper than dedicated GCE?** Duong flagged the ~$13/mo VM as too expensive for a personal one-user product. Options to evaluate: (a) host on her own computer (uptime + tunneling tradeoffs), (b) does Duong's existing Google Gemini Pro / Google One AI Pro $20/mo plan include any GCP credits that cover the footprint, (c) `e2-micro` free tier or Cloud Run-only stateless dispatcher. Pick before Phase 2.
4. **Multi-turn refinement inside a single job?** "Make the report more about X" after delivery — does she need that (session persistence), or is each job one-shot (much simpler)? Syndra's recommendation is one-shot first, add a 15-minute conversation window only if she complains.
5. **Mobile-responsive or desktop-only for v1?** Next.js handles both; changes UI budget. Does she work from her phone?
6. **Sister's agent personality — visible Bee character or invisible professional tool?** Duong's Strawberry roster leans heavy on character. His sister may want something flatter. Ask her directly; it shapes the profile body.
7. **Privacy boundary of `feedback-log.md`.** Will accumulate personal phrasing and possibly work-sensitive document context. MUST NOT live in the Strawberry repo. Private GitHub repo for the memory mirror is the plan — confirm Duong's okay with that.
8. **Tentative-rule graduation threshold** (2 confirmations, 10-session expiry) is a guess. Not gating; we ship with the defaults and tune after a few weeks.
9. **Failure mode when Vietnamese source coverage is thin** — degrade to English paraphrased back, or stop and ask her? Syndra's lean: degrade, note the gap in Vietnamese, offer English sources as fallback.

## 9. What this plan does NOT do

- Does not specify Tailwind / component library / exact UI framework details. Phase 3 territory.
- Does not write the `comments.py` OOXML helper — that's a Phase 1 implementation job.
- Does not name an implementer. Evelynn's call after Duong approves per Rule 8.
- Does not design the feedback UI — Phase 4 territory.
- Does not design the VN-news MCP scraper selectors — Phase 2 territory.
- Does not resolve Max ToS question #1. That's on Duong.
- Does not touch the autonomous-delivery-pipeline plan's shape. §5.1 notes the coupling; pipeline plan owns its own mitigation.

## 10. Cross-references

- `plans/proposed/2026-04-08-autonomous-delivery-pipeline.md` — shared-Max-quota dependency, §5.1 and §8.2 touch on it
- `plans/proposed/2026-04-09-operating-protocol-v2.md` — Layer-3 delegation primitives (this agent lives outside Strawberry's coordination fabric; she's a standalone product, not a teammate)
- `plans/approved/2026-04-08-skills-integration.md` — `/comment` and `/research` skills follow the format defined here
- `assessments/2026-04-08-protocol-leftover-audit.md` — unrelated but useful context for what "current state" means in the repo

