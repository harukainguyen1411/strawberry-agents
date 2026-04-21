---
title: Plan ↔ Google Doc Mirror (Review Workflow)
status: implemented
owner: swain
created: 2026-04-08
---

# Plan ↔ Google Doc Mirror (Review Workflow)

## Problem

Duong writes plans on the Windows agent box but reads and edits them on his phone or Mac. He's already in the Google ecosystem (Gemini, Drive, Docs apps everywhere). He does not want to set up Working Copy + iOS git for the *review* step — only for read/edit during the approval window.

The existing `2026-04-05-plan-viewer.md` solves a different problem (browse + tap-to-approve in myapps via GitHub Contents API). It is read-mostly, no inline editing. This plan complements it by giving Duong an *editable* surface during the review window. See "Relationship to plan-viewer" below.

## Goal

Make the lifecycle of a single plan look like this, with three explicit operations and nothing in between:

1. **Publish** — agent creates the plan in `plans/proposed/<file>.md`, commits to main, then pushes the file as a Google Doc into a designated Drive folder. Returns a shareable link.
2. **Review** — Duong opens the doc on his phone or Mac. Reads, edits inline if needed. Tells Evelynn "approved."
3. **Fetch + approve** — Evelynn pulls the (possibly edited) doc back as markdown, writes it to `plans/approved/<file>.md`, deletes the proposed copy, commits.
4. **Execute** — separate Sonnet agent (delegated by Evelynn after approval, not by this plan) runs the work.
5. **Unpublish** — when the plan moves to `plans/implemented/`, the Google Doc is deleted from Drive. Source of truth is git from this point on.

Three operations per plan: publish, fetch-back, delete. All explicit. No watchers, no daemons, no real-time sync.

## Non-Goals

- Real-time two-way sync. Lifecycle is bounded.
- Multi-user collaboration, comment threading, plan diffing, web UIs.
- Replacing the plan-viewer (myapps GitHub-API approach). They coexist.
- Editing plans that are already `approved/`, `in-progress/`, or `implemented/`. Edit window is exactly the proposed → approved transition.
- Bypassing git as source of truth. Drive is a transient mirror; git is canonical.

## Relationship to `2026-04-05-plan-viewer.md`

**Verdict: coexist. Do not extend, do not supersede.** They solve adjacent problems.

| Concern | plan-viewer (myapps) | plan-gdoc-mirror (this plan) |
|---|---|---|
| Read on phone | yes | yes |
| Tap-to-approve (no edit) | yes | no |
| Inline edit on phone | no | yes |
| Native Google ecosystem | no | yes |
| Requires myapps deployment | yes | no |
| Requires Google API auth | no | yes |
| Triggered by | Duong opening myapps | agent or Duong CLI |

The plan-viewer is the "I just want to read this and approve as-is" path. This plan is the "I want to actually edit a paragraph before approving" path. Duong uses whichever fits the moment. They don't share code, don't conflict — but if both are active, the rule is: **whichever path Duong uses to approve is the one whose content lands in `plans/approved/`.** If Duong edits the Google Doc *and* taps approve in myapps, the plan-viewer commit happens first (it's a direct GitHub API write), then the gdoc fetch-back overwrites it. We accept that — Duong shouldn't do both for the same plan.

## Architecture

### Flow

```
[1] Opus agent writes plans/proposed/<file>.md
        |
        | git commit + push (chore: prefix)
        v
[2] ./scripts/plan-publish.sh <file>
        |
        | converts md -> gdoc, uploads to designated Drive folder
        | writes gdoc id back into the md frontmatter
        | git commit (chore: link gdoc)
        v
[3] Duong opens the doc on phone/Mac, reads, edits
        |
        | tells Evelynn "approved" via chat
        v
[4] ./scripts/plan-fetch.sh <file>
        |
        | downloads gdoc as markdown
        | writes plans/approved/<file>.md (destructive — gdoc wins)
        | deletes plans/proposed/<file>.md
        | leaves the Drive doc in place for now
        | git commit
        v
[5] Sonnet agent executes (out of scope for this plan)
        |
        v
[6] When plan moves into plans/implemented/:
        ./scripts/plan-unpublish.sh <file>
        |
        | deletes the Drive doc
        | strips gdoc_id from frontmatter
        | git commit
```

Three scripts. One frontmatter field. No daemons.

### Decision 1 — Auth: OAuth user credentials, not service account

**Recommendation: OAuth user credentials (installed-app flow), with the refresh token stored in `secrets/encrypted/google.age`.**

Trade-off table:

| Concern | Service Account | OAuth User Creds (installed app) |
|---|---|---|
| Doc shows up in Duong's "My Drive" natively | no — lives in service account's drive, must be shared | yes — created directly in Duong's Drive |
| Phone access via normal Google Docs app | painful (requires sharing each doc, opens as "shared with me") | native, no extra steps |
| Setup complexity | low (download json, done) | medium (one-time OAuth dance to mint refresh token) |
| Token rotation | static key, no expiry, leaks are bad forever | refresh token, can be revoked from Google account UI in one click |
| Blast radius if leaked | full access to service account drive + any docs ever shared with it | scoped to whatever OAuth scopes were granted (drive.file is enough — see below) |
| Scope minimization | hard — service accounts get broad scopes | easy — `drive.file` only touches files the app created |

The deciding factor is **`drive.file` scope**. With OAuth + `drive.file`, the agent can only see and modify files *it created*. It cannot read Duong's existing Drive contents. If the refresh token leaks, an attacker can list and read plan docs the agent published (already in git anyway) and create new docs in Duong's drive (annoying, not catastrophic). This is the tightest blast radius available.

A service account would force every doc to be "shared from a robot account," which is awkward in the Drive UI and doesn't show up cleanly in Duong's "Recent" on the phone.

**Failure modes:**
- **OAuth refresh token revoked / expired** (Google revokes after 6 months of inactivity, or if password changed): publish/fetch fails with `invalid_grant`. Recovery: re-run the one-time OAuth bootstrap. Document this clearly.
- **Refresh token leaked**: revoke at [myaccount.google.com → Security → Third-party access](https://myaccount.google.com/permissions), re-bootstrap. Plan docs in Drive are not sensitive (they're already in public-to-Duong git), so blast radius is low.
- **Network failure during publish**: script aborts before writing `gdoc_id` to frontmatter. Idempotent retry — the script must handle "no gdoc_id yet" as "create new doc" and "has gdoc_id but doc 404s on Drive" as "create new doc." See "Idempotency" below.

### Decision 2 — Markdown round-trip fidelity: native Drive markdown import/export, with frontmatter preserved as a fenced YAML block

Google Docs added native markdown import/export in 2024. It handles:

- **Headings (h1-h6)**: clean round-trip.
- **Bold, italic, links**: clean.
- **Bulleted and numbered lists**: clean. Nested lists round-trip in most cases — occasional indent normalization.
- **Fenced code blocks (` ``` `)**: preserved as monospace blocks. Language hint is *lost* on import to gdoc and not recoverable on export. Mitigation: agents accept that ```ts vs ```bash don't survive. Doesn't matter for plan readability.
- **Tables**: round-trip but cell formatting can drift; column widths reset. Acceptable for plans.
- **Inline code (`` ` ``)**: preserved as monospace span.
- **YAML frontmatter**: this is the tricky one. Drive's markdown converter does not understand `---` YAML frontmatter and will render it as a literal paragraph. On export it comes back as a literal paragraph, not as frontmatter delimiters.

**Frontmatter mitigation:** the publish script wraps the YAML frontmatter in a fenced code block before upload, with a sentinel marker:

```
```yaml plan-frontmatter
title: Foo
status: proposed
owner: swain
created: 2026-04-08
gdoc_id: abc123
```
```

The fetch script recognizes the ` ```yaml plan-frontmatter ` fence on the way back, unwraps it, and re-emits as `---`-delimited frontmatter. Duong is told (in `secrets/README.md` or a docs note) **do not edit inside the plan-frontmatter block**. If he edits status manually, fetch-back honors it. If he deletes the block entirely, fetch-back uses the previous on-disk frontmatter as a fallback.

**What gets mangled and we accept:**
- Code block language hints (cosmetic).
- Table column widths (cosmetic).
- Multi-paragraph blockquotes occasionally collapse (rare).
- HTML embedded in markdown: lost. Plans should not contain HTML.

**What we explicitly test in the success criteria** (see below): a known plan with all of headings, lists, code blocks, tables, links, and frontmatter round-trips through publish → fetch and produces a markdown file that re-renders identically in any markdown viewer.

### Decision 3 — Plan ↔ Google Doc mapping: frontmatter field `gdoc_id`

Three options were considered:

| Option | Survives rename | Survives directory move | Visible in plan file | Notes |
|---|---|---|---|---|
| (a) `gdoc_id` in frontmatter | yes | yes | yes | one source of truth, travels with the file |
| (b) sidecar `<file>.gdoc` | yes | requires moving sidecar in lockstep | yes (separate file) | doubles file count, easy to forget on `git mv` |
| (c) external manifest `plans/.gdoc-map.json` | yes | yes | no | yet another file to keep in sync, race conditions |

**Recommendation: (a) frontmatter field `gdoc_id`.** It travels with the file content. When the plan moves from `plans/proposed/` to `plans/approved/` via the fetch script, the field is already inside the file being moved — nothing extra to track. A simple grep tells you which plans have published docs.

Frontmatter shape after publish:

```yaml
---
title: Plan ↔ Google Doc Mirror (Review Workflow)
status: proposed
owner: swain
created: 2026-04-08
gdoc_id: 1A2B3C4D5E6F_example
gdoc_url: https://docs.google.com/document/d/1A2B3C4D5E6F_example/edit
---
```

`gdoc_url` is redundant with `gdoc_id` but is the thing Duong actually clicks. Storing both is cheap.

### Decision 4 — Trigger model: manual scripts, no automation

**Recommendation: manual CLI scripts, invoked by Evelynn or by Duong directly.**

```
./scripts/plan-publish.sh    plans/proposed/2026-04-08-plan-gdoc-mirror.md
./scripts/plan-fetch.sh      plans/proposed/2026-04-08-plan-gdoc-mirror.md
./scripts/plan-unpublish.sh  plans/implemented/2026-04-08-plan-gdoc-mirror.md
```

Why not automation:

- A git hook or GitHub Action that publishes on every commit to `plans/proposed/` would publish drafts the agent doesn't want published yet, would publish things the agent meant to delete, would re-publish on every typo fix, and would create orphaned Drive docs whenever a plan is moved or renamed. The blast radius of "wrong thing in Drive" is low but the cleanup is annoying.
- A watcher process violates the "no daemons" constraint.
- Manual aligns with "we don't need to be too complicated" and gives the agent (or Duong) explicit control over the moment a plan goes external.

In practice the publish call happens **once**, immediately after the plan is committed. Evelynn or the planning Opus agent can wire it as the next command after `git commit`, but it's still a discrete shell call, not an event subscription.

### Decision 5 — Cleanup: tied to plan moving into `plans/implemented/`

**Recommendation: cleanup happens when a plan moves into `plans/implemented/`.**

Options considered:

| Option | Cognitive overhead | Failure mode |
|---|---|---|
| (a) explicit `plan-unpublish.sh` per plan | medium — must remember to call it | plan rots in Drive forever if forgotten |
| (b) automatic when plan moves to `plans/implemented/` | low — natural endpoint already exists | only fails if the move isn't done (which would be a separate bug) |
| (c) age-out after N days | none for Duong, but creates uncertainty | doc disappears mid-review if N is wrong |

**Recommendation: (b), implemented as a check inside the agent's "move plan to implemented" routine.** When the agent (or whoever) moves a plan into `plans/implemented/`, it calls `plan-unpublish.sh` as part of that step. If the plan has no `gdoc_id`, the script is a no-op. This puts cleanup on the same step as the natural lifecycle event.

We also keep `plan-unpublish.sh` callable manually for the "Duong wants to kill the doc early" case.

### Decision 6 — Conflict resolution: Google Doc wins during the review window

**Rule: between publish and fetch-back, the Google Doc is canonical. Fetch-back is destructive on the markdown file.**

Stated more precisely:

- Once `plan-publish.sh` runs, the markdown in `plans/proposed/<file>.md` is **frozen** by convention. Agents must not edit it. The only field that may change is content inside the doc on Drive.
- `plan-fetch.sh` overwrites the markdown file with whatever is in the doc. No three-way merge, no diff prompt.
- If an agent accidentally edits the proposed markdown after publish, those edits are lost on fetch-back. This is a feature: it forces the rule that the doc is canonical in the review window.

This rule must be documented in `secrets/README.md` (or a new `architecture/plan-gdoc-mirror.md` — see "Docs touched" below) and stated in the PR description for the implementing PR.

The plan-viewer (myapps approve button) does not coordinate with this. If Duong uses both for the same plan, the last writer wins, and Duong is on the hook for not doing that. We do *not* try to detect and merge — that's the kind of complexity Duong explicitly told us to avoid.

### Decision 7 — Credentials: depends on the encrypted-secrets plan

The OAuth client secret and the long-lived refresh token live in `secrets/encrypted/google.age`. This plan **depends on `2026-04-08-encrypted-secrets.md` landing first.**

If the encrypted-secrets plan slips, the temporary path is:

- OAuth client secret (downloaded JSON from Google Cloud Console) at `secrets/google-oauth-client.json` (gitignored).
- Refresh token at `secrets/google-refresh-token` (gitignored, 600 perms).
- Both must be present on the Windows agent box where the scripts run.
- Mac doesn't need them — Mac never runs publish/fetch (Mac is the *reading* surface, not the *executing* surface).

Once encrypted-secrets lands, both files migrate into `secrets/encrypted/google.age` as `OAUTH_CLIENT_JSON` and `REFRESH_TOKEN` keys, consumed via `scripts/secret-use.sh` per the standard discipline (no plaintext in shell variables).

**The implementation PR must check for the encrypted-secrets feature first** and use it if available; otherwise use the gitignored fallback paths and log a warning telling Duong to migrate after encrypted-secrets lands.

### Decision 8 — Drive folder layout

A single dedicated folder in Duong's Drive: **"Strawberry Plans (transient)"**.

- Created manually by Duong during bootstrap. The folder ID is stored as `GOOGLE_DRIVE_PLANS_FOLDER_ID` in the same encrypted secrets blob as the OAuth credentials.
- Every published doc lives directly in this folder. No subfolders by status — status is in the doc title and the plan moves through git directories, not Drive directories.
- The folder name has "(transient)" as a deliberate visual reminder that anything in here is mirror, not source. Anything Duong wants to keep should live in git.

Doc title format: `[strawberry] <plan-filename-without-extension>` — e.g. `[strawberry] 2026-04-08-plan-gdoc-mirror`. The `[strawberry]` prefix makes search clean and avoids collisions with any other plans Duong has elsewhere.

## Idempotency and Error Handling

The scripts must survive being re-run after partial failures. Concrete rules:

**`plan-publish.sh <file>`:**
1. Read the markdown file. Parse frontmatter.
2. If `gdoc_id` exists, attempt `drive.files.get(gdoc_id)`.
   - If the doc exists, treat publish as "update": replace the doc body with the current markdown content. Do not create a new doc.
   - If the doc 404s (deleted from Drive), treat as "create": fall through to step 3.
3. Convert markdown → Drive's markdown import format (single API call: `drive.files.create` with `mimeType=application/vnd.google-apps.document` and the markdown as the request body).
4. Move the new doc into the configured `GOOGLE_DRIVE_PLANS_FOLDER_ID`.
5. Update the local markdown file's frontmatter with `gdoc_id` and `gdoc_url`.
6. `git add`, `git commit -m "chore: link gdoc for <filename>"`, push.

**`plan-fetch.sh <file>`:**
1. Read frontmatter, get `gdoc_id`. If missing, error: "plan was never published."
2. `drive.files.export(gdoc_id, mimeType=text/markdown)` → string.
3. Unwrap the `yaml plan-frontmatter` fenced block back into `---`-delimited frontmatter.
4. If the `yaml plan-frontmatter` block was deleted by Duong, fall back to the on-disk frontmatter.
5. Compute target path: if source was `plans/proposed/<file>.md`, target is `plans/approved/<file>.md`. (Other transitions are out of scope.)
6. Write target file. Delete source file.
7. `git add`, `git commit -m "chore: approve <filename> via gdoc fetch"`, push.
8. Do **not** delete the Drive doc here. That happens in unpublish.

**`plan-unpublish.sh <file>`:**
1. Read frontmatter, get `gdoc_id`. If missing, no-op (exit 0).
2. `drive.files.delete(gdoc_id)`. If 404, treat as success (already gone).
3. Strip `gdoc_id` and `gdoc_url` from the markdown frontmatter.
4. `git add`, `git commit -m "chore: unpublish gdoc for <filename>"`, push.

All three scripts must be safe to re-run. None of them should ever silently overwrite local uncommitted edits — they should refuse to run if `git status` shows the target file as modified.

## Bootstrap

One-time setup, manually executed by Duong:

1. **Google Cloud project:** create a new project at [console.cloud.google.com](https://console.cloud.google.com), enable the Google Drive API. Project name: "strawberry-plan-mirror" or similar.
2. **OAuth consent screen:** configure as "External," user type single-user, add Duong's Google account as a test user. No verification needed for personal use under test mode.
3. **OAuth client:** create an OAuth 2.0 client of type "Desktop app." Download the JSON. This is the `OAUTH_CLIENT_JSON`.
4. **Initial token mint:** run `./scripts/google-oauth-bootstrap.sh` once. This:
   - Opens a browser on Mac to the Google consent screen (or prints a URL to paste into a browser if running headless on Windows).
   - Asks for `drive.file` scope.
   - Receives the auth code, exchanges for a refresh token.
   - Writes the refresh token to `secrets/encrypted/google.age` (or the gitignored fallback path).
5. **Drive folder:** create "Strawberry Plans (transient)" in Duong's Drive manually. Copy the folder ID from the URL. Add it to the encrypted secrets as `GOOGLE_DRIVE_PLANS_FOLDER_ID`.
6. **Verify:** `./scripts/plan-publish.sh plans/proposed/<some-test-plan>.md` and confirm a doc shows up in the folder with the correct title.

This is bootstrap. Agents do not run it. Duong runs it once. After this, the daily flow is just the three scripts.

## File Layout

```
scripts/
  plan-publish.sh             # md -> gdoc, write gdoc_id back, commit
  plan-fetch.sh               # gdoc -> md (proposed -> approved), commit
  plan-unpublish.sh           # delete gdoc, strip gdoc_id, commit
  google-oauth-bootstrap.sh   # one-time refresh-token mint

secrets/
  encrypted/
    google.age                # OAUTH_CLIENT_JSON, REFRESH_TOKEN, GOOGLE_DRIVE_PLANS_FOLDER_ID
                              # (or gitignored fallback paths until encrypted-secrets lands)

architecture/
  plan-gdoc-mirror.md         # one-page how-it-works doc, written as part of implementation
```

No new long-running processes. No new MCP tools. No new agent capabilities. Just four scripts and one architecture doc.

## Implementation Language

**Recommendation: bash, calling `curl` and `jq` for the Drive API.**

The Drive API surface this plan needs is tiny — three or four endpoints. A full Google API client (Python `google-api-python-client`, Node `googleapis`) is overkill and adds dependencies. Bash + curl + jq matches the existing agent infra (already used in heartbeat scripts, secret helpers, etc.) and runs identically on Mac and Windows git-bash.

The one bash-awkward part is the OAuth refresh-token dance for the bootstrap script. That's a short Python or Node helper *only* for `google-oauth-bootstrap.sh` (which Duong runs once on Mac, not on Windows, and not from agent context). All daily-use scripts stay pure bash.

If implementation discovers bash makes any of this measurably worse, the implementer is allowed to rewrite a single script in Python — but not the whole set.

## Documentation Touched

- `architecture/plan-gdoc-mirror.md` (new): one page describing the lifecycle, the three scripts, and the "gdoc wins during review window" rule.
- `secrets/README.md` (existing, may not exist yet): add a section for `google.age` keys and what they're for.
- `CLAUDE.md`: optional small note in the plan workflow section pointing to the new architecture doc. Not critical.
- `plans/README.md` (if it exists): add the publish/fetch/unpublish step to the plan lifecycle description.

## Open Questions for Duong

*Answered 2026-04-08. Decisions recorded below; questions retained for audit.*

1. **Drive folder name and location.** Recommendation: top-level "Strawberry Plans (transient)" in My Drive. Acceptable, or do you want it nested under an existing folder?
2. **Doc deletion vs trash.** When `plan-unpublish.sh` runs, should it `drive.files.delete` (immediate, permanent) or `drive.files.update(trashed=true)` (recoverable for 30 days)? Recommendation: trash. Slightly more forgiving, no real downside since Duong's Drive isn't space-constrained.
3. **Bootstrap timing vs encrypted-secrets.** Do you want this plan implemented *before* encrypted-secrets lands (using gitignored credential files), or do you want to wait until encrypted-secrets is done so this plan ships clean? Both work; the second is cleaner.
4. **OAuth account.** Personal Google account, or a workspace/MMP one? Recommendation: personal — keeps work and personal completely isolated, and the test-mode consent screen flow is fine for a single-user app.

## Decisions (2026-04-08)

1. **Drive folder: pre-existing folder provided by Duong.** Folder ID `1ygXvAK2mP-JnCs5Mq3jiszho64MuKrdU` (in Duong's personal My Drive). The implementer should store this as `GDRIVE_PLANS_FOLDER_ID` and reference it from publish/fetch/unpublish scripts. Folder ID is not a secret (access is gated by OAuth scope), but the implementer should still source it from config rather than hardcoding it in scripts so it's swappable.
2. **Trashed, not hard-deleted.** `plan-unpublish.sh` uses `drive.files.update(trashed=true)`. Duong gets the 30-day recovery window for free.
3. **Sequencing: this plan ships *after* encrypted-secrets lands.** Google OAuth refresh token is stored in `secrets/encrypted/google.age` from day one. No gitignored-credential interim phase. The success criterion "refresh token stored in encrypted form" becomes a hard requirement, not a fallback.
4. **Personal Google account, always.** Not workspace, not MMP. Reinforced as a standing rule for any Strawberry-side Google integration: personal account only. Work-side Google integrations live in `~/Documents/Work/mmp/workspace/` and are out of scope for this repo.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Markdown round-trip mangles frontmatter | Wrap frontmatter in `yaml plan-frontmatter` fenced block, unwrap on fetch, fall back to on-disk frontmatter if Duong deletes the block |
| Refresh token expires (6mo inactivity / password change) | Document the symptom ("`invalid_grant` from publish/fetch") and the fix (re-run bootstrap). Low effort, low frequency. |
| Refresh token leaks | `drive.file` scope minimizes blast radius. One-click revoke at myaccount.google.com. Re-bootstrap. |
| Agent edits proposed markdown after publish | Convention rule: proposed plans are frozen post-publish. Documented in architecture doc. Lost edits are the agent's fault, not the system's. |
| Duong edits both myapps plan-viewer and gdoc for same plan | Last writer wins. Documented as "don't do that." Not worth detection logic. |
| Drive doc deleted manually by Duong mid-review | `plan-fetch.sh` errors with "doc not found, was it deleted?" Recovery: re-publish, redo edits. Annoying but rare. |
| Network failure during publish leaves orphan doc in Drive without `gdoc_id` in file | Idempotent publish: re-running creates a second doc. To detect orphans, list files in the folder and cross-reference against `git grep gdoc_id plans/`. Manual cleanup. |
| Drive's markdown converter changes behavior | Pin a fidelity test (a known plan that round-trips identically) and run it whenever a plan-mirror script changes. If it ever fails, we know Drive changed something. |
| Plan moves directories before fetch (proposed -> archived) | Out of scope. Fetch-back only handles proposed -> approved. Other transitions don't use the gdoc round-trip. |

## Success Criteria

- Four scripts exist and are executable: `plan-publish.sh`, `plan-fetch.sh`, `plan-unpublish.sh`, `google-oauth-bootstrap.sh`.
- A test plan with frontmatter, headings, lists, code blocks, tables, and links round-trips through publish → fetch and produces markdown that renders identically to the original. Frontmatter is preserved including the new `gdoc_id` field.
- Publishing the same plan twice does not create duplicate Drive docs.
- Unpublishing a plan deletes (or trashes) the Drive doc and strips `gdoc_id` from the markdown.
- All scripts refuse to run when the target file has uncommitted changes (no silent clobbering).
- `architecture/plan-gdoc-mirror.md` exists and accurately describes the lifecycle.
- The "gdoc wins during review window" rule is documented in the architecture doc and in the implementing PR description.
- Refresh token is stored in encrypted form (or in the documented gitignored fallback if encrypted-secrets has not yet landed).
- Plaintext credentials never appear in chat, agent context, shell history, or commit history.

## Ship-Now Defaults (recorded by katarina, 2026-04-08)

What landed in the first cut and what's deferred:

- **Shipped:** all four scripts (`plan-publish.sh`, `plan-fetch.sh`, `plan-unpublish.sh`, `google-oauth-bootstrap.sh`), shared library (`_lib_gdoc.sh`), offline test suite (`test_plan_gdoc_offline.sh`), architecture doc (`architecture/plan-gdoc-mirror.md`).
- **Shipped:** frontmatter wrap/unwrap with `yaml plan-frontmatter` sentinel; round-trip is byte-identical (covered by offline test).
- **Shipped:** idempotent publish (re-runs update the existing doc, recreate if 404).
- **Shipped:** require-clean check on the target file before any operation (no silent clobbering).
- **Shipped:** trash (not hard-delete) on unpublish per Decision 2.
- **Shipped:** OAuth refresh-flow inside a process-isolated subshell — credentials never leak to caller globals.
- **Shipped:** integration with the sibling encrypted-secrets pipeline. The plan-gdoc-mirror scripts source four single-key plaintext files from `secrets/` (`google-client-id.env`, `google-client-secret.env`, `google-refresh-token.env`, `google-drive-plans-folder-id.env`), each populated by `tools/decrypt.sh`. The scripts deliberately do not call `age` directly; that's `tools/decrypt.sh`'s exclusive job per the encrypted-secrets discipline.
- **Deferred — credentials:** the four `secrets/encrypted/google-*.age` blobs do not yet exist (waiting on Duong's Google Cloud Console bootstrap + the encrypted-secrets pipeline being usable). The plan-gdoc-mirror scripts will fail with a clear "missing credential file" error until they exist.
- **Deferred — end-to-end verification:** the publish → fetch → unpublish round trip against the live Drive API has NOT been executed because credentials are not yet provisioned. Offline tests pass. Re-test required after credentials land.
- **Deferred — fidelity test fixture:** the success criterion "a known plan with all of headings, lists, code blocks, tables, and links round-trips" needs to be run against real Drive once credentials exist. The test plan file should be checked in under `tests/fixtures/` at that time.
- **Deferred — automatic cleanup hook:** Decision 5 says `plan-unpublish.sh` should be invoked automatically as part of the agent routine that moves a plan into `plans/implemented/`. The script exists and is callable, but no agent routine wires it up yet. Follow-up for whoever adds the move-to-implemented helper.

## Out-of-Scope (Future Work)

- Automatic publish on `git commit` to `plans/proposed/`.
- Diff view of "what changed in the gdoc vs the original markdown" before approving.
- Comments / suggestions thread support (Drive supports this; we ignore it).
- Mirror to formats other than Google Docs (Notion, Dropbox Paper, etc.).
- Coordinating with the myapps plan-viewer (e.g. showing a "this plan is currently being edited in Drive" badge).
- Multi-user review (more than one Google account).
