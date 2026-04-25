/**
 * mtime-cache.mjs — per-source file mtime tracker for incremental re-scan.
 *
 * Reads and writes a JSON file mapping absolute path → mtime (ms since epoch).
 * Allows ingest.mjs to skip files that haven't changed since last run.
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Implements T.P1.2 DoD (a) — mtime-cache for incremental ingest.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';

/**
 * Load the mtime cache from disk.
 * Returns an empty object if the cache file does not exist.
 * @param {string} cachePath — absolute path to the .mtimecache JSON file
 * @returns {Record<string, number>}
 */
export function loadMtimeCache(cachePath) {
  if (!existsSync(cachePath)) return {};
  try {
    return JSON.parse(readFileSync(cachePath, 'utf8'));
  } catch {
    return {};
  }
}

/**
 * Save the mtime cache to disk.
 * @param {string} cachePath — absolute path to the .mtimecache JSON file
 * @param {Record<string, number>} cache
 */
export function saveMtimeCache(cachePath, cache) {
  writeFileSync(cachePath, JSON.stringify(cache, null, 2), 'utf8');
}

/**
 * Check whether a file needs re-processing (its mtime has changed).
 * @param {Record<string, number>} cache
 * @param {string} filePath
 * @param {number} currentMtime — ms since epoch
 * @returns {boolean} true if the file is new or has been modified
 */
export function needsReprocess(cache, filePath, currentMtime) {
  return cache[filePath] !== currentMtime;
}
