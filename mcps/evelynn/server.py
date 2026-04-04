"""
Evelynn MCP Server
==================
Evelynn-only tools: session management, agent state commits.
Only Evelynn may call these tools (sender enforcement).

Environment Variables:
  Required:
    WORKSPACE_PATH       — path to workspace root
    AGENTS_PATH          — path to agents/ root (contains agent folders)
    ITERM_PROFILES_PATH  — path to iTerm2 DynamicProfiles/agents.json
  Optional:
    OPS_PATH             — path for operational data (health registry).
                           Falls back to in-repo paths under AGENTS_PATH if not set.
"""
import asyncio
import json
import logging
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('evelynn')

WORKSPACE = os.environ.get('WORKSPACE_PATH', '')
AGENTS_DIR = os.environ.get('AGENTS_PATH', '')
ITERM_PROFILES = os.environ.get('ITERM_PROFILES_PATH', '')
OPS_PATH = os.environ.get('OPS_PATH', '')

mcp = FastMCP('evelynn')


# ── helpers ──────────────────────────────────────────────────────────────

def _ops_root() -> Optional[Path]:
    if not OPS_PATH:
        return None
    p = Path(OPS_PATH)
    p.mkdir(parents=True, exist_ok=True)
    return p


def _agents_root() -> Path:
    if not AGENTS_DIR:
        raise ToolError('AGENTS_PATH not configured.')
    p = Path(AGENTS_DIR)
    if not p.is_dir():
        raise ToolError(f'AGENTS_PATH does not exist: {AGENTS_DIR}')
    return p


def _is_agent_dir(d: Path) -> bool:
    return d.is_dir() and (d / 'memory').is_dir()


def _read_section(text: str, heading: str) -> str:
    match = re.search(f'^## {heading}\n(.*?)(?:\n## |\\Z)', text, re.MULTILINE | re.DOTALL)
    if not match:
        return ''
    lines = [l.lstrip('- ').strip() for l in match.group(1).strip().splitlines() if l.strip()]
    return lines[0] if lines else ''


def _read_agent_info(agent_dir: Path, name: str) -> dict[str, str]:
    memory = agent_dir / 'memory' / f'{name}.md'
    if not memory.exists():
        return {'role': '', 'specialty': ''}
    text = memory.read_text()
    return {
        'role': _read_section(text, 'Role'),
        'specialty': _read_section(text, 'Specialty'),
    }


def _scan_agents() -> list[dict[str, str]]:
    root = _agents_root()
    agents = []
    for agent_dir in sorted(root.iterdir()):
        if not _is_agent_dir(agent_dir):
            continue
        name = agent_dir.name
        info = _read_agent_info(agent_dir, name)
        agents.append({
            'name': name,
            'role': info['role'],
            'specialty': info['specialty'],
        })
    return agents


def _registry_path() -> Path:
    ops = _ops_root()
    if ops:
        d = ops / 'health'
        d.mkdir(parents=True, exist_ok=True)
        return d / 'registry.json'
    return _agents_root() / 'health' / 'registry.json'


def _read_registry() -> dict[str, Any]:
    path = _registry_path()
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def _write_registry(data: dict[str, Any]):
    path = _registry_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n')


def _set_agent_status(name: str, status: str, platform: str = 'cli', task: Optional[str] = None):
    registry = _read_registry()
    registry[name] = {
        'status': status,
        'last_heartbeat': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S'),
        'platform': platform,
        'current_task': task,
    }
    _write_registry(registry)


def _get_iterm_agent_windows() -> list[dict[str, str]]:
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


def _send_to_iterm_window(window_id: str, text: str) -> bool:
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


def _git(args: list[str], cwd: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        ['git'] + args,
        cwd=cwd or WORKSPACE,
        capture_output=True,
        text=True,
    )


def _enforce_evelynn(sender: str):
    if sender.lower().strip() != 'evelynn':
        raise ToolError('Only Evelynn can invoke this tool.')


# ── tools ────────────────────────────────────────────────────────────────

@mcp.tool()
async def end_all_sessions(sender: str, exclude: Optional[list[str]] = None) -> dict[str, Any]:
    """End all running agent sessions. Restricted to Evelynn only.

    Messages each agent with instructions to follow the session closing protocol
    (end_session tool, journal, handoff note, memory update, learnings).

    Args:
        sender: Agent invoking this tool (must be 'evelynn')
        exclude: Optional list of agent names to skip
    """
    _enforce_evelynn(sender)
    all_agents = _scan_agents()
    agent_names = {a['name'] for a in all_agents}
    exclude_set = {n.lower() for n in (exclude or [])}

    iterm_windows = _get_iterm_agent_windows()
    ended = []
    skipped = []

    end_message = 'End your session now. Follow the session closing protocol in CLAUDE.md.'

    for w in iterm_windows:
        name_lower = w['name'].lower()
        if name_lower not in agent_names:
            continue
        if name_lower in exclude_set:
            skipped.append(name_lower)
            continue

        log.info(f'Ending session for {w["name"]}')
        _send_to_iterm_window(w['window_id'], end_message)
        _set_agent_status(name_lower, 'offline')
        ended.append(w['name'])
        await asyncio.sleep(1)

    return {
        'ended': ended,
        'skipped': skipped,
        'message': f'Sent end-session instructions to {len(ended)} agent(s).',
    }


@mcp.tool()
async def commit_agent_state_to_main(sender: str) -> dict[str, Any]:
    """Commit all agent state files to main branch and push. Restricted to Evelynn only.

    Stages agent memory, learnings, journals, and wip files (excluding inbox),
    commits to main with a standard message, and pushes to origin.

    Args:
        sender: Agent invoking this tool (must be 'evelynn')
    """
    _enforce_evelynn(sender)
    if not WORKSPACE:
        raise ToolError('WORKSPACE_PATH not set')
    if not AGENTS_DIR:
        raise ToolError('AGENTS_PATH not set')

    agents_rel = os.path.relpath(AGENTS_DIR, WORKSPACE)

    # Record current branch
    result = _git(['branch', '--show-current'])
    if result.returncode != 0:
        raise ToolError(f'Failed to get current branch: {result.stderr.strip()}')
    original_branch = result.stdout.strip()
    on_main = original_branch == 'main'

    stashed = False

    try:
        # Stash if not on main and working tree is dirty
        if not on_main:
            dirty = _git(['status', '--porcelain'])
            if dirty.stdout.strip():
                stash_result = _git(['stash', '--include-untracked'])
                if stash_result.returncode != 0:
                    raise ToolError(f'Failed to stash: {stash_result.stderr.strip()}')
                stashed = True

            # Checkout main
            checkout = _git(['checkout', 'main'])
            if checkout.returncode != 0:
                if stashed:
                    _git(['stash', 'pop'])
                raise ToolError(f'Failed to checkout main: {checkout.stderr.strip()}')

        # Pull latest
        pull = _git(['pull', 'origin', 'main'])
        if pull.returncode != 0:
            log.warning(f'git pull failed (continuing): {pull.stderr.strip()}')

        # Stage agent state files (memory, learnings, journal, wip) — exclude inbox
        state_patterns = [
            f'{agents_rel}/*/memory/',
            f'{agents_rel}/*/learnings/',
            f'{agents_rel}/*/journal/',
            f'{agents_rel}/*/wip/',
            f'{agents_rel}/memory/',
        ]

        staged_files = []
        for pattern in state_patterns:
            add_result = _git(['add', pattern])
            if add_result.returncode == 0:
                diff = _git(['diff', '--cached', '--name-only', '--', pattern])
                if diff.stdout.strip():
                    staged_files.extend(diff.stdout.strip().splitlines())

        # Remove any inbox files that got staged
        _git(['reset', 'HEAD', '--', f'{agents_rel}/*/inbox/'])

        # Check if anything is staged
        check = _git(['diff', '--cached', '--name-only'])
        if not check.stdout.strip():
            if not on_main:
                _git(['checkout', original_branch])
                if stashed:
                    _git(['stash', 'pop'])
            return {'status': 'no_changes', 'message': 'No agent state changes to commit.'}

        final_files = check.stdout.strip().splitlines()
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M')

        # Commit
        commit = _git(['commit', '-m', f'chore: update agent state [{timestamp}]'])
        if commit.returncode != 0:
            _git(['reset', 'HEAD'])
            if not on_main:
                _git(['checkout', original_branch])
                if stashed:
                    _git(['stash', 'pop'])
            raise ToolError(f'Failed to commit: {commit.stderr.strip()}')

        # Get commit hash
        hash_result = _git(['rev-parse', '--short', 'HEAD'])
        commit_hash = hash_result.stdout.strip()

        # Push
        push = _git(['push', 'origin', 'main'])
        push_failed = push.returncode != 0
        push_error = push.stderr.strip() if push_failed else None

        # Restore original branch
        if not on_main:
            _git(['checkout', original_branch])
            if stashed:
                _git(['stash', 'pop'])

        result = {
            'status': 'committed',
            'commit': commit_hash,
            'files': final_files,
            'files_count': len(final_files),
            'pushed': not push_failed,
        }
        if push_failed:
            result['push_error'] = push_error

        return result

    except ToolError:
        raise
    except Exception as e:
        # Safety net: restore branch
        if not on_main:
            _git(['checkout', original_branch])
            if stashed:
                _git(['stash', 'pop'])
        raise ToolError(f'Unexpected error: {e}')


# ── entry point ──────────────────────────────────────────────────────────

if __name__ == '__main__':
    mcp.run(transport='stdio')
