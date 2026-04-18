# 2026-04-19 — T5/T6 refresh-server.mjs + sbu.sh review (PRs #35, #37)

## Patterns observed

- **CORS health-check bypass**: GET /health often skips the origin guard that POST /refresh has. Always check both routes when a CORS policy is stated in the plan.

- **`open` portability trap**: macOS `open` in a script under `scripts/` (not `scripts/mac/`) violates CLAUDE.md rule 10. The correct fix is either `scripts/mac/` placement or a cross-platform open helper. Authors who note "macOS" in comments are flagging awareness, not granting an exemption from the rule.

- **nohup silent failure**: background processes started with `>/dev/null 2>&1 &` give no feedback if they fail to bind/start. A post-spawn `kill -0` liveness check or stderr log redirect is needed for user-facing tooling.

- **Concurrent spawn race on POST /refresh**: no in-flight guard means two rapid requests spawn two build.sh processes writing to the same output file. An `isBuilding` flag + 409 is the minimal fix.

## TDD compliance notes

- Both T5 and T6 had the correct xfail-first → impl-second commit ordering.
- T6 test 2 PID liveness check is shallow (numeric PID only, not kill -0 confirmation). Acceptable for personal tooling.
