# Firebase Storage CORS — myapps-b31ea

## Bucket name

`myapps-b31ea.firebasestorage.app`

This is the SDK-facing name. It is a Firebase "Next Generation" storage bucket. The underlying GCS bucket is not visible via `gcloud storage buckets list` to the harukainguyen1411 account; it requires Firebase Storage initialization to be accessible via the Firebase JS SDK.

## Why gcloud/gsutil return 404

Next Gen Firebase Storage buckets (`*.firebasestorage.app`) are not standard GCS buckets from the perspective of the logged-in user account. They are managed by Firebase's storage backend. Both `gcloud storage buckets update` and `gsutil cors set` return 404 because these tools look up the bucket via the standard GCS JSON API, which doesn't expose this bucket to the harukainguyen1411 account.

## Firebase Storage initialization

Firebase Storage must be initialized via the Firebase Console before the browser JS SDK can upload. Without initialization, `https://firebasestorage.googleapis.com/v0/b/myapps-b31ea.firebasestorage.app/o` returns HTTP 404, which browsers interpret as a CORS failure.

To initialize: https://console.firebase.google.com/project/myapps-b31ea/storage — click "Get Started".

## CORS configuration

Once Firebase Storage is initialized, the v0 API serves `access-control-allow-origin: *` by default. Explicit CORS rules may not be required.

If explicit CORS is needed (e.g., to restrict origins or set specific headers), use a JSON file:

```json
[
  {
    "origin": [
      "https://apps.darkstrawberry.com",
      "https://darkstrawberry.com",
      "https://myapps-b31ea.web.app",
      "https://myapps-b31ea.firebaseapp.com",
      "http://localhost:5173",
      "http://localhost:5174"
    ],
    "method": ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"],
    "responseHeader": [
      "Content-Type",
      "Authorization",
      "Content-Length",
      "X-Requested-With",
      "x-goog-resumable"
    ],
    "maxAgeSeconds": 3600
  }
]
```

Apply with (if gsutil can see the bucket after initialization):
```bash
gsutil cors set cors.json gs://myapps-b31ea.firebasestorage.app
```

Or via firebase-tools if gsutil still cannot access it:
```bash
# No direct firebase-tools CORS command exists — use gsutil or GCP Console
```

## Verification

After initialization + CORS fix, verify:
```bash
curl -X OPTIONS -i "https://firebasestorage.googleapis.com/v0/b/myapps-b31ea.firebasestorage.app/o?name=test" \
  -H "Origin: https://apps.darkstrawberry.com" \
  -H "Access-Control-Request-Method: POST"
```
Expected: `HTTP/2 200` with `access-control-allow-origin: https://apps.darkstrawberry.com` (or `*`).

## Storage rules

`apps/myapps/storage.rules` — deploy with `firebase deploy --only storage` from `apps/myapps/`.

## Server-side (bee-worker)

The Firebase Admin SDK on bee-worker uses the GCS service account directly and bypasses the Firebase Storage v0 API. Server-side writes work regardless of Firebase Storage initialization status.
