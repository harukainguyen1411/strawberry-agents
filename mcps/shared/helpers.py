"""
Shared helpers for MCP servers.
Agent scanning, iTerm integration, health registry, and git operations.
"""
import json
import logging
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

log = logging.getLogger(__name__)

WORKSPACE = os.environ.get('WORKSPACE_PATH', '')
AGENTS_DIR = os.environ.get('AGENTS_PATH', '')
ITERM_PROFILES = os.environ.get('ITERM_PROFILES_PATH', '')
OPS_PATH = os.environ.get('OPS_PATH', '')


# ── ops path ─────────────────────────────────────────────────────────────

def ops_root() -> Optional[Path]:
    """Return the ops directory if OPS_PATH is set and exists, else None."""
    if not OPS_PATH:
        return None
    p = Path(OPS_PATH)
    p.mkdir(parents=True, exist_ok=True)
    return p


# ── agents ───────────────────────────────────────────────────────────────

def agents_root() -> Path:
    if not AGENTS_DIR:
        raise ValueError('AGENTS_PATH not configured.')
    p = Path(AGENTS_DIR)
    if not p.is_dir():
        raise ValueError(f'AGENTS_PATH does not exist: {AGENTS_DIR}')
    return p


def is_agent_dir(d: Path) -> bool:
    return d.is_dir() and (d / 'memory').is_dir()


def read_section(text: str, heading: str) -> str:
    """Extract the first line of a ## section from markdown text."""
    match = re.search(f'^## {heading}\n(.*?)(?:\n## |\\Z)', text, re.MULTILINE | re.DOTALL)
    if not match:
        return ''
    lines = [l.lstrip('- ').strip() for l in match.group(1).strip().splitlines() if l.strip()]
    return lines[0] if lines else ''


def read_agent_info(agent_dir: Path, name: str) -> dict[str, str]:
    """Read role and specialty from the agent's memory file."""
    memory = agent_dir / 'memory' / f'{name}.md'
    if not memory.exists():
        return {'role': '', 'specialty': ''}
    text = memory.read_text()
    return {
        'role': read_section(text, 'Role'),
        'specialty': read_section(text, 'Specialty'),
    }


def scan_agents() -> list[dict[str, str]]:
    root = agents_root()
    agents = []
    for agent_dir in sorted(root.iterdir()):
        if not is_agent_dir(agent_dir):
            continue
        name = agent_dir.name
        info = read_agent_info(agent_dir, name)
        agents.append({
            'name': name,
            'role': info['role'],
            'specialty': info['specialty'],
        })
    return agents


# ── health registry ──────────────────────────────────────────────────────

def registry_path() -> Path:
    ops = ops_root()
    if ops:
        d = ops / 'health'
        d.mkdir(parents=True, exist_ok=True)
        return d / 'registry.json'
    return agents_root() / 'health' / 'registry.json'


def read_registry() -> dict[str, Any]:
    path = registry_path()
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def write_registry(data: dict[str, Any]):
    path = registry_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n')


def set_agent_status(name: str, status: str, platform: str = 'cli', task: Optional[str] = None):
    registry = read_registry()
    registry[name] = {
        'status': status,
        'last_heartbeat': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S'),
        'platform': platform,
        'current_task': task,
    }
    write_registry(registry)


# ── iTerm ────────────────────────────────────────────────────────────────

def get_iterm_agent_windows() -> list[dict[str, str]]:
    """Get all iTerm2 windows with their session names and window IDs."""
    script = """
tell application "iTerm"
    set output to ""
    repeat with w in windows
        set wid to id of w
        try
            set tabName to name of current session of current tab of w
            set output to output & tabName & "|||" & wid & linefeed
        end try
    end repeat
    return output
end tell
"""
    result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
    if result.returncode != 0:
        return []

    windows = []
    for line in result.stdout.strip().splitlines():
        parts = line.strip().split('|||')
        if len(parts) != 2:
            continue
        raw_name = parts[0].strip()
        agent_name = raw_name.split()[0] if raw_name else raw_name
        windows.append({
            'name': agent_name,
            'raw_name': raw_name,
            'window_id': parts[1].strip(),
        })
    return windows


def send_to_iterm_window(window_id: str, text: str) -> bool:
    """Send text to a specific iTerm2 window by ID."""
    flat = ' '.join(text.splitlines())
    escaped = flat.replace('\\', '\\\\').replace('"', '\\"')
    script = f"""
tell application "iTerm"
    repeat with w in windows
        if id of w is {window_id} then
            tell current session of current tab of w
                write text "{escaped}"
            end tell
            return "ok"
        end if
    end repeat
    return "not found"
end tell
"""
    result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
    return 'ok' in result.stdout


# ── git ──────────────────────────────────────────────────────────────────

def git(args: list[str], cwd: str | None = None) -> subprocess.CompletedProcess:
    """Run a git command and return the result."""
    return subprocess.run(
        ['git'] + args,
        cwd=cwd or WORKSPACE,
        capture_output=True,
        text=True,
    )
