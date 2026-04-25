/**
 * duckdb-runner.mjs — execute DuckDB SQL queries against events.jsonl.
 *
 * Uses the `duckdb` CLI binary (required on PATH).
 * Passes SQL via stdin with `-json` flag for clean JSON array output.
 * Substitutes the events.jsonl path into SQL before execution.
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Implements T.P1.4 DoD (a)-(b).
 */

import { execSync } from 'node:child_process';

/**
 * Run a DuckDB SQL query against an events.jsonl file.
 *
 * The SQL may use 'events.jsonl' as the file path in read_ndjson_auto() calls;
 * this function substitutes the actual absolute path before execution.
 *
 * Returns the query result as a parsed JSON array.
 *
 * @param {string} sql — SQL content (may contain 'events.jsonl' placeholder)
 * @param {string} eventsPath — absolute path to events.jsonl
 * @returns {Array<Object>}
 */
export function runDuckDBQuery(sql, eventsPath) {
  // Substitute the events.jsonl placeholder with the actual absolute path
  const escapedPath = eventsPath.replace(/'/g, "''");
  const resolvedSql = sql.replace(/'events\.jsonl'/g, `'${escapedPath}'`);

  // Strip trailing semicolons so DuckDB doesn't emit multiple result sets
  const cleanSql = resolvedSql.replace(/;\s*$/, '') + ';';

  try {
    const result = execSync('duckdb -json', {
      input: cleanSql,
      stdio: 'pipe',
      encoding: 'utf8',
    });
    const trimmed = result.trim();
    if (!trimmed) return [];
    return JSON.parse(trimmed);
  } catch (err) {
    const stderr = err.stderr ? err.stderr.toString() : '';
    throw new Error(`DuckDB query failed: ${stderr || err.message}\nSQL:\n${cleanSql}`);
  }
}
