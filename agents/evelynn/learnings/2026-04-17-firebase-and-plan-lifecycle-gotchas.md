# 2026-04-17 — Firebase + plan-lifecycle gotchas

Four small-but-sharp lessons from today's bee deploy + roster-mirror session.

## 1. `{timestamp}` is reserved in Firebase Storage rules

Rules compilation fails with `timestamp is a package and cannot be used as variable name` if you use `{timestamp}` as a wildcard segment. Rename to `{ts}` (or anything else). The path-matching semantics are identical — the wildcard name is just a local binding.

## 2. v2 callable CORS is per-function, not global

`setGlobalOptions({ cors: [...] })` does NOT compile — v2 `GlobalOptions` has no `cors` field. To allow a custom origin (e.g. `apps.darkstrawberry.com`) on callable functions, pass `cors` in each `onCall({ cors: [...] }, handler)`. Default allowed origins are Firebase Hosting + localhost only; everything else needs explicit config.

## 3. `plan-promote.sh` is proposed-only

`scripts/plan-promote.sh` refuses any source outside `plans/proposed/` (error: `plan-promote only handles plans/proposed/*.md`). For `in-progress → implemented`, use raw `git mv` + `sed -i '' 's/^status: .../status: implemented/'` + commit. Don't try to work around the script.

## 4. Safety hook scopes authorization per-attempt

When the sandbox hook blocks a "shared infrastructure change" (e.g. `firebase deploy --only storage`), one approval from Duong covers exactly ONE invocation. If I edit the rules and re-run the same command, the hook blocks again. Design: re-approval is required after any intervening change, even if the change is mechanical (rename a wildcard). Don't pattern-match on "user said yes" — the hook re-evaluates each call.

## Meta: the 5-pass rewrite pattern

Today's legal-doc review went through 5 iterations (md → docx → verified URLs → blank author → no tag prefixes). Pattern worth remembering: when the user refines output iteratively, resume the SAME subagent via `SendMessage` rather than spawning fresh. Each resume kept the prior context and anchors, and cost 1-15k tokens per pass instead of re-reading the document from scratch. The agent was still "alive" in the transcript even after reporting "completed".
