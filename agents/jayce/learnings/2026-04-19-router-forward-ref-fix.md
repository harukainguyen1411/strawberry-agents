# 2026-04-19 — Router forward-ref fix (PRs #32, #43, #44, #45)

## What happened

PR stack V0.2–V0.11 was authored with a shared router that referenced views from other branches in the stack. Each branch's build failed with ENOENT because the router was written as if the full stack had already landed.

## Root cause pattern

Three classes of forward-ref router bugs were found:

1. **V0.2 (#32)**: Router had `{ path: 'import', component: () => import('@/views/CsvImport.vue') }` — CsvImport.vue doesn't ship until V0.11.

2. **V0.9 (#43), V0.10 (#44), V0.11 (#45)**: All had identical router with `{ path: '/sign-in-callback', component: () => import('@/views/auth/SignInCallbackView.vue') }` — that auth/ subdirectory only exists in V0.2.

## Secondary TS errors found in V0.9 and V0.11

- `useAuth.ts` imported `{ app }` as a named import from `@/firebase/config`, but `app` is a default export there (config.ts does `export default app`). Fixed by switching to `import { auth } from '@/firebase/config'` (auth IS a named export).
- `onUnmounted` imported but never used in useAuth.ts.
- `ref` imported but unused in AppShell.test.ts.
- `beforeEach` imported but unused in BaseCurrencyPicker.test.ts.
- `const props = defineProps<...>()` in BaseCurrencyPicker.vue and SourceSelect.vue triggered TS6133 (noUnusedLocals). In `<script setup>`, template access to props is automatic — just `defineProps<...>()` without assignment.
- `t212.ts` line 115: `received: timeStr` where `ImportError.received` is `string[]`, not `string`. Fixed to `received: [timeStr]`.

## Clean branches (no router fixes needed)

V0.6 (#40), V0.7 (#41), V0.8 (#42): routers only referenced views present in their own branches.

## Worktree pattern

Worktrees do not inherit node_modules. Each worktree needed `npm install --prefix apps/myapps/portfolio-tracker` before the first build. Subsequent builds within the same session work without reinstalling.

## Merge conflict pattern

When remote was ahead (V0.9, V0.11), used `git merge origin/<branch>` then resolved conflicts keeping HEAD (fixed) versions. Used `git checkout --ours <files>` for bulk resolution when all conflicts followed the same pattern.
