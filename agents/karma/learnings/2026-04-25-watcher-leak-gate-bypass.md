---
date: 2026-04-25
author: karma
topic: coordinator identity env leak, watcher subprocess identity, gate bypass
---

# Coordinator Identity Leak and Watcher Subprocess Bug — Post-Mortem

## (a) The env-var leak that mis-pinned Evelynn as Sona

`scripts/mac/launch-evelynn.sh` and `launch-sona.sh` used bare `export` statements at
the top level of the script body. When a user ran `. launch-evelynn.sh` (or dot-sourced
it to probe it), the exports persisted in the interactive shell. After `/exit`, the next
`claude` invocation inherited `STRAWBERRY_AGENT=Evelynn` (or `=Sona` from a prior Sona
probe), and the SessionStart hook's Tier 1 env-var resolution trusted it — silently
mis-pinning the session identity.

The fix: wrap the body of each `.sh` launcher in a subshell `( ... )` so even when
sourced the exports are confined to the subshell child and never reach the outer shell.
`coordinator-boot.sh` (invoked via `bash scripts/coordinator-boot.sh Evelynn`) was
already safe because `bash ...` runs in a subprocess — it was not modified for leak
isolation, only for hint-file writing.

## (b) Yuumi commit `240bd394` broke the watcher silently

Yuumi shipped a "clean launcher" that set identity inside the Claude process only,
without propagating env vars to subprocesses. `inbox-watch.sh` resolved identity
exclusively from `CLAUDE_AGENT_NAME` / `STRAWBERRY_AGENT`. When Monitor spawned
the watcher, the subprocess inherited Claude's env — which contained neither var
under the clean launcher. The watcher exited 0 with empty stdout, Monitor saw nothing,
and Duong received no inbox events. No test existed for this subprocess identity path.

## (c) The corrective gate path (Karma -> Orianna -> Talon -> Senna+Lucian)

The corrective plan went through the full gate:
1. Karma authored the plan at `plans/proposed/personal/2026-04-25-coordinator-identity-leak-watcher-fix.md`.
2. Orianna reviewed and approved it, moving it to `plans/approved/`.
3. Talon branched via `safe-checkout.sh`, committed xfail tests first (Rule 12), then
   implemented the fix.
4. Senna + Lucian reviewed the PR before merge (Rule 18).

Yuumi's direct commit bypassed every one of these gates, which is why the regression
shipped with no test coverage and was invisible until production use.

## (d) Architectural lesson — subprocess identity needs explicit coverage

Any change to coordinator identity resolution must include subprocess-propagation tests
because Monitor inherits Claude's env from the *launcher process*, not from inside
Claude's own process. Specifically:

- Env vars set with `export` inside a running Claude session do not propagate back to
  the spawning shell or to Monitor-spawned child processes.
- The canonical identity source for subprocesses is the `.coordinator-identity` hint
  file, written atomically by the launcher before `exec claude`.
- Tests must exercise the "no env vars, only hint file" code path in
  `inbox-watch.sh` and `inbox-watch-bootstrap.sh` — not just the env-var path.

Pattern to follow for future identity-resolution changes:
1. Add a Tier 3 hint-file path alongside any Tier 1/2 env-var paths.
2. Write a dedicated test that unsets all env vars and verifies the hint-file path works.
3. Write the hint file from all launcher scripts, not just `coordinator-boot.sh`.
