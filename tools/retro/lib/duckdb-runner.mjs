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
 * Alternatively, the SQL may use `FROM file` when the events file is passed as
 * the DuckDB database argument (see runDuckDBQueryWithFileDb below).
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

/**
 * Run a DuckDB SQL query using the events file as the DuckDB database argument.
 *
 * This enables `FROM file` in the SQL, where DuckDB auto-loads the events JSONL
 * as a table named `file`. Used by Phase-2 queries with dedicated event sources
 * (e.g. feedback-rollup.sql reads from feedback-events.jsonl via `FROM file`).
 *
 * Unlike runDuckDBQuery, no path substitution is done — the SQL must use `FROM file`
 * to reference the auto-loaded data.
 *
 * @param {string} sql — SQL content (uses `FROM file` to reference eventsPath data)
 * @param {string} eventsPath — absolute path to the dedicated events JSONL file
 * @returns {Array<Object>}
 */
export function runDuckDBQueryWithFileDb(sql, eventsPath) {
  // Strip trailing semicolons so DuckDB doesn't emit multiple result sets
  const cleanSql = sql.replace(/;\s*$/, '') + ';';

  // Pass eventsPath as the DuckDB database file so `FROM file` is auto-loaded
  // Single-quote escaping for shell: replace ' with '\''
  const shellPath = eventsPath.replace(/'/g, "'\\''");

  try {
    const result = execSync(`duckdb -json '${shellPath}'`, {
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
