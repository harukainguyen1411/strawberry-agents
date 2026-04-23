#!/usr/bin/env python3
"""
_lib_bash_path_scan.py — bash AST path extractor for pretooluse-plan-lifecycle-guard.

Reads a bash command string from stdin (or argv[1]), parses it with bashlex,
walks the AST, and prints every resolved file-path argument to stdout (one per line).

Handles:
  - Redirect targets  (> >> < <<)
  - Command arguments (mv, cp, rm, git mv, touch, tee, dd, etc.)
  - Variable assignments in the same pipeline resolved at use-sites ($var)
  - ANSI-C quoting  ($'...')
  - Regular single/double quoting (bashlex already exposes word value)
  - Case-folding: all paths emitted as lowercase (for APFS / case-insensitive FS)
  - .. collapse and double-slash collapse (same normalization as shell guard)

Exit 0 always (caller decides what to do with the paths).
"""

from __future__ import annotations

import re
import sys


def normalize_path(p: str) -> str:
    """Collapse double-slashes and resolve .. segments; return lowercase."""
    # Case-fold for APFS / case-insensitive FS comparison
    p = p.lower()
    # Strip surrounding quotes (bashlex sometimes preserves them in word values)
    if (p.startswith("'") and p.endswith("'")) or (p.startswith('"') and p.endswith('"')):
        p = p[1:-1]
    # Strip $' ANSI-C prefix if bashlex left it as "$'...'"
    if p.startswith("$'") and p.endswith("'"):
        p = p[2:-1]
    # bashlex sometimes emits ANSI-C word as "$actualpath" (the $ is the parameter sigil
    # from the misparse of $'...' — strip a leading bare $ that isn't a variable name).
    # We detect: starts with "$" but NOT "${"  and the rest looks like a plain path.
    if p.startswith("$") and not p.startswith("${") and "/" in p:
        p = p[1:]
    # Collapse repeated slashes
    while "//" in p:
        p = p.replace("//", "/")
    # Resolve . and .. segments
    parts = p.split("/")
    resolved: list[str] = []
    for seg in parts:
        if seg in ("", "."):
            continue
        elif seg == "..":
            if resolved:
                resolved.pop()
        else:
            resolved.append(seg)
    return "/".join(resolved)


def extract_word_value(node) -> str | None:  # type: ignore[type-arg]
    """
    Extract the string value from a bashlex word node.
    Returns None if the word is a pure variable expansion with no known value.
    """
    word = node.word  # type: ignore[attr-defined]
    return word if word else None


def walk(node, assignments: dict[str, str], out: list[str]) -> None:  # type: ignore[type-arg]
    """Recursively walk a bashlex AST node and collect paths."""
    kind = node.kind  # type: ignore[attr-defined]

    if kind == "command":
        # Collect assignment nodes first so they're visible to later words
        for part in node.parts:  # type: ignore[attr-defined]
            if part.kind == "assignment":
                # assignment node: word is "name=value"
                raw = part.word  # type: ignore[attr-defined]
                if "=" in raw:
                    name, _, value = raw.partition("=")
                    # Strip quotes from value
                    value = normalize_path(value) if value else ""
                    assignments[name] = value
        # Now collect word arguments
        for part in node.parts:  # type: ignore[attr-defined]
            if part.kind == "word":
                raw = part.word  # type: ignore[attr-defined]
                # Resolve variable references like $dest or ${dest}
                resolved = _resolve_vars(raw, assignments)
                normed = normalize_path(resolved)
                if normed:
                    out.append(normed)
            elif part.kind in ("redirect",):
                # Redirect target is in heredoc or filename
                _walk_redirect(part, assignments, out)
            else:
                walk(part, assignments, out)

    elif kind == "redirect":
        _walk_redirect(node, assignments, out)

    elif kind in ("list", "pipeline", "compound", "if", "while", "for", "until",
                  "function", "subshell"):
        for part in getattr(node, "parts", []):  # type: ignore[attr-defined]
            walk(part, assignments, out)

    elif kind == "operator":
        # && || ; | — recurse into parts if any
        for part in getattr(node, "parts", []):  # type: ignore[attr-defined]
            walk(part, assignments, out)

    else:
        # Fallback: recurse into any parts
        for part in getattr(node, "parts", []):  # type: ignore[attr-defined]
            walk(part, assignments, out)


def _walk_redirect(node, assignments: dict[str, str], out: list[str]) -> None:  # type: ignore[type-arg]
    """Extract the redirect target filename.

    bashlex RedirectNode stores the target filename in node.output (a WordNode),
    not in node.parts. We check output first, then fall back to parts iteration.
    """
    # Primary: use the output attribute (standard for > >> < redirects)
    output = getattr(node, "output", None)  # type: ignore[attr-defined]
    if output is not None and hasattr(output, "word"):
        raw = output.word  # type: ignore[attr-defined]
        resolved = _resolve_vars(raw, assignments)
        normed = normalize_path(resolved)
        if normed:
            out.append(normed)
        return
    # Fallback: iterate parts (heredoc or unusual node shape)
    parts = getattr(node, "parts", [])  # type: ignore[attr-defined]
    for part in parts:
        if part.kind == "word":
            raw = part.word  # type: ignore[attr-defined]
            resolved = _resolve_vars(raw, assignments)
            normed = normalize_path(resolved)
            if normed:
                out.append(normed)
        else:
            walk(part, assignments, out)


_VAR_RE = re.compile(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?')


def _resolve_vars(s: str, assignments: dict[str, str]) -> str:
    """Replace $name / ${name} with known assignment values; leave unknown as-is."""
    def replacer(m: re.Match[str]) -> str:
        name = m.group(1)
        return assignments.get(name, m.group(0))
    return _VAR_RE.sub(replacer, s)


def scan(command: str) -> list[str]:
    """Parse command with bashlex and return list of normalized paths."""
    import bashlex  # type: ignore[import]

    try:
        parts = bashlex.parse(command)
    except Exception:  # noqa: BLE001
        # If bashlex can't parse, fall back to naive whitespace token scan so
        # the guard still catches obvious paths even on parse failure.
        paths = []
        for tok in command.split():
            # strip leading redirect chars
            tok = tok.lstrip("><")
            normed = normalize_path(tok)
            if normed:
                paths.append(normed)
        return paths

    assignments: dict[str, str] = {}
    out: list[str] = []
    for node in parts:
        walk(node, assignments, out)
    return out


def main() -> None:
    if len(sys.argv) > 1:
        command = sys.argv[1]
    else:
        command = sys.stdin.read()

    paths = scan(command)
    for p in paths:
        print(p)


if __name__ == "__main__":
    main()
