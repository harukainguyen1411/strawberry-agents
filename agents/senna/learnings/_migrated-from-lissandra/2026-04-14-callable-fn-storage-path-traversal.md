# Callable Cloud Function — client-supplied storage path traversal

**Date:** 2026-04-14
**Seen in:** PR #97 (bee-worker docxUrl), PR #105 (beeIntakeStart fileRef)

## Pattern

Firebase callable Cloud Functions that accept a storage path (`fileRef`, `docxUrl`, etc.) from the client and pass it directly to `bucket.file(path)` or construct a `gs://` URL from it are vulnerable to path traversal. A malicious or buggy client can supply an arbitrary path that the service account can read.

## Fix

Before any `bucket.file(path)` call, assert that the path starts with the expected user-scoped prefix:

```typescript
if (!fileRef.startsWith(`bee-temp/${uid}/`)) {
  throw new HttpsError("invalid-argument", "invalid_file_ref");
}
```

The prefix must include the authenticated `uid` so one user cannot access another user's uploads.

## Also check

- Any GCS URL constructed from a stored `fileRef` and appended to public outputs (GitHub issues, notifications) — the stored value was originally caller-supplied and must be treated as untrusted at write time.
- Submit/finalize handlers that re-read `fileRef` from Firestore do not need to re-validate (stored by the server), but the write path must validate before storing.
