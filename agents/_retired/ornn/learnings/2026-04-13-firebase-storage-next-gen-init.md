# Firebase Storage Next Gen — Initialization Required Before Browser SDK Works

## Lesson

Firebase projects with `*.firebasestorage.app` buckets (Next Gen storage) must be explicitly initialized
via the Firebase Console before the browser JS SDK can upload. Without initialization:

- `https://firebasestorage.googleapis.com/v0/b/<project>.firebasestorage.app/o` returns HTTP 404
- The browser treats a non-2xx preflight response as a CORS failure — misleading error message
- `gcloud storage buckets list` returns empty for these buckets (invisible to standard GCS API)
- `gsutil cors set` and `gcloud storage buckets update --cors-file` both return 404
- `firebase deploy --only storage` fails with explicit "Firebase Storage has not been set up" message

## The real CORS is not the problem

The v0 API already serves `access-control-allow-origin: *`. No CORS header fix is needed — the 404
is the bug. Once the bucket is initialized in the Firebase Console, preflight returns 200.

## Firebase Admin SDK is unaffected

The Admin SDK on server-side (e.g., bee-worker GCE VM) accesses the bucket via service account
credentials and raw GCS API — bypasses Firebase Storage v0 entirely. Server-side writes work even
without Firebase Storage initialization.

## Diagnosis command

```bash
firebase deploy --only storage --dry-run
# If it says "Firebase Storage has not been set up" — initialization is required, not a CORS fix
```

## Fix

Firebase Console > project > Storage > Get Started. Selects the existing bucket, sets region.
