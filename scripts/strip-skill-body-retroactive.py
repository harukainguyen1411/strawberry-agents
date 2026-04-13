#!/usr/bin/env python3
r"""
Retroactively strip skill-body leaks from cleaned transcripts.

Usage:
    python scripts/strip-skill-body-retroactive.py [--dry-run] [paths...]

If no paths given, walks agents/*/transcripts/*.md relative to repo root.

A "skill-body leak" is a block of markdown inside a speaker section that:
  - starts with a line beginning with "# " (H1)
  - has >= 3 "## " headers in the first 5000 chars of the block
  - is >= 500 chars long

Speaker headers are distinguished by the pattern:
  ^## [A-Z][A-Za-z]+ \u2014 \d{4}-\d{2}-\d{2}T

The block is stripped from the "# " line up to (but not including) the next
speaker header or end of file.
"""

import argparse
import glob
import os
import re
import sys
from pathlib import Path

# Pattern matching legitimate speaker turn headers
SPEAKER_HEADER_RE = re.compile(r"^## [A-Z][A-Za-z]+ \u2014 \d{4}-\d{2}-\d{2}T", re.MULTILINE)


def looks_like_skill_body(text: str) -> bool:
    """Same heuristic as scripts/clean-jsonl.py:looks_like_skill_body()."""
    if not text.startswith("# "):
        return False
    if len(text) < 500:
        return False
    head = text[:5000]
    h2_count = sum(1 for line in head.split("\n") if line.startswith("## "))
    return h2_count >= 3


def strip_skill_bodies(content: str) -> tuple[str, int]:
    """
    Return (cleaned_content, bytes_stripped).

    Scans for H1 lines that look like leaked skill bodies and removes them
    up to the next speaker header.
    """
    lines = content.split("\n")
    result_lines = []
    i = 0
    bytes_stripped = 0

    while i < len(lines):
        line = lines[i]
        # Check if this line starts an H1
        if line.startswith("# "):
            # Collect from here to next speaker header or EOF
            block_start = i
            block_lines = []
            j = i
            while j < len(lines):
                # Stop collecting when we hit a speaker header (but not the first line)
                if j > i and SPEAKER_HEADER_RE.match(lines[j]):
                    break
                block_lines.append(lines[j])
                j += 1
            block_text = "\n".join(block_lines)
            if looks_like_skill_body(block_text):
                stripped = len(block_text.encode("utf-8"))
                bytes_stripped += stripped
                # Skip these lines
                i = j
                continue
        result_lines.append(line)
        i += 1

    cleaned = "\n".join(result_lines)
    # Collapse runs of 3+ blank lines down to 2
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned, bytes_stripped


def process_file(path: str, dry_run: bool) -> int:
    """Process one file. Returns bytes stripped."""
    with open(path, "r", encoding="utf-8") as f:
        original = f.read()

    cleaned, bytes_stripped = strip_skill_bodies(original)

    if bytes_stripped == 0:
        return 0

    print(f"{path}: stripped {bytes_stripped} bytes")

    if not dry_run:
        with open(path, "w", encoding="utf-8") as f:
            f.write(cleaned)

    return bytes_stripped


def main() -> None:
    parser = argparse.ArgumentParser(description="Strip skill-body leaks from transcripts.")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing files.")
    parser.add_argument("paths", nargs="*", help="Transcript files to process (default: agents/*/transcripts/*.md).")
    args = parser.parse_args()

    # Determine repo root (script lives at <root>/scripts/)
    repo_root = Path(__file__).resolve().parent.parent

    if args.paths:
        files = args.paths
    else:
        pattern = str(repo_root / "agents" / "*" / "transcripts" / "*.md")
        files = sorted(glob.glob(pattern))

    if not files:
        print("No transcript files found.")
        return

    total_stripped = 0
    files_touched = 0

    for path in files:
        stripped = process_file(path, dry_run=args.dry_run)
        if stripped:
            files_touched += 1
            total_stripped += stripped

    mode = "(dry-run)" if args.dry_run else ""
    print(f"\nDone {mode}: {files_touched} files touched, {total_stripped} total bytes stripped.")


if __name__ == "__main__":
    main()
