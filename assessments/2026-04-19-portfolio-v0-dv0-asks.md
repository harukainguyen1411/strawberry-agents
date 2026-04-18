---
created: 2026-04-19
author: ekko
subject: Portfolio v0 — DV0 prerequisite asks for Duong
---

# Portfolio v0 — DV0 Prerequisite Asks

Duong, the following items are blocking v0 execution. Please fill in each section
and reply (or commit this file with answers). Answers feed directly into implementation
tasks V0.1–V0.7 and V0.20.

---

## DV0-1 — Firebase project for portfolio-v0

**Needed for:** V0.1 (Firebase project bootstrap)

**Context:** The existing Firebase projects are:

| Project Name      | Project ID                | Notes                        |
|-------------------|---------------------------|------------------------------|
| myapps            | `myapps-b31ea`            | Current prod (myapps)        |
| myapps staging    | `myapps-b31ea-staging`    | Current staging (myapps)     |

The portfolio tracker app code will live under
`apps/myapps/portfolio-tracker/` in `harukainguyen1411/strawberry-app`,
which is already under the `myapps` umbrella.

**Recommendation — reuse `myapps-b31ea` / `myapps-b31ea-staging`:**

- The ADR (§3, §9) places all app code in the `myapps` monorepo. Reusing the
  existing projects avoids GCP billing sprawl, keeps IAM/secrets in one place,
  and is consistent with where the other `apps/myapps/**` apps already deploy.
- Firestore, Auth, Functions, and Hosting all support multi-app configurations
  within one project via separate Hosting sites and Firestore security rules.
- The portfolio's Firestore data is isolated under `users/{uid}/...` with
  per-user rules (V0.3), so co-tenancy with any other myapps data is safe.

**Alternative — new dedicated project `strawberry-portfolio` (or similar):**

- Cleaner blast-radius isolation: portfolio data and Functions never share
  billing, quotas, or IAM roles with other myapps services.
- Costs an extra project slot and means maintaining a third Firebase config.
- Recommended only if myapps-b31ea already has tight Function quota usage or
  if you want hard billing separation from day one.

**Action required:** Confirm one of:

- [ ] **Reuse `myapps-b31ea` (prod) + `myapps-b31ea-staging` (staging)** — agent will
      commit `firebase.json` / `.firebaserc` targeting these project IDs.
- [ ] **Create a new project** — please create it in the GCP console (or run the
      commands below), then reply with the new project ID.

Commands to create a new project (run yourself — agent will not create without approval):

```sh
# Replace <NEW_PROJECT_ID> with your chosen ID (e.g. strawberry-portfolio)
gcloud projects create <NEW_PROJECT_ID> --name="Strawberry Portfolio"
firebase projects:addfirebase <NEW_PROJECT_ID>
```

---

## DV0-2 — Allowlisted email addresses

**Needed for:** V0.2 (Auth + allowlist)

Two emails to be committed to
`apps/myapps/portfolio-tracker/functions/config/allowlist.ts` (no secrets —
just two plain email strings, same as any auth config file).

**Action required:** Provide both emails:

- [ ] Email 1 (Duong): `_________________________`
- [ ] Email 2 (friend): `_________________________`

Note: `harukainguyen1411@gmail.com` is on file as Duong's email — confirm
whether to use this one or a different address.

---

## DV0-3 — Trading 212 sample CSV export

**Needed for:** V0.6 (CSV parser — T212)

A real T212 export from Duong's account, anonymized:
- Remove or replace real ticker names with synthetic ones if desired
  (e.g. `AAPL → STKA`, `TSLA → STKB`).
- Replace all monetary values with scaled-down fictions (e.g. divide by 10).
- The header row and column structure must be real — that is the load-bearing part.

Filename convention: `test/fixtures/t212-sample.csv`

**Action required:** Drop the anonymized CSV file at the path above in
`harukainguyen1411/strawberry-app`, or share the raw export and an agent
will anonymize it for you.

Note: V0.6 can proceed with synthetic fixtures derived from T212 documentation
if the real sample is delayed, but must be replaced with the real anonymized
sample before V0.20 sign-off.

---

## DV0-4 — Interactive Brokers Activity Statement sample

**Needed for:** V0.7 (CSV parser — IB)

An IB Activity Statement CSV export, anonymized using the same approach as DV0-3.
IB Activity Statements use a multi-section format (Trades section, Open Positions
section, etc.) — the multi-section structure is the tricky part, so a real sample
is especially high-value here.

Filename convention: `test/fixtures/ib-sample.csv`

**Action required:** Same as DV0-3 — drop the file or share the raw export.

Note: Same slip rule as DV0-3 — synthetic fixtures unblock V0.7 build, but real
sample required before V0.20.

---

## DV0-5 — Discord channel `#portfolio-digest` + webhook

**Needed for:** v2 (Claude digest), not v0 — tracked separately under T9.

No action needed from Duong at this stage. Ekko will stand it up when v2 kicks off.

---

## DV0-6 — Figma file "Strawberry — Portfolio v0"

**Needed for:** V0.18 QA gate (rule 16) — tracked under T4b / Neeko.

Neeko is handling this. No action needed from Duong at this stage.

---

## DV0-7 — v0 exit-criteria sign-off (Duong)

**Needed for:** V0.20

Duong runs the v0 happy path end-to-end on his own machine against the
emulator build and signs off in `assessments/2026-04-DD-portfolio-v0-exit-signoff.md`.

No agent may close V0.20 autonomously — this is a human gate by design.

**Action required:** No action until V0.1–V0.19 are all merged and green.
At that point, Evelynn will ping you with the sign-off checklist.

---

## Summary

| ID    | Blocker?        | Status      |
|-------|-----------------|-------------|
| DV0-1 | Yes (V0.1)      | Awaiting Duong decision |
| DV0-2 | Yes (V0.2)      | Awaiting 2 email addresses |
| DV0-3 | Soft (V0.6)     | Can use synthetic fixtures; real needed for V0.20 |
| DV0-4 | Soft (V0.7)     | Can use synthetic fixtures; real needed for V0.20 |
| DV0-5 | No (v2 only)    | Tracked under T9 |
| DV0-6 | No (V0.18 only) | Tracked under T4b / Neeko |
| DV0-7 | Yes (V0.20)     | Human gate — no action until V0.18+V0.19 green |
