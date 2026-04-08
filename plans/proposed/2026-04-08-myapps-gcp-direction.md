---
status: proposed
owner: swain
created: 2026-04-08
title: MyApps on Google Infrastructure — Direction, Not Migration
---

# MyApps on Google Infrastructure — Direction, Not Migration

> Rough plan. Alignment-level only. No commands, no configs, no implementer assigned.
> This plan exists to answer a question that is ambiguous, not to execute a migration.
> The actual architectural question is **"which Google?"**, not **"move to Google."**

---

## The Question, Restated

Duong asked: *how could we migrate myapps so that we use Google infrastructure from now on.*

The trap in that sentence is the word **migrate**. MyApps is already on Google infrastructure. Firebase Hosting is a Google product. Firestore is a Google product. Firebase Auth is a Google product. Every byte myapps serves is already being served out of a GCP region on google.com-owned hardware, billed to a Google-owned project (`myapps-b31ea`). There is no "move to Google" to perform, because we never left.

So before any infrastructure change is proposed, this plan's first job is to confirm what Duong actually wants. Below are the four plausible readings of his question, and I recommend one.

---

## Four Readings of "Move to Google"

### (A) Nothing to do — mental model correction

MyApps is already Google infrastructure. Firebase is a GCP product surface. If Duong's concern is "I want my app on Google, not some third-party cloud" — we are done. The only action is clarifying the mental model so this question doesn't recur.

**Cost:** zero. **Risk:** zero. **Value:** high — stops us burning cycles on a non-problem.

### (B) Formalize the GCP project underneath Firebase

Today `myapps-b31ea` exists as a Firebase project. A Firebase project **is** a GCP project with a Firebase wrapper on top. You can open it in the GCP Console right now and see it. What it is **not** is well-organized:

- Probably no explicit GCP Organization or folder structure
- Probably owned by a personal google.com identity rather than a cleanly separated billing org
- IAM is likely whatever Firebase initialization dropped in
- No audit logging policy
- No budget alerts
- No clearly-labeled environments (there is only one environment — prod)

Option B is: **keep Firebase, but treat the underlying GCP project as a first-class citizen.** Add governance. Add billing alerts. Add a proper IAM model. Possibly move the project under a GCP Organization tied to a domain Duong controls. This is mostly governance work, not migration work.

**Cost:** small to medium. **Risk:** low. **Value:** medium — mostly future-proofing.

### (C) Rip Firebase primitives out, replace with raw GCP services

This is the "real" migration reading. Firebase Hosting → Cloud Run or Cloud Storage + Cloud CDN. Firestore → Cloud SQL or Spanner or Firestore-in-Datastore-mode. Firebase Auth → Identity Platform (which is literally Firebase Auth rebadged with extra enterprise features, so this one is nearly free). CI would move off GitHub Actions to Cloud Build, image artifacts would land in Artifact Registry.

This is a massive amount of work. For a personal productivity app with one user (Duong) and occasional agent writes, **it is architectural malpractice**. You would spend weeks rebuilding primitives Firebase gives you for free, lose the real-time `onSnapshot` ergonomics that PR #54 depends on, lose the free tier, and gain essentially nothing except the ability to say "we use Cloud Run."

**Cost:** very high. **Risk:** high. **Value:** negligible for this app at this scale. **Do not do this.**

### (D) Expand GCP usage around what's already there

MyApps uses the Firebase slice of GCP but none of the adjacent GCP surface:

- **Secret Manager** — instead of a raw `FIREBASE_CONFIG` JSON blob stored as a GitHub secret
- **Cloud Logging / Cloud Monitoring** — no monitoring exists today
- **Cloud Build** — alternative to GitHub Actions, tighter GCP integration, but GitHub Actions is fine and changing it has no real upside right now
- **Artifact Registry** — not relevant until there's a container
- **Firebase Performance Monitoring** — cheapest observability win, drop-in SDK
- **Firebase Preview Channels** — native Firebase Hosting feature that gives you per-PR preview URLs with almost no work

Option D is additive. It does not move anything. It fills holes the snapshot already identifies.

**Cost:** small, incremental. **Risk:** low. **Value:** high — directly unblocks the autonomous-delivery-pipeline plan Syndra is writing.

---

## Recommendation

**(A) + (B)-lite + a focused slice of (D). Reject (C) outright.**

Concretely — and these are still alignment-level, not execution steps:

1. **Confirm (A) with Duong.** Make sure he understands Firebase = GCP. If his question was "am I already on Google?", the answer is yes and everything below becomes optional.
2. **Lightweight (B):** add billing alerts, add a minimal IAM review, add audit logging, decide whether the project belongs under a proper Google Workspace domain or stays under a personal account. Do not restructure organizations unless there's a real reason to.
3. **Targeted (D) to close ship-gaps:**
   - **Firebase Hosting Preview Channels** for per-PR previews (foundation for autonomous-delivery-pipeline)
   - **Firebase Performance Monitoring + Cloud Logging** for minimum viable observability
   - **Secret Manager** for `FIREBASE_CONFIG` and the service account key (or at minimum audit whether the current GitHub-secret approach is tolerable for a solo dev workflow — it may be)
   - **Automate Firestore index deploys** in CI (this is a GitHub Actions change, not a GCP migration)
4. **Explicitly defer (C).** Document that it was considered and rejected for scale reasons, so nobody revisits it without new information.

I am not married to this recommendation. If Duong comes back with "actually I want to learn raw GCP end-to-end and myapps is the vehicle," (C) becomes reasonable — but that's a learning project, not an infrastructure decision, and it should be framed that way.

---

## Ship-Gap Analysis (independent of which reading wins)

These gaps exist today and the autonomous-delivery-pipeline plan Syndra is writing cannot function without them being closed. Whichever reading of "move to Google" Duong picks, the gaps remain.

### Staging / preview environments
- **Gap:** only prod exists
- **Approach:** Firebase Hosting Preview Channels. Native feature. Per-branch or per-PR URLs with auto-expiry. No new infrastructure.
- **Failure mode:** preview channels share the same Firestore backend as prod — agents deploying previews can write to real data. Needs either a second Firebase project for staging data, or a runtime flag that points previews at a staging Firestore. Decision deferred to detailed phase.

### Monitoring / observability
- **Gap:** nothing. Agents deploying autonomously with zero visibility is genuinely dangerous.
- **Approach:** minimum viable = Firebase Performance Monitoring (client) + Cloud Logging (already on by default for the project) + a single uptime check on the public URL. Sentry is an alternative, not an addition.
- **Failure mode:** noisy alerts train Duong to ignore them. Threshold tuning matters more than tool choice.

### Firestore index deploys
- **Gap:** manual. Katarina is fixing PR #54 in parallel and the index is part of that fix, but the general problem — indexes not deployed from CI — remains.
- **Approach:** add a Firestore-indexes deploy step to the release workflow. Small change, high leverage.
- **Failure mode:** a bad index definition committed to main would auto-deploy and could brick queries. Need a review gate, not just automation.

### Secrets — `FIREBASE_CONFIG` as raw JSON in GH Secrets
- **Gap:** works but fragile. Rotating requires manually re-pasting JSON.
- **Approach:** two options — (1) leave it, accept the fragility for a solo-dev app; (2) move to Secret Manager and have CI pull at build time. Option 1 is genuinely defensible here. This is not a security problem, it is an ergonomics problem.
- **Failure mode:** moving to Secret Manager adds a new IAM surface CI must authenticate against. Trades one fragility for another. Recommend option 1 unless Duong has a specific reason to rotate often.

### Incident runbook
- **Gap:** none exists.
- **Approach:** a single markdown file under `apps/myapps/docs/runbook.md` covering: how to roll back a deploy, how to roll back a bad Firestore index, how to revoke a compromised service account, how to read the logs. One page. This is prerequisite to autonomous deploys.
- **Failure mode:** a runbook nobody reads. Must be short enough Duong or an agent will actually open it at 2am.

### Monorepo coupling — `apps/myapps/` inside strawberry
- **Gap:** myapps lives inside the agent-system repo. This couples a user-facing product to an internal agent system. CI for agents and CI for myapps are entangled. Git history is shared. Access control is shared.
- **Approach:** I am **not** recommending a split right now. The coupling is weird but functional, and splitting has real costs (shared tooling, shared CLAUDE.md, shared commit norms). Flag it as a known structural smell to revisit once myapps has a second user or real traffic. Do not split as part of this plan.
- **Failure mode:** if we split later, we lose the ability for agents to edit myapps code in the same working tree they live in. That's a real capability loss.

---

## Interaction with autonomous-delivery-pipeline

Syndra is writing `plans/proposed/2026-04-08-autonomous-delivery-pipeline.md` in parallel. Her plan describes **what** the autonomous pipeline does — preview envs per PR, agent-driven deploys, Discord integration, credential management, agent team structure. This plan describes **what infrastructure that pipeline sits on top of.**

Division of labor:
- **This plan (Swain):** the GCP/Firebase foundation — preview channels, observability, secrets, index automation, runbook, governance posture. The "ground."
- **Syndra's pipeline plan:** the orchestration, the agent workflows, the PR lifecycle, the Discord surface. The "machine."

Cross-reference: Syndra's plan should assume this plan's ship-gaps are closed as a prerequisite. If Duong approves only one of the two, **this plan should go first** — the pipeline cannot run on an unmonitored, un-preview-able, un-runbooked foundation.

I have not read Syndra's draft (it is being written in parallel). If her draft conflicts with the shape above, we reconcile in the detailed-phase, not here.

---

## PR #54 — explicit non-ownership

PR #54 (task list merge, blocked on Firestore index + `onSnapshot` listener) is called out in the snapshot as a blocker. **This plan does not own the fix.** Katarina is being dispatched in parallel against the already-approved `2026-04-05-myapps-task-list.md` plan. This plan simply notes PR #54 as a prerequisite that must land before preview channels and index automation can be meaningfully tested, and defers the fix to the existing owner.

---

## Open Questions for Duong

Only the ones that genuinely need his judgment. Evelynn absorbs the trivial stuff.

1. **What did you actually mean by "migrate to Google"?** (A), (B), (C), or (D)? My strong recommendation is A + light B + targeted D, and (C) is explicitly not worth doing for a personal app at this scale. Confirm or correct.
2. **Staging data isolation.** Preview channels are free and easy, but they share Firestore with prod by default. Do you want a second Firebase project for staging data, or are you comfortable with previews writing to real data as long as the runbook covers cleanup?
3. **Governance depth.** Do you want the GCP project placed under a proper Google Workspace / Cloud Organization, or is the current personal-account-ownership model fine? This is a "now or never" decision in the sense that restructuring later is painful, but it's not urgent.

---

## Failure Modes of This Plan Itself

- **We confirm (A) and do nothing.** That's fine. That's the right outcome if his mental model just needed alignment. Not a failure.
- **We do the targeted (D) work but the autonomous-delivery-pipeline plan gets descoped or abandoned.** The (D) work still stands on its own — preview channels, observability, index automation, and a runbook are valuable even without agent-driven deploys.
- **Scope creep into (C).** If detailed-phase discussions start pulling in Cloud Run, Spanner, or Cloud Build, this plan has failed. Guard against it by keeping the line "reject (C)" as an explicit decision in the approved version.
- **Ship-gap work gets deferred indefinitely.** The gaps are real regardless of the Google question. Even if Duong answers (A) and stops here, the gaps still need to be addressed under a different plan.

---

## What This Plan Is Not

- Not a migration plan
- Not a Cloud Run / Spanner / Identity Platform proposal
- Not a monorepo split proposal
- Not a replacement for Syndra's autonomous-delivery-pipeline plan
- Not an implementation spec — rough-phase only, detailed-phase comes after approval
