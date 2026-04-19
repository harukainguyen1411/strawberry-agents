# Dependabot Lockfile Review — Patterns from Phase 1

## npm workspace hoisting is not scope creep

When a root lockfile is fully regenerated to apply `overrides`, npm resolves all workspaces declared in root `package.json`. Packages from sibling workspace `package.json` files get hoisted into the root lockfile. Packages appearing in the lockfile diff that already exist in the repo under any workspace `package.json` are not scope creep — verify with `git show main:<path>/package.json | grep <package>` before raising the issue.

## Lockfile regen drift: require pin overrides for drifting packages

A standalone `npm install` regen (not `npm ci`) resolves floating semver ranges to latest, causing unrelated packages to bump. This appeared in B2 (`fast-xml-parser` 5.5.11→5.7.0, `@nodable/entities` new). The fix: add `overrides` pins for drifting packages at their main-branch version. Always verify pin targets against `git show main:<lockfile>` — if the pin version doesn't match main, it's itself a change.

## Surgical lockfile edits: verify integrity hashes independently

When full regen is not viable (e.g. 200+ unreviewed bumps in apps/myapps), surgical lockfile edits are acceptable with team-lead authorization. The critical review step: independently verify `version`, `resolved`, and `integrity` fields against `npm view <pkg>@<ver> dist.integrity dist.tarball`. Do not trust that `npm ci` passing is sufficient alone — verify hashes yourself.

## Plan scope gaps: check alert inventory against PR claims

Always cross-check the PR's claimed alert closures against `gh api /repos/.../dependabot/alerts?state=open` filtered by manifest. B2 initially missed `@tootallnate/once` (alert #78) which was in the plan scope. Catch these before approving.

## Post reviews as `gh pr comment`, never `gh pr review`

Confirmed pattern from memory — the `gh pr review` command is not usable on own-repo PRs in a way Duong prefers. Always `gh pr comment`.
