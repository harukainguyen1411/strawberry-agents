---
id: 2026-04-13-fix-bee-storage-rules
title: Fix Bee Storage Rules — path mismatch + placeholder UID
status: approved
created: 2026-04-13
owner: katarina
---

## Problem

Two bugs block Bee uploads with a 403. First, `apps/myapps/storage.rules` matches path `bee/{userId}/{jobId}/{file}` but the portal uploads to `bee-temp/{uid}/{timestamp}/input.docx` — different prefix, so the default-deny triggers. Second, the auth check compares `request.auth.uid` against the literal string `"SISTER_UID_PLACEHOLDER"` — a value that was never replaced — so even a path-matching request would be denied.

## Fix

Update `apps/myapps/storage.rules` to match the actual upload path `bee-temp/{uid}/{timestamp}/{file}`, allow read+write only when auth uid equals the hardcoded UID `0DJzc86i5MP74jAwwT4YjvbcAub2` AND matches the path uid segment, and enforce the existing file-type and size constraints on write. Worker-side writes use Admin SDK and bypass rules — no additional rule needed. All other paths remain default-deny.

## Verification

After CI deploys (storage deploy job in `release.yml` triggers on `apps/myapps/storage.rules` path filter): ask Duong to retry the Bee upload from her browser — expect success instead of 403.
