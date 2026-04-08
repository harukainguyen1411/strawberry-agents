# Plan ↔ Google Doc Mirror

How plan files in `plans/proposed/` get mirrored into Google Drive so Duong
can read and edit them on his phone or Mac during the review window.

## Why this exists

Plans are written by Opus agents on the Windows agent box. Duong needs to
review (and sometimes lightly edit) them from a phone or Mac. The existing
myapps plan-viewer is read-only-with-tap-to-approve. This system is the
inline-edit path: a one-shot publish, edit in Google Docs natively, fetch back.

## Lifecycle

```
[1] Opus agent writes plans/proposed/<file>.md, commits to main
       │
       ▼
[2] scripts/plan-publish.sh plans/proposed/<file>.md
       creates a Google Doc in the "Strawberry Plans (transient)" Drive folder,
       writes gdoc_id + gdoc_url back into the markdown frontmatter, commits.
       │
       ▼
[3] Duong reads/edits the doc on phone or Mac.
       │
       ▼
[4] scripts/plan-fetch.sh plans/proposed/<file>.md
       downloads the doc as markdown, writes plans/approved/<file>.md
       (status: approved), deletes the proposed copy, commits.
       │
       ▼
[5] Sonnet agent executes the approved plan (out of scope here).
       │
       ▼
[6] When the plan moves into plans/implemented/:
       scripts/plan-unpublish.sh plans/implemented/<file>.md
       trashes the Drive doc and strips gdoc_id/gdoc_url from frontmatter.
```

Three operations per plan: publish, fetch-back, unpublish. No daemons. No
watchers. No git hooks.

## The "Drive wins" rule

Between publish and fetch-back, the Google Doc is canonical. The proposed
markdown file is frozen by convention. If an agent edits it after publish,
those edits are clobbered when `plan-fetch.sh` runs. This is intentional —
it makes the source of truth unambiguous during the review window.

## Frontmatter survival

YAML frontmatter does not survive Drive's markdown converter natively. The
publish script wraps the frontmatter in a sentinel fenced block:

````
```yaml plan-frontmatter
title: ...
status: proposed
gdoc_id: ...
```
````

The fetch script unwraps it on the way back. If Duong manually deletes the
block in the doc, the fetch script falls back to the on-disk frontmatter.
**Duong should not edit inside the `plan-frontmatter` block.**

## Files

| Path | Purpose |
|---|---|
| `scripts/_lib_gdoc.sh` | Shared helpers: secrets handling, frontmatter parsing, OAuth token mint, fenced-block wrap/unwrap |
| `scripts/plan-publish.sh` | md → gdoc, write gdoc_id back, commit |
| `scripts/plan-fetch.sh` | gdoc → md (proposed → approved), commit |
| `scripts/plan-unpublish.sh` | trash gdoc, strip gdoc_id, commit |
| `scripts/google-oauth-bootstrap.sh` | One-time refresh-token mint (run on Mac) |

## Credentials

The plan-gdoc-mirror scripts source four single-key plaintext files from
`secrets/`. These are gitignored, written by `tools/decrypt.sh` from the
encrypted blobs, and never re-encrypted by these scripts:

| File | Variable | Source blob |
|---|---|---|
| `secrets/google-client-id.env` | `GOOGLE_CLIENT_ID` | `secrets/encrypted/google-client-id.age` |
| `secrets/google-client-secret.env` | `GOOGLE_CLIENT_SECRET` | `secrets/encrypted/google-client-secret.age` |
| `secrets/google-refresh-token.env` | `GOOGLE_REFRESH_TOKEN` | `secrets/encrypted/google-refresh-token.age` |
| `secrets/google-drive-plans-folder-id.env` | `GDRIVE_PLANS_FOLDER_ID` | `secrets/encrypted/google-drive-plans-folder-id.age` |

The folder id Duong handed us is `1ygXvAK2mP-JnCs5Mq3jiszho64MuKrdU` (in
his personal My Drive).

The scripts deliberately do **not** call `age` themselves. Decryption is
the exclusive job of `tools/decrypt.sh` per the encrypted-secrets discipline.
To populate a credential, do:

```bash
cat secrets/encrypted/google-refresh-token.age \
  | tools/decrypt.sh --target secrets/google-refresh-token.env --var GOOGLE_REFRESH_TOKEN
```

Repeat for each of the four credentials. After that, the plan-gdoc-mirror
scripts can run.

### OAuth scope

`https://www.googleapis.com/auth/drive.file` only. The agent can only see
and modify files it created. It cannot read existing Drive content.

### Rotating credentials

If the refresh token leaks or expires (`invalid_grant` from any script):

1. Revoke the token at https://myaccount.google.com/permissions
2. Re-run `scripts/google-oauth-bootstrap.sh` on Mac
3. Replace `GOOGLE_REFRESH_TOKEN` in the encrypted blob

## Bootstrap (one-time, Duong runs)

1. Create a Google Cloud project, enable the Google Drive API
2. Configure the OAuth consent screen (External, single test user = your account)
3. Create an OAuth 2.0 Client of type "Desktop app". Download the JSON.
4. Save the JSON at `secrets/google-oauth-client.json` on Mac (gitignored,
   bootstrap-only — not consumed by the daily scripts).
5. Run `./scripts/google-oauth-bootstrap.sh` on Mac. Approve in browser.
   Capture the refresh token from stdout.
6. Manually create a Drive folder named "Strawberry Plans (transient)" or
   reuse the existing one. Copy the folder id from the URL.
7. Encrypt each of `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`,
   `GOOGLE_REFRESH_TOKEN`, `GDRIVE_PLANS_FOLDER_ID` into its own age blob
   under `secrets/encrypted/` via the encrypted-secrets pipeline. On the
   Windows agent box, decrypt each blob to its `.env` file using
   `tools/decrypt.sh`.
8. Verify by publishing a test plan.

## Idempotency

- `plan-publish.sh` re-run on a plan that already has `gdoc_id`: updates the
  doc body in place. If the doc was deleted from Drive, creates a new one.
- `plan-fetch.sh`: not idempotent — it deletes the proposed copy. Run once.
- `plan-unpublish.sh` re-run on a plan with no `gdoc_id`: no-op.
- All three refuse to operate on files with uncommitted changes.

## Known limitations

- Code block language hints don't survive the round trip.
- Tables round-trip but column widths reset.
- Multi-paragraph blockquotes occasionally collapse.
- Embedded HTML is lost. Plans should not contain HTML.
- Only `proposed → approved` transitions use this round trip. Other moves
  (e.g. `proposed → archived`) bypass the gdoc layer entirely.

## Out of scope

- Real-time sync, watchers, daemons, automatic publish on commit.
- Coordination with the myapps plan-viewer. If Duong uses both for the same
  plan, last writer wins.
- Diffing what changed in the doc vs the original markdown.
- Multi-user review.
