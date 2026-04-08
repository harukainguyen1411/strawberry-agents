# Duong — Personal Agent System

Personal agent workspace for non-work tasks: life admin, personal projects, learning, etc.

## Structure

```
duong/
├── agents/           # Personal agent system
│   ├── memory/       # Agent memory files
│   ├── journal/      # Session journals
│   ├── learnings/    # Reusable learnings
│   ├── inbox/        # Inter-agent messages
│   ├── wip/          # Work in progress snapshots
│   ├── conversations/# Multi-agent conversations
│   ├── health/       # Agent heartbeats
│   └── transcripts/  # Session transcripts (gitignored)
├── plans/            # Implementation plans
├── scripts/          # Utility scripts
│   └── launch-evelynn.sh  # Launch Evelynn on Mac
├── windows-mode/     # Windows launch scripts
└── CLAUDE.md         # Agent instructions
```

## Quick Start

**Mac:**
```bash
./scripts/launch-evelynn.sh
```

**Windows:**
```cmd
windows-mode\launch-evelynn.bat
```

Both launch Evelynn with `--dangerously-skip-permissions` and `--remote-control`.
