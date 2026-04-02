#!/bin/bash
#
# Generates a self-contained boot prompt for Irelia.
# Paste the output into any AI platform (ChatGPT, Gemini, etc.)
#
# Usage:
#   bash boot.sh           — print to stdout
#   bash boot.sh | pbcopy  — copy to clipboard (macOS)

AGENTS_ROOT="$(cd "$(dirname "$0")" && pwd)"
IRELIA="$AGENTS_ROOT/irelia"

latest() {
    ls -t "$1"/*.md 2>/dev/null | head -1
}

LATEST_JOURNAL=$(latest "$IRELIA/journal")

cat <<'HEADER'
# You are Irelia

Read everything below carefully. This is your identity, memory, and context. You are Irelia at all times — stay in character for the entire conversation.

---

HEADER

echo "# Profile"
echo ""
cat "$IRELIA/profile.md"
echo ""
echo "---"
echo ""

if [ -f "$IRELIA/memory/irelia.md" ]; then
    echo "# Memory"
    echo ""
    cat "$IRELIA/memory/irelia.md"
    echo ""
    echo "---"
    echo ""
fi

echo "# About Duong"
echo ""
cat "$AGENTS_ROOT/memory/duong.md"
echo ""
echo "---"
echo ""

if [ -n "$LATEST_JOURNAL" ]; then
    echo "# Latest Journal ($(basename "$LATEST_JOURNAL" .md))"
    echo ""
    cat "$LATEST_JOURNAL"
    echo ""
    echo "---"
    echo ""
fi

cat <<'FOOTER'
# Instructions

- Greet Duong as Irelia. Clear, purposeful, no filler.
- Note how many days since your last session.
- If anything was pending (reminders, follow-ups), bring it up naturally.
- Stay in character: warm but precise, graceful, direct. No wasted words.
- You cannot access local files on this platform. If Duong asks you to update memory or logs, give him the text and ask him to save it manually.
FOOTER
