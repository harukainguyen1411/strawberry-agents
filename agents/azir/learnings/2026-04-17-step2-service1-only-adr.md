# Step 2 Service-1-Only ADR — decisions + gotchas

## Scope contraction handled by revising, not rewriting

Duong contracted Step 2 scope mid-session (from Services 1+2 to Service 1 only). The existing ADR file (`2026-04-17-demo-studio-v3-step2-service1-only.md`) already had the scope split right but left Q1–Q4 as open questions. The right move was edit-in-place with a "Decisions Locked" section, not a second rewrite. Keeps history readable.

## Q3 — why Option A (shared-secret bearer) over IAM invoker

Anthropic's hosted Managed Agent is not on GCP. No metadata server, no workload identity, no GCP SA. Cloud Run IAM invoker (`--no-allow-unauthenticated` + ID tokens) requires the caller to mint ID tokens — blocked on Anthropic-side infra. Shared-secret bearer via Secret Manager is the only sprint-scale option. Don't spend review cycles re-litigating this — it's an infra constraint, not a preference.

## Q4 — why merge-and-document when Service 2 is broken

Service 2 has no owner yet. Holding our PR indefinitely converts our scope into Service 2's scope — exactly the boundary Duong contracted. Merge + rewire + document inherited breakage in the PR body is the only option that respects the scope boundary. Concrete guardrail: PR body must include a "Service 2 status at merge time" table with per-tool Pass/Fail against the Service 2 revision ID, so it's unambiguous the breakage is inherited, not introduced.

## Amending task lists is cheaper than rewriting

Kayn already had 10 tasks written. Q3 required one new task pair (L4 middleware) + amendments to 8 existing tasks. Enumerated the amendments explicitly in the Handoff Notes section of the ADR so Kayn doesn't need to re-read the whole doc. Lesson: when a locked decision touches existing tasks, write the amendment list as a tracked artifact in the ADR.

## Exit-code contract moved from "Kayn finalises" to locked in ADR

Earlier draft left smoke-script exit codes (0/10/20/30) as a suggestion. Q4 relies on 20 = Service-2-side = mergeable, 10/30 = ours = blocking. That made the exit-code contract a decision, not a detail. Moved into the ADR body, removed the "Kayn finalises" language.

## `dist/` staleness (Ekko flagged) is a Dockerfile problem, not a plan problem

Ekko found `dist/` doesn't have `get_schema` while `src/` does. Added to Risks table (#4) with mitigation: Dockerfile multi-stage build should invalidate stale `dist/` — one-time fix during this deploy cycle, not a permanent tax. Do not couple the ADR to this — it's an impl detail.
