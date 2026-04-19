# Playwright Docker Version Matching for Linux Snapshot Generation

**Date:** 2026-04-19
**Context:** Generating `*-chromium-linux.png` baseline snapshots via Docker for CI.

## Lesson

`package.json` may declare `"@playwright/test": "^1.58.0"` but npm resolves to a newer patch
(e.g. 1.59.1) in `package-lock.json`. The Playwright Docker image tag MUST match the resolved
version, not the declared range — otherwise the browser executable path inside the container
won't match what the installed npm package expects.

Error symptom: `Executable doesn't exist at /ms-playwright/chromium_headless_shell-<N>/...`
with a hint: "Looks like Playwright was just updated to X.Y.Z. Please update docker image."

## Fix

1. Read the resolved version: `cat package-lock.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['packages']['node_modules/@playwright/test']['version'])"`
2. Pull the matching image: `docker pull mcr.microsoft.com/playwright:v<resolved>-jammy`
3. Run: `docker run --rm -v <repo-root>:/work -w /work/apps/myapps --ipc=host mcr.microsoft.com/playwright:v<resolved>-jammy bash -c "cd /work && npm ci --workspace=apps/myapps && cd /work/apps/myapps && npx playwright test e2e/visual-regression.spec.ts --update-snapshots --project=chromium"`
