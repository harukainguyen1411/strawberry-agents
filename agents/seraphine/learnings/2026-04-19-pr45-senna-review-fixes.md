# PR #45 V0.11 Senna Review Fixes

**Date:** 2026-04-19
**Agent:** Seraphine
**Branch:** `feature/portfolio-v0-V0.11-csv-import-step1`
**Commits:** d67e82a (xfail), c8da426 (fix)

## Critical Bug Fixed

`useCsvParser` composable must be called exactly once at setup. The bug was:
```ts
parseResult.value = useCsvParser().result.value  // NEW instance — always null
```
Fix: destructure `result` from the single setup-time call, use `result.value` directly.

## Test Strategy for Composable Instance Bugs

When testing that a composable's shared reactive state propagates correctly:
- Mock `useCsvParser` at module scope (top-level `vi.mock`) — NOT inside `beforeEach`
- The mock factory must populate `result.value` when `parse()` is called
- `FAKE_RESULT` constant must be at module scope — `vi.mock` is hoisted, closures over `describe`-scoped consts fail with "not defined"

## jsdom Limitations for Drag/Drop Tests

- `DataTransfer` constructor: not available in jsdom
- `DragEvent` constructor: not available in jsdom
- Workaround: expose `onDrop` from the component via `defineExpose` and call it directly with a fake event object (`{ dataTransfer: { files: fakeFileList } }`)
- Fake FileList: `Object.assign([f1, f2], { length: 2, item: (i) => [f1, f2][i] })`

## DropZone errorId Pattern

- `computed(() => 'id-' + Math.random())` is fragile — looks stable because Math.random() has no reactive dep, but intent is wrong
- Fix: module-scoped counter `let _counter = 0` + `ref('dropzone-error-' + ++_counter)` in setup
- Gives deterministic, per-instance-stable ids for ARIA labelling

## CsvPasteArea Hard Reject

- Hard reject at 10 MB: check in `onInput` before emitting `update:modelValue`
- Restore textarea to previous value: `(e.target as HTMLTextAreaElement).value = props.modelValue`
- Emit `too-large` with byte count so parent can show a message
- Test: `Object.defineProperty(textarea.element, 'value', { value: hugeText, writable: true })` then `dispatchEvent(new Event('input'))`

## Pre-existing Failure

`functions/__tests__/emulator-boot.test.ts` "firestore.indexes.json should have empty indexes" was already failing at `b985c68` before my changes. Not introduced by this session.
