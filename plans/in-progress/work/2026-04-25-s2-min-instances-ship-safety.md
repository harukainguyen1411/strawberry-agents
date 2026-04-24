---
title: S2 demo-config-mgmt — add --min-instances=1 to prevent scale-to-zero session wipe
status: in-progress
concern: work
complexity: quick
owner: karma
tests_required: false
orianna_gate_version: 2
priority: P0
created: 2026-04-25
---

## Context

Exploration discovered that prod S2 (`demo-config-mgmt`) stores session state **in-memory only** — no Firestore or other durable backend. Any Cloud Run scale-to-zero event or instance rotation wipes all in-flight session state mid-demo. Full finding: `agents/ekko/learnings/2026-04-23-demo-config-mgmt-s2-contract.md`. Wave D ship is gated on this.

Duong picked option `b`: keep one Cloud Run instance always warm by adding `--min-instances=1` to the S2 `deploy.sh` invocation of `gcloud run deploy`. This is a one-line deploy-script flag tweak that eliminates scale-to-zero as a failure mode. Firestore-backed persistence (the "proper" fix) is tracked as a separate non-blocking follow-up: `plans/proposed/work/2026-04-25-s2-firestore-persistence.md`.

Risk: increases idle cost marginally (1 always-warm instance × Cloud Run pricing, ~negligible at demo scale). Acceptable for current volume; revisit if S2 traffic grows. No functional risk — `minScale` is a standard Cloud Run autoscaling annotation.

**Merge-order note — informational, not blocking.** Wave C (`plans/in-progress/work/2026-04-25-peer-deploy-sh-hardening-sweep.md`, Talon in-flight) explicitly excludes `demo-config-mgmt/deploy.sh` from its scope (see that plan's §Non-goals: "No change to `demo-config-mgmt/deploy.sh` (already hardened)"). Therefore no file-level conflict is expected. If Wave C's scope expands to re-touch this file, this plan rebases on top.

## Tasks

- **T1** — kind: edit, estimate_minutes: 5. Files: `~/Documents/Work/mmp/workspace/company-os/tools/demo-config-mgmt/deploy.sh`. Detail: locate the `gcloud run deploy demo-config-mgmt ...` invocation and append `--min-instances=1` to the flag list (preserve existing flag ordering; one flag per line if the invocation uses line-continuation style). DoD: flag present on the deploy line; script passes `bash -n` syntax check; local diff is a single-line addition (plus line-continuation backslash if needed).

- **T2** — kind: deploy+verify, estimate_minutes: 15. Files: none (runtime verification). Detail: redeploy S2 to stg first, then prod, using the edited `deploy.sh`. After each deploy, run `gcloud run services describe demo-config-mgmt --region europe-west1 --format='value(spec.template.metadata.annotations)'` and confirm the output contains `autoscaling.knative.dev/minScale: "1"`. DoD: both environments show the annotation; `gcloud run revisions list` shows a new ACTIVE revision on each.

- **T3** — kind: docs-sync, estimate_minutes: 5. Files: any sibling `README.md` or `DEPLOY.md` under `tools/demo-config-mgmt/` that documents deploy flags. Detail: if such docs exist and enumerate the `gcloud run deploy` flags, add `--min-instances=1` with a one-line rationale ("keeps one instance warm; S2 holds in-memory session state — see plan 2026-04-25-s2-firestore-persistence for the durable fix"). If no such docs exist, skip. DoD: docs and script agree, or task is explicitly skipped with a note in the PR body.

## Orianna / Talon path

- Orianna gate on this plan → approve → promote to `approved/`.
- Talon dispatch to execute on branch `fix/s2-min-instances` in the `company-os` workspace.
- Commit prefix: `ops:` (infra/deploy-script only, no `apps/**` touched).
- PR is single-file (plus optional docs); no E2E/QA-report required (not a user-flow change).

## References

- `agents/ekko/learnings/2026-04-23-demo-config-mgmt-s2-contract.md` — source finding.
- `plans/proposed/work/2026-04-25-s2-firestore-persistence.md` — follow-up durable-persistence plan. <!-- orianna: ok -->
- `plans/in-progress/work/2026-04-25-peer-deploy-sh-hardening-sweep.md` — Wave C, non-overlapping scope.

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Clear owner (karma), P0 ship-blocker grounded in Ekko's S2 in-memory contract finding, concrete one-line `--min-instances=1` addition with bash-syntax and annotation-verification DoDs across stg+prod. Follow-up durable-persistence plan is explicitly decoupled and referenced. Merge-order note with Wave C confirms no file conflict. `tests_required: false` is appropriate for a deploy-script flag tweak validated by `gcloud run services describe`.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** approved → in-progress
- **Rationale:** Plan body unchanged since approved-stage gate at 2a961ed6; tasks T1–T3 are actionable with concrete file paths, DoDs, and verification commands. `tests_required: false` remains appropriate for a deploy-flag tweak. Duong has given explicit go-ahead; Wave C non-overlap reconfirmed. Ready for Talon dispatch on `fix/s2-min-instances`.
