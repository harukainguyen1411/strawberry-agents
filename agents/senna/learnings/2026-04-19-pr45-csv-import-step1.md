# PR #45 V0.11 CSV Import Step 1 — code review

**Repo:** harukainguyen1411/strawberry-app
**Tip:** b985c68
**Verdict:** CHANGES_REQUESTED

## Headline bug
`CsvImport.vue:onParse` calls `useCsvParser()` a **second time** to read `result`,
yielding a fresh composable instance whose `result` is always `null`. Every
successful parse advances to step 2 with `parseResult = null`, defeating the
whole feature's purpose for V0.12.

Fix: destructure `result` from the original `useCsvParser()` call at setup
scope, or have `parse()` return the result directly.

The test suite mocks `useCsvParser` wholesale and never asserts step
advancement — which is exactly why the bug slipped through. Flagged as a
Rule-13 regression-test requirement.

## Secondary findings
- `DropZone.errorId` uses `computed(() => 'dropzone-error-' + Math.random()...)`.
  Should be setup-scoped stable ref.
- `FileReader` in `onFileDropped` has no `onerror` handler; silent failure.
- `CsvPasteArea` only warns at 1 MB — no hard cap; pure parsers run
  synchronously on main thread and can freeze tab on multi-MB paste.
- `useCsvParser.ts` reaches into `@/../functions/portfolio-tools/...` — works
  but couples Vue bundle to functions workspace layout.
- MIME allowlist includes `text/plain` — fine as UX gate; flagged for comment.

## No security issues
No `v-html`, no credentials, no trust boundary crossed at this step.

## Lessons for future reviews
- When a Vue view consumes a composable, grep for every `useXxx()` call in the
  same file — repeat factory calls creating shadow instances is a common
  anti-pattern and hard to spot in diffs.
- Composable mocks in tests hide entire classes of integration bugs. Flag
  when a test mocks the very thing it claims to exercise.
