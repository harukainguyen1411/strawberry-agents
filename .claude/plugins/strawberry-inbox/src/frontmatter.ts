/**
 * Minimal YAML frontmatter reader.
 * Only extracts the fields we care about: from, to, status, priority, timestamp.
 * Does not use any external parser — keeps the plugin dependency-free beyond the MCP SDK.
 */

export interface InboxFrontmatter {
  from?: string;
  to?: string;
  status?: string;
  priority?: string;
  timestamp?: string;
}

/**
 * Parse the YAML frontmatter block from a markdown file's content.
 * Returns null if the file does not start with a `---` fence.
 */
export function parseFrontmatter(content: string): InboxFrontmatter | null {
  const lines = content.split('\n');
  if (lines[0].trim() !== '---') return null;

  const result: InboxFrontmatter = {};
  let i = 1;
  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === '---') break;
    // Match `key: value` — values may be quoted or bare.
    const match = line.match(/^(\w+):\s*(.+)$/);
    if (match) {
      const key = match[1] as keyof InboxFrontmatter;
      const val = match[2].trim().replace(/^['"]|['"]$/g, '');
      result[key] = val;
    }
    i++;
  }
  return result;
}
