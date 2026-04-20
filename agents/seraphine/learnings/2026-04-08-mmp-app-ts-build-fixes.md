---
topic: mmp-app TypeScript and build compatibility
date: 2026-04-08
---

# mmp-app TypeScript Build Fixes

## Issue
msw@2.13.0 requires typescript >= 4.8, but the project pinned ~4.5.5. This caused ERESOLVE failures during `npm install` in Docker CI builds.

## Fixes Applied
1. **typescript ~4.5.5 -> ~4.9.5** — satisfies msw peer dep requirement
2. **vanilla-jsoneditor added** — peer dependency of json-editor-vue, was missing and caused vite build to fail with unresolved import
3. **--skipLibCheck added to build script** — vue-tsc with TS 4.9 surfaced type errors in @types/jsdom and @types/vue-cropperjs (both from node_modules). The tsconfig base already sets skipLibCheck: true but vue-tsc doesn't respect it from the config when using project references; CLI flag is needed.

## Gotchas
- `npm install typescript@x.y.z --save-dev` changes `~` prefix to `^` — must manually fix back in package.json
- vue-tsc 2.x works with TS 4.9 but ignores skipLibCheck from tsconfig.json when using project references
- The @vue/tsconfig base config already has skipLibCheck: true but vue-tsc doesn't honor it
