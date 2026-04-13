# Firebase Storage CORS Investigation — 2026-04-13

## What we were trying to fix

Browser error when Haruka uploaded a `.docx` via the Bee app: `Access to XMLHttpRequest at 'https://firebasestorage.googleapis.com/v0/b/myapps-b31ea.firebasestorage.app/o?...' from origin 'https://apps.darkstrawberry.com' has been blocked by CORS policy: Response to preflight request doesn't pass access control check.`

## Root cause: Firebase Storage was never initialized

The bucket `myapps-b31ea.firebasestorage.app` exists as a raw GCS-adjacent resource (created automatically when the Firebase project was set up or when the Admin SDK first ran), but **Firebase Storage was never initialized** for this project via the Firebase Console. Specifically:

- `firebase deploy --only storage` returns: `Firebase Storage has not been set up on project 'myapps-b31ea'. Go to https://console.firebase.google.com/project/myapps-b31ea/storage and click 'Get Started' to set up Firebase Storage.`
- `gcloud storage buckets list --project=myapps-b31ea` returns empty — the bucket is not visible to the standard GCS API under this account.
- `https://firebasestorage.googleapis.com/v0/b/myapps-b31ea.firebasestorage.app/o` returns HTTP 404. The browser interprets a non-2xx preflight response as a CORS failure, regardless of `access-control-allow-origin` headers present.
- The `firebasestorage.googleapis.com` API was also disabled at the start of investigation (Ornn enabled it during this session).
- The Firebase Admin SDK on bee-worker successfully writes to the bucket because it goes through a different code path (GCS service account credentials, not Firebase Storage v0 API).

## Why gcloud couldn't see it

The bucket uses the `firebasestorage.app` domain naming, which is Firebase's "Next Generation" storage. These buckets are not visible via `gcloud storage buckets list` to standard user accounts — they appear to be managed by a different GCS namespace. The Firebase Storage v0 REST API (used by the browser JS SDK) also cannot route to this bucket because Firebase Storage was not initialized, so there's no mapping between the bucket name and the Firebase Storage backend.

## The CORS headers are not actually the problem

A `curl` preflight against the v0 endpoint confirms `access-control-allow-origin: *` IS returned — but with HTTP 404 status. The real fix is not a CORS header change. It is initializing Firebase Storage so the v0 API can resolve the bucket.

## What needs to happen (Duong action required)

**Step 1:** Visit https://console.firebase.google.com/project/myapps-b31ea/storage and click "Get Started". Choose the existing bucket `myapps-b31ea.firebasestorage.app` and the `us-central1` region. This initializes Firebase Storage and makes the v0 API functional.

**Step 2:** After initialization, `firebase deploy --only storage` will work. Run it from `apps/myapps/` to deploy `storage.rules`.

**Step 3:** Verify the fix with:
```bash
curl -X OPTIONS -i "https://firebasestorage.googleapis.com/v0/b/myapps-b31ea.firebasestorage.app/o?name=test" \
  -H "Origin: https://apps.darkstrawberry.com" \
  -H "Access-Control-Request-Method: POST"
```
Expect: `HTTP/2 200` (not 404) with `access-control-allow-origin: *`.

**Step 4 (optional):** If after initialization the CORS policy is still restrictive, set explicit CORS via `/tmp/cors.json` using:
```bash
gsutil cors set /tmp/cors.json gs://myapps-b31ea.firebasestorage.app
```
But the v0 API already serves `access-control-allow-origin: *` — additional CORS configuration may not be necessary once the 404 is resolved.

## Secondary finding: two useBee.ts files

`apps/yourApps/bee/src/useBee.ts` (root-level) hardcodes `gs://myapps-b31ea.appspot.com` as the `storageUri` passed to bee-worker. `apps/yourApps/bee/src/composables/useBee.ts` uses `gs://myapps-b31ea.firebasestorage.app`. The bee-worker server-side code should be checked to confirm which path it reads from.

## What Ornn did during this session

- Enabled `firebasestorage.googleapis.com` API on `myapps-b31ea` (was disabled, needed for firebase deploy + bucket management)
- Investigated all available API surfaces: gcloud storage, Firebase Storage v0/v1alpha/v1beta, Firebase Management API
- Confirmed root cause: uninitialized Firebase Storage, not a CORS header misconfiguration
