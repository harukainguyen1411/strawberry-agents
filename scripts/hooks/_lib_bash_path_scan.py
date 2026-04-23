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
  - CompoundNode / subshell children via .list (B4/B5 fix)
  - WordNode command substitutions via .parts (B1/B2/B3 fix)
  - eval / bash -c / sh -c argument re-parse (B7 fix)
  - Case-folding: all paths emitted as lowercase (for APFS / case-insensitive FS)
  - .. collapse and double-slash collapse (same normalization as shell guard)

Exit codes:
  0 — success, paths printed to stdout
  3 — bashlex parse error (stderr message written); caller must treat as fail-closed
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
                # Also walk any commandsubstitution nodes inside the assignment word
                for subpart in getattr(part, "parts", []):
                    walk(subpart, assignments, out)

        # Detect eval / bash -c / sh -c for argument re-parse (B7)
        _verb = ""
        _dash_c = False
        _parts_list = list(getattr(node, "parts", []))
        for i, part in enumerate(_parts_list):
            if part.kind == "word" and i == 0:
                _verb = part.word.lower()  # type: ignore[attr-defined]
            elif part.kind == "word" and i == 1 and _verb in ("bash", "sh") and part.word == "-c":  # type: ignore[attr-defined]
                _dash_c = True

        _reparse_next = _verb == "eval" or (_verb in ("bash", "sh") and _dash_c)
        _reparse_idx = 1 if _verb == "eval" else 2  # index of the arg to re-parse

        # Now collect word arguments
        for i, part in enumerate(_parts_list):
            if part.kind == "word":
                raw = part.word  # type: ignore[attr-defined]
                # Walk commandsubstitution nodes inside word.parts (B1/B2/B3)
                for subpart in getattr(part, "parts", []):
                    walk(subpart, assignments, out)
                # Resolve variable references like $dest or ${dest}
                resolved = _resolve_vars(raw, assignments)
                normed = normalize_path(resolved)
                if normed:
                    out.append(normed)
                # eval / bash -c re-parse (B7) — single level only
                if _reparse_next and i == _reparse_idx:
                    _reparse_str = resolved.strip('"').strip("'")
                    _try_reparse(_reparse_str, assignments, out)
            elif part.kind in ("redirect",):
                # Redirect target is in heredoc or filename
                _walk_redirect(part, assignments, out)
            elif part.kind == "assignment":
                pass  # already handled above
            else:
                walk(part, assignments, out)

    elif kind == "redirect":
        _walk_redirect(node, assignments, out)

    elif kind == "commandsubstitution":
        # B1/B2/B3: walk the inner command of $(...) and `...`
        inner = getattr(node, "command", None)
        if inner is not None:
            walk(inner, assignments, out)
        # Also check .parts in case bashlex uses that shape
        for part in getattr(node, "parts", []):
            walk(part, assignments, out)

    elif kind in ("list", "pipeline", "compound", "if", "while", "for", "until",
                  "function", "subshell"):
        # B4/B5: CompoundNode (subshells, function bodies) uses .list, not just .parts
        for child in getattr(node, "list", []):  # type: ignore[attr-defined]
            walk(child, assignments, out)
        for part in getattr(node, "parts", []):  # type: ignore[attr-defined]
            walk(part, assignments, out)

    elif kind == "operator":
        # && || ; | — recurse into parts if any
        for part in getattr(node, "parts", []):  # type: ignore[attr-defined]
            walk(part, assignments, out)

    else:
        # Fallback: recurse into any parts or list children
        for child in getattr(node, "list", []):
            walk(child, assignments, out)
        for part in getattr(node, "parts", []):  # type: ignore[attr-defined]
            walk(part, assignments, out)


def _try_reparse(cmd_str: str, assignments: dict[str, str], out: list[str]) -> None:
    """Attempt to re-parse a string as bash (for eval/bash -c). Single level."""
    import bashlex  # type: ignore[import]

    if not cmd_str.strip():
        return
    try:
        sub_parts = bashlex.parse(cmd_str)
    except Exception:  # noqa: BLE001
        # Re-parse failure is non-fatal — we already recorded the raw string above
        return
    for node in sub_parts:
        walk(node, assignments, out)


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
    """Parse command with bashlex and return list of normalized paths.

    On parse error, writes to stderr and exits with code 3 (B6: no silent fallback).
    """
    import bashlex  # type: ignore[import]

    try:
        parts = bashlex.parse(command)
    except Exception as exc:  # noqa: BLE001
        # B6: no silent tokenizer fallback — exit non-zero so caller fails closed.
        print(
            f"[_lib_bash_path_scan] bashlex parse error: {exc}",
            file=sys.stderr,
        )
        sys.exit(3)

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
