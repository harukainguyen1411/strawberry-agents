---
date: 2026-04-18
topic: unit-tests-workflow-npm-install
tags: [ci, npm, workflows, latent-bug]
---

# Missing `npm install` in unit-tests.yml causes silent first-run failure

## What happened

`unit-tests.yml` ran `vitest` directly after `actions/setup-node` without any `npm install` step. The workflow had never been triggered on a TDD-enabled package before B3, so the bug was latent. First run failed with `vitest: not found`.

## Fix

Add `npm install --prefer-offline` between `setup-node` and the package detection / test-run steps:

```yaml
- name: Install dependencies
  run: npm install --prefer-offline
```

## Why `--prefer-offline`

Uses the npm cache when available (CI runners cache `~/.npm`), falls back to registry only for cache misses. Faster than `npm ci` on incremental runs and avoids lock-file desync errors when the workflow itself is on a feature branch that hasn't updated the lockfile.

## Secondary fix: CWD-relative `require` in node -e

The package-detection step used `require('./$dir/package.json')`. On CI the working directory isn't guaranteed to match the repo root, so this can silently `throw` and be swallowed by the `try/catch`. Fixed with:

```sh
node -e "try{const p=require(require('path').resolve('$dir/package.json')); ...}"
```

## Lesson

Any workflow that runs Node tools must have an explicit install step — `setup-node` only installs the Node runtime, not project dependencies. Audit new workflows for this before merging. The "first PR to touch a new check" is always the one that surfaces latent wiring bugs.
