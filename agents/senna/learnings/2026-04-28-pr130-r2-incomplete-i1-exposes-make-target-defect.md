# PR #130 r2 — Incomplete I1 fix exposes pre-existing make-target defect

**PR:** missmp/company-os#130 — `chore: wire /v1/schema to canonical schema.yaml`
**Branch:** `feat/wire-real-schema` @ `9cacf1f`
**Verdict:** CHANGES-REQUESTED (r2)

## What I learned

When a reviewer flags a path-glob fix (I1) as "fix all N occurrences", the implementer
may resolve a subset and miss occurrences that are not syntactically identical to the
ones called out. Here Talon fixed three `paths:` / `working-directory:` occurrences but
missed `cache-dependency-path:` on line 24 of the same workflow file — same wrong path,
different YAML key, same root cause.

Reviewer takeaway: when filing path-glob findings, grep the entire workflow file for the
wrong-path string and enumerate every occurrence by line number rather than relying on
the implementer to find them all.

## Second-order finding worth flagging

I1's correction (the trigger paths) caused the workflow to actually fire against this
package for the first time in PR #130 — and that exposed a pre-existing defect: the
workflow runs `make lint` / `make test`, but `tools/demo-config-mgmt/` has no `Makefile`.
The workflow had been wrong-path-globbed since inception, so the missing-Makefile bug was
silently lurking. Fixing one bug surfaced another.

This is the inverse of "shipping a fix surfaces a regression": **shipping a fix surfaces
a previously-masked defect**. Worth checking on every "CI workflow path-correction" PR
whether the workflow itself runs at all in its new state.

## conftest staging — design pattern worth remembering

The `pytest_configure` / `pytest_unconfigure` shape Talon used is the right way to stage
files BEFORE test collection. A session-scoped fixture won't work because pytest imports
test modules during collection (which fires before any fixture, including session-scoped
autouse fixtures). For `import-time-side-effect` modules (like main.py reading schema at
import), `pytest_configure` is the only safe ordering.

Tracking-flag pattern (`config._talon_staged_schema = True`) cleanly distinguishes
"I created this file" from "this file was already here" so cleanup never deletes
pre-existing dev-staged copies.

## What I shipped

Comment: https://github.com/missmp/company-os/pull/130#issuecomment-4329056406
Severity: 1 BLOCKER (make-target defect, CI red), 1 IMPORTANT (cache-dependency-path
residue), 1 NIT (build-context bloat).
