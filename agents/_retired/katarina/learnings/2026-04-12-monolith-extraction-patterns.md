# Monolith Extraction — Common Patterns and Pitfalls

## Date
2026-04-12

## Context
Extracted 4 apps from apps/myapps monolith into standalone Vite workspace packages.

## Patterns

1. **Root-level stray files**: The monolith had data files (`books.ts`, `goals.ts`, etc.) at `src/` root. When copying components you may also copy these. They import `./auth` (relative to src root), which breaks in the new app. Check `src/*.ts` after scaffolding and remove non-main files.

2. **@shared alias vs relative path**: App-level firebase helpers often imported shared utilities with a relative `../../../shared/` path. The standalone vite.config.ts sets up `@shared` alias. Update these imports — sed one-liner works.

3. **API drift between composables**: When a root-level `src/useBee.ts` (old Firestore API) and a `src/composables/useBee.ts` (new Cloud Functions API) both exist, views may be wired to the old one. The views import from `@/composables/useBee` but reference types/methods that only exist in the old version. Check composable API carefully when extracting.

4. **dist/ gitignore scope**: A gitignore in `apps/myapps/` only covers `apps/myapps/dist/`. Sibling directories like `apps/yourApps/` need their own gitignore. Always add `.gitignore` before running `npm run build` in a new app directory.

5. **Test files with monolith-specific imports**: Spec files (e.g. `Dashboard.spec.ts`) may import `@/test/utils` or other test infrastructure that doesn't exist in the standalone app. Remove or exclude them — they're not needed for the initial extraction.
