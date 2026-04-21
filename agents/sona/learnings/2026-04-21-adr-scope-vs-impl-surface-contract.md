# ADR-scope plans without reading impl code risk endpoint contract mismatches

**Date:** 2026-04-21
**Context:** S3 plan (projectId reuse + S4 auto-trigger) authored from ADR-level scope without reading the actual S3 implementation. Discovered during Wave 1 dispatch prep: plan assumed non-streaming `POST /build`; actual S3 endpoint is SSE-streaming `POST /v1/build`.

## What happened

The S3 ADR plan described an `POST /build` endpoint for the build invocation path. When preparing the Jayce dispatch for Wave 1, cross-checking against actual code revealed the S3 service exposes `POST /v1/build` with SSE (Server-Sent Events) streaming — a fundamentally different response contract. The planner authored the ADR based on the service's conceptual role, not its actual API surface.

Jayce was corrected with the right endpoint before dispatch. But if this had not been caught, the implementation would have targeted a non-existent endpoint, producing silent failures or integration breakage that would have been expensive to trace.

## The lesson

**Plans authored from ADR-level scope (service role, conceptual flow) without reading target code risk producing implementation contracts that don't match reality.** For any ADR that specifies an endpoint signature, response format, or integration contract:

1. The planner must read the relevant source files before finalizing the contract section.
2. Alternatively, the executor (Jayce/Viktor) must be explicitly instructed to validate the contract against actual code before implementing and surface any mismatches before writing code.
3. Streaming vs non-streaming is not a minor detail — it changes the client implementation entirely (response parsing, error handling, partial-read behavior).

## Application

Add to delegation context for all Wave 1–4 impl: "Before implementing any API call, read the actual source file for that endpoint and confirm the method, path, and response format match the plan. If mismatch found, surface before writing code."
