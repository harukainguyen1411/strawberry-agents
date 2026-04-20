# Session API ADR — notes

## Scope discipline is half the value

Brief was explicit: our team owns Session API only, do not touch Config API (PR #40's `/v1/config*`, `/v1/schema`, `/logs`). Every temptation to "while we're in there, also fix PATCH /v1/config" was left as an open question at most. The ADR stays surgical because the brief stayed surgical. When an ADR crosses team boundaries, the crossing must be called out and deferred, not absorbed.

## Enum divergences need a winner picked in the ADR, not left as TBD

Existing code: `configuring/approved/building/complete/failed/archived`.
PR #40 spec: `configuring/building/built/qc_passed/qc_failed/build_failed/completed/cancelled`.
Picked PR #40 as canonical (spec > code, because code hasn't shipped to paying customers and the spec was written against the target state). Published a concrete mapping table for the backfill, left only the `archived → ?` ambiguity as a flagged Q1. Don't write ADRs that punt on enum choice — pick, map, and flag only the genuinely ambiguous row.

## Pointer ownership: one-way, written by one side

`sessions.configVersion` is an int pointer into `configs/{id}/versions/{n}`. Two teams, one field. Rule baked into the ADR: Config API writes it (they're the only party that knows when a new version lands), Session API never writes it. Other services (Factory, Preview) read it. This is how you keep two collections on the same service from tangling — named ownership per field, one-way.

## Hard cut is the house default

Resiliency redesign decision #2 established hard-cut cutover as the team norm (no feature flags, product not live, rollback = revert commit). Phase C of this ADR inherits that style wholesale. When the team has a cutover style, new ADRs should cite it and follow, not re-litigate.

## Out-of-scope items still deserve an Open Question

`auth.py`'s `demo-studio-used-tokens` Firestore collection is not this ADR's problem, but it blocks Phase C from cleanly dropping `google-cloud-firestore` from Service 1. Flagged as Q4 with three concrete options. Pattern: if X is out of scope but affects X's dependencies on *this* ADR's success, surface it as an open question with options, not just silence.

## Frontmatter verified post-write

Per 2026-04-17-resiliency-redesign-adr.md gotcha: grepped for `^status:` and `^---` after writing to confirm frontmatter fences survived. They did. Keep doing this.
