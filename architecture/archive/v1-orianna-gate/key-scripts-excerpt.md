# Key Scripts — Orianna v1 Gate Excerpt (Archived)

This excerpt was removed from `architecture/key-scripts.md` when the v1 Orianna gate
regime was replaced by the v2 callable-agent regime. See
`plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md`.

---

## Orianna Signing Scripts (v1 — archived)

These scripts implement the Orianna-signed plan lifecycle (ADR `plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md`). Speed-up scripts (body-hash guard, pre-fix, stale-lock helper) were added by `plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md`.

The scripts themselves are archived at `scripts/_archive/v1-orianna-gate/`.

| Script | Usage | Purpose |
|--------|-------|---------|
| `orianna-sign.sh` | `bash orianna-sign.sh <plan.md> <phase>` | Entry point for signing. Invokes phase prompt via claude CLI, computes body hash, appends signature, commits. |
| `orianna-verify-signature.sh` | `bash orianna-verify-signature.sh <plan.md> <phase>` | Verifies phase signature (hash, author, trailers, single-file scope). |
| `orianna-hash-body.sh` | `bash orianna-hash-body.sh <plan.md>` | Computes SHA-256 of plan body for signature/verification. |
| `plan-promote.sh` | `bash plan-promote.sh <file> <stage>` | Moved plan between phase directories (verifying signatures). |
| `hooks/pre-commit-orianna-signature-guard.sh` | Via dispatcher | Enforced signing commit shape (shape A and shape B). |
| `hooks/pre-commit-orianna-body-hash-guard.sh` | Via dispatcher | Rejected edits to signed plan body without re-signing. |
| `orianna-pre-fix.sh` | Via orianna-sign.sh | Mechanical rewrites before Orianna invocation. |
| `_lib_stale_lock.sh` | Sourced | Stale index.lock cleanup helper. |
| `_lib_coordinator_lock.sh` | Sourced | Advisory exclusive lock for concurrent sign/promote prevention. |
