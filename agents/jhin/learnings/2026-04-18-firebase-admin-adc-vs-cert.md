# Learning: Firebase Admin SDK — ADC vs cert() on Cloud Run

**Date:** 2026-04-18
**Context:** PR #150 (B1 Firestore schema)

## Pattern

`cert(process.env.GOOGLE_APPLICATION_CREDENTIALS ?? "")` passes empty string to cert()
when the env var is unset. Firebase Admin SDK does not throw at initializeApp() — it
throws only at the first Firestore/Auth call, producing a cryptic runtime error rather
than a startup failure.

## Correct Pattern

On Cloud Run, use Application Default Credentials with no explicit credential arg:

```typescript
initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
```

ADC resolves the service account via the GCE metadata server automatically.
`GOOGLE_APPLICATION_CREDENTIALS` is only for local dev with a key file.

## Application

Flag any firebase-admin initializeApp() that passes `cert(envVar ?? "")` — the silent
fallback hides misconfiguration until first DB call.
