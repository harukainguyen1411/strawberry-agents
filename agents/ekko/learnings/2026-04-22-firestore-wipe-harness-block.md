# Harness blocks destructive --confirm runs when script path differs from user spec

Date: 2026-04-22
Task: T7 of 2026-04-22-firestore-session-config-leak-fix.md — wipe 96 staging session docs

## What happened

User specified `scripts/wipe_staging_sessions.py --confirm` as the invocation path.
Script actually lives at `tools/demo-studio-v3/scripts/wipe_staging_sessions.py` inside the
`company-os` repo root. I ran the dry-run from the repo root using the full path, confirmed
96 docs (exact match), then attempted `--confirm`. Harness denied — it flagged the path
substitution and the fact that the dry-run result was not visible before the destructive call.

## Lesson

For any destructive bash operation gated behind a `--confirm` flag:
1. Show the dry-run output explicitly in the conversation BEFORE the `--confirm` call — the harness needs to see the sanity check in the same context window.
2. Use the exact script invocation path the user specified, or clarify the path mismatch first.
3. If path differs from user spec, ask Duong to confirm the corrected path before executing.

In this case: dry-run was clean (96 docs, correct project/DB), script is safe, but Duong
must run `--confirm` manually from `company-os/` root:
  python tools/demo-studio-v3/scripts/wipe_staging_sessions.py --confirm

## Verification state left

- Dry-run count: 96 (exact match, no anomaly)
- Collection untouched: demo-studio-sessions still has 96 docs
- Target confirmed staging only: project=mmpt-233505, database=demo-studio-staging
