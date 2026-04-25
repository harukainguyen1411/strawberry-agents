/**
 * Vanilla snapshot helper (~30 LOC) for render-html.test.mjs
 *
 * Usage:
 *   import { assertSnapshot } from './lib/snapshot.mjs';
 *   assertSnapshot(html, 'index.html');
 *
 * Set UPDATE_SNAPSHOTS=1 to rewrite snapshot files.
 *
 * Snapshots live alongside the tests in __snapshots__/<name>.snap
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SNAPSHOTS_DIR = join(__dirname, '..', '__snapshots__');

export function assertSnapshot(actual, snapshotName) {
  const snapPath = join(SNAPSHOTS_DIR, `${snapshotName}.snap`);

  if (process.env.UPDATE_SNAPSHOTS === '1') {
    mkdirSync(SNAPSHOTS_DIR, { recursive: true });
    writeFileSync(snapPath, actual, 'utf8');
    console.log(`[snapshot] Updated: ${snapPath}`);
    return;
  }

  if (!existsSync(snapPath)) {
    // First run — write the snapshot
    mkdirSync(SNAPSHOTS_DIR, { recursive: true });
    writeFileSync(snapPath, actual, 'utf8');
    console.log(`[snapshot] Created: ${snapPath}`);
    return;
  }

  const expected = readFileSync(snapPath, 'utf8');
  assert.strictEqual(
    actual,
    expected,
    `Snapshot mismatch for "${snapshotName}".\n` +
    `Run with UPDATE_SNAPSHOTS=1 to update.\n` +
    `First difference at char ${[...actual].findIndex((c, i) => c !== expected[i])}.`
  );
}
