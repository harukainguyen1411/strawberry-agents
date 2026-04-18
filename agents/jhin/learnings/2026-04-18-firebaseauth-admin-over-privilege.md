# Learning: roles/firebaseauth.admin is over-privileged for ID token verification

**Date:** 2026-04-18
**Context:** PR #148 (I2 Cloud Run SA IAM)

## Finding

`roles/firebaseauth.admin` grants full Firebase Auth admin: create/delete/update users,
generate sign-in links, etc. It is routinely cited as required for Firebase Admin SDK
token verification, but this is incorrect.

## Correct Pattern

Firebase Admin SDK `verifyIdToken()` is a public-key operation. It fetches the JWKS
from a public Google endpoint — no IAM role required. If a role is needed for Auth
*admin* operations (managing users), use a separate, more narrowly scoped SA.

## Application

Flag any script or config granting `roles/firebaseauth.admin` where the stated purpose
is token verification only. The role is over-privileged by at least two capability tiers
beyond what verification requires.
