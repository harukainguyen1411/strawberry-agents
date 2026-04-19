# Learning: ccusage version mismatch — blocks subcommand

Date: 2026-04-19
Session: Phase 1 CI fix (PR #62)

## What happened

`usage-dashboard#build` failed in CI with `Error: Command not found: blocks`.
The `scripts/usage-dashboard/build.sh` calls `ccusage blocks -j` but
`dashboards/usage-dashboard/package.json` pinned `ccusage` at `0.8.0`, which
only has `daily`, `monthly`, `session`, `mcp` subcommands.

The `blocks` subcommand was introduced in a later major release. Current
latest is 18.0.11, which has `blocks`.

## Secondary issue

`build.sh` called `ccusage session -j -i -p`. In 0.8.0 those unknown flags
were silently tolerated (or ignored). In 18.x:
- `-i` / `--id <id>` — filter to a specific session ID
- `-p` / `--project <project>` — filter to a project name

So `session -j -i -p` would pass `-p` as the value for `--id`, producing
wrong output. The correct call is just `ccusage session -j`.

## Fix applied

1. Bumped `ccusage` `0.8.0` → `18.0.11` in `dashboards/usage-dashboard/package.json`
2. Surgical lockfile patch — updated `node_modules/ccusage` version/resolved/integrity
3. Removed `-i -p` from `ccusage session` call in `build.sh`

## Lesson

When a build script calls a CLI subcommand, verify the pinned package version
actually exposes that subcommand before landing. The build.sh and package.json
were written in different commits by different agents with diverging ccusage
version assumptions.
