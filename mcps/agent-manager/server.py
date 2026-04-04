"""
Agent Manager MCP Server
=========================
Manages agents: list, look up, create, launch, restart, status, messaging, and conversations.

Environment Variables:
  Required:
    WORKSPACE_PATH       — path to workspace root
    AGENTS_PATH          — path to agents/ root (contains agent folders)
    ITERM_PROFILES_PATH  — path to iTerm2 DynamicProfiles/agents.json
  Optional:
    OPS_PATH             — path for operational data (inbox, conversations, health, inbox-queue).
                           Falls back to in-repo paths under AGENTS_PATH if not set.
"""
import asyncio
import json
import logging
import os
import re
import shutil
import subprocess
import textwrap
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('agent-manager')

WORKSPACE = os.environ.get('WORKSPACE_PATH', '')
AGENTS_DIR = os.environ.get('AGENTS_PATH', '')
ITERM_PROFILES = os.environ.get('ITERM_PROFILES_PATH', '')
OPS_PATH = os.environ.get('OPS_PATH', '')

mcp = FastMCP('agent-manager')


# ── ops path ─────────────────────────────────────────────────────────────

def _ops_root() -> Optional[Path]:
    """Return the ops directory if OPS_PATH is set and exists, else None."""
    if not OPS_PATH:
        return None
    p = Path(OPS_PATH)
    p.mkdir(parents=True, exist_ok=True)
    return p


# ── helpers ──────────────────────────────────────────────────────────────

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
    """Extract the first line of a ## section from markdown text."""
    match = re.search(f'^## {heading}\n(.*?)(?:\n## |\\Z)', text, re.MULTILINE | re.DOTALL)
    if not match:
        return ''
    lines = [l.lstrip('- ').strip() for l in match.group(1).strip().splitlines() if l.strip()]
    return lines[0] if lines else ''


def _read_agent_info(agent_dir: Path, name: str) -> dict[str, str]:
    """Read role and specialty from the agent's memory file."""
    memory = agent_dir / 'memory' / f'{name}.md'
    if not memory.exists():
        return {'role': '', 'specialty': ''}
    text = memory.read_text()
    return {
        'role': _read_section(text, 'Role'),
        'specialty': _read_section(text, 'Specialty'),
    }


def _find_agent(name: str) -> Path:
    """Find agent directory. Raises ToolError if not found."""
    name = name.lower().strip()
    root = _agents_root()
    agent_dir = root / name
    if _is_agent_dir(agent_dir):
        return agent_dir
    raise ToolError(f"Agent '{name}' not found.")


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


# ── grid / window layout ────────────────────────────────────────────────

GRID_COLS = 3
GRID_ROWS = 2
GRID_SLOTS = GRID_COLS * GRID_ROWS


def _get_screen_size() -> tuple[int, int]:
    script = 'tell application "Finder" to get bounds of window of desktop'
    result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
    if result.returncode == 0 and result.stdout.strip():
        parts = result.stdout.strip().split(', ')
        if len(parts) == 4:
            return (int(parts[2]), int(parts[3]))
    return (1920, 1080)


def _grid_bounds(slot: int) -> tuple[int, int, int, int]:
    screen_w, screen_h = _get_screen_size()

    menu_bar = 25
    usable_h = screen_h - menu_bar
    col = slot % GRID_COLS
    row = slot // GRID_COLS
    w = screen_w // GRID_COLS
    h = usable_h // GRID_ROWS
    x = col * w
    y = menu_bar + row * h
    return (x, y, x + w, y + h)


def _count_agent_windows() -> int:
    return len(_get_iterm_agent_windows())


def _position_iterm_window(slot: int):
    x1, y1, x2, y2 = _grid_bounds(slot)
    script = f"""
tell application "iTerm"
    set bounds of current window to {{{x1}, {y1}, {x2}, {y2}}}
end tell
"""
    subprocess.run(['osascript', '-e', script], capture_output=True, text=True)


def _add_iterm_profile(name: str, agent_dir: Path) -> str:
    if not ITERM_PROFILES:
        return 'skipped — ITERM_PROFILES_PATH not set'
    profiles_path = Path(ITERM_PROFILES)
    if not profiles_path.exists():
        return f'skipped — {ITERM_PROFILES} not found'
    try:
        data = json.loads(profiles_path.read_text())
    except (json.JSONDecodeError, OSError) as e:
        return f'skipped — could not read profiles: {e}'

    guid = f'agent-{name}'
    profiles = data.get('Profiles', [])
    if any(p.get('Guid') == guid for p in profiles):
        return 'already exists'

    profiles.append({
        'Background Image Mode': 2,
        'Background Image Location': str(agent_dir / 'iterm' / 'background.jpg'),
        'Blend': 0.15,
        'Guid': guid,
        'Tags': ['agents'],
        'Custom Directory': 'Recycle',
        'Name': name.capitalize(),
    })
    data['Profiles'] = profiles
    profiles_path.write_text(json.dumps(data, indent=2) + '\n')
    return 'added'


def _remove_iterm_profile(name: str) -> str:
    if not ITERM_PROFILES:
        return 'skipped — ITERM_PROFILES_PATH not set'
    profiles_path = Path(ITERM_PROFILES)
    if not profiles_path.exists():
        return 'skipped — not found'
    try:
        data = json.loads(profiles_path.read_text())
    except (json.JSONDecodeError, OSError):
        return 'skipped — could not read'

    guid = f'agent-{name}'
    before = len(data.get('Profiles', []))
    data['Profiles'] = [p for p in data.get('Profiles', []) if p.get('Guid') != guid]
    if len(data['Profiles']) == before:
        return 'not found in profiles'

    profiles_path.write_text(json.dumps(data, indent=2) + '\n')
    return 'removed'


# ── tools ────────────────────────────────────────────────────────────────

@mcp.tool()
async def list_agents() -> list[dict[str, str]]:
    """List all agents with their role and specialty."""
    return _scan_agents()


@mcp.tool()
async def get_agent(name: str) -> dict[str, str]:
    """Look up a single agent by name.

    Returns name, role, specialty, and directory.
    """
    agent_dir = _find_agent(name)
    info = _read_agent_info(agent_dir, name.lower().strip())
    return {
        'name': name.lower().strip(),
        'role': info['role'],
        'specialty': info['specialty'],
        'directory': str(agent_dir),
    }


@mcp.tool()
async def create_agent(
    name: str,
    role: str,
    gender: str = 'Male',
    age: int = 30,
    personality: str = '',
    appearance: str = '',
    backstory: str = '',
    speaking_style: str = '',
    quirks: str = '',
    interests: str = '',
    relationship: str = '',
) -> dict:
    """Create a new agent.

    Creates the directory structure, profile.md, memory file, and iTerm2 profile.

    Args:
        name: Agent name (lowercase)
        role: Agent's role description
        gender: Gender (default Male)
        age: Age (default 30)
        personality: Comma-separated personality traits
        appearance: Physical appearance description
        backstory: Agent backstory
        speaking_style: How the agent speaks
        quirks: Newline-separated quirks
        interests: Interests description
        relationship: Relationship to Duong
    """
    name = name.lower().strip()
    root = _agents_root()

    agent_dir = root / name
    if agent_dir.exists():
        raise ToolError(f"Agent '{name}' already exists.")
    for sub in ('memory', 'journal', 'transcripts', 'iterm'):
        (agent_dir / sub).mkdir(parents=True, exist_ok=True)

    display = name.capitalize()

    # Write profile.md
    profile_parts = [f'# {display}\n']
    profile_parts.append(f'## Age\n{age}\n')
    if appearance:
        profile_parts.append(f'## Appearance\n{appearance}\n')
    if backstory:
        profile_parts.append(f'## Backstory\n{backstory}\n')
    if speaking_style:
        profile_parts.append(f'## Speaking Style\n{speaking_style}\n')
    if quirks:
        quirk_lines = '\n'.join(f'- {q.strip()}' for q in quirks.split('\n') if q.strip())
        profile_parts.append(f'## Quirks\n{quirk_lines}\n')
    if interests:
        profile_parts.append(f'## Interests\n{interests}\n')
    profile_parts.append(f'## Role\n{role}\n')
    if relationship:
        profile_parts.append(f'## Relationship to Duong\n{relationship}\n')
    (agent_dir / 'profile.md').write_text('\n'.join(profile_parts))

    # Write memory file
    trait_lines = ''
    if personality:
        trait_lines = '\n'.join(f'- {t.strip()}' for t in personality.split(',') if t.strip())
    else:
        trait_lines = f'- {gender}'

    memory = textwrap.dedent(f"""\
        # {display}

        ## Personality
        - {gender}
        {trait_lines}

        ## Role
        - {role}

        ## Sessions
        (none yet)
    """)
    (agent_dir / 'memory' / f'{name}.md').write_text(memory)

    iterm_result = _add_iterm_profile(name, agent_dir)

    log.info(f"Created agent '{name}'")
    return {
        'agent': name,
        'directory': str(agent_dir),
        'iterm_profile': iterm_result,
        'next_steps': [
            f'Drop a background image at {agent_dir}/iterm/background.jpg',
            'Update routing tables in CLAUDE.md if needed',
        ],
    }



# ── inbox ────────────────────────────────────────────────────────────────

def _inbox_dir(agent_name: str) -> Path:
    """Get (and ensure) the inbox directory for an agent."""
    ops = _ops_root()
    if ops:
        d = ops / 'inbox' / agent_name.lower().strip()
    else:
        agent_dir = _find_agent(agent_name)
        d = agent_dir / 'inbox'
    d.mkdir(parents=True, exist_ok=True)
    return d


def _inbox_queue_dir() -> Path:
    """Central queue for action-priority messages awaiting Duong's approval."""
    ops = _ops_root()
    if ops:
        d = ops / 'inbox-queue'
    else:
        d = _agents_root() / 'inbox-queue'
    d.mkdir(parents=True, exist_ok=True)
    return d


def _write_inbox_message(
    sender: str,
    recipient: str,
    message: str,
    priority: str = 'info',
    conversation: Optional[str] = None,
    context: Optional[str] = None,
) -> Path:
    """Write an inbox .md file to the recipient's inbox/ folder.

    Returns the path to the created file.
    """
    inbox = _inbox_dir(recipient)
    ts = datetime.now().strftime('%Y%m%d-%H%M')
    filename = f'{ts}-{sender.lower()}-{priority}.md'
    path = inbox / filename

    frontmatter_lines = [
        '---',
        f'from: {sender.lower()}',
        f'to: {recipient.lower()}',
        f'priority: {priority}',
        f'timestamp: {datetime.now().strftime("%Y-%m-%d %H:%M")}',
    ]
    if conversation:
        frontmatter_lines.append(f'conversation: {conversation}')
    if context:
        frontmatter_lines.append(f'context: {context}')
    frontmatter_lines.append('status: pending')
    frontmatter_lines.append('---')
    frontmatter_lines.append('')
    frontmatter_lines.append(message)
    frontmatter_lines.append('')

    path.write_text('\n'.join(frontmatter_lines))
    return path


# ── messaging ────────────────────────────────────────────────────────────

@mcp.tool()
async def launch_agent(name: str, task: str = '') -> dict[str, str]:
    """Launch an agent in autonomous mode in a new iTerm2 window.

    The agent boots into Claude Code and receives an autonomous-mode
    greeting. If a task is provided, it is delivered via the inbox system
    after launch.

    Args:
        name: Agent name to launch
        task: Optional task message to deliver after launch
    """
    if not WORKSPACE:
        raise ToolError('WORKSPACE_PATH not set')

    agent_dir = _find_agent(name)
    recipient = name.strip().lower()
    greeting = recipient.capitalize()

    # Check if already running
    iterm_windows = _get_iterm_agent_windows()
    for w in iterm_windows:
        if w['name'].lower() == recipient:
            raise ToolError(f'{greeting} is already running. Use message_agent to send messages.')

    slot = _count_agent_windows() % GRID_SLOTS
    open_script = f"""
tell application "iTerm"
    activate
    set newWindow to (create window with profile "{greeting}")
    tell current session of current tab of newWindow
        set name to "{greeting}"
        write text "cd {WORKSPACE} && claude"
    end tell
end tell
"""
    subprocess.run(['osascript', '-e', open_script], check=True)
    _position_iterm_window(slot)

    await asyncio.sleep(2)

    startup = f'[autonomous] {greeting}, you have been launched by another agent. Check your inbox for tasks.'
    iterm_windows = _get_iterm_agent_windows()
    for w in iterm_windows:
        if w['name'].lower() == recipient:
            _send_to_iterm_window(w['window_id'], startup)
            break

    _set_agent_status(recipient, 'idle')

    result = {
        'agent': recipient,
        'status': 'launched',
        'mode': 'autonomous',
    }

    # Deliver task via inbox if provided
    if task:
        await asyncio.sleep(1)
        inbox_path = _write_inbox_message(
            sender='system',
            recipient=recipient,
            message=task,
            priority='info',
        )
        iterm_windows = _get_iterm_agent_windows()
        for w in iterm_windows:
            if w['name'].lower() == recipient:
                _send_to_iterm_window(w['window_id'], f'[inbox] {inbox_path}')
                break
        result['task_delivered'] = 'true'

    return result


@mcp.tool()
async def message_agent(
    name: str,
    message: str,
    sender: str = '',
    priority: str = 'info',
    conversation: Optional[str] = None,
    context: Optional[str] = None,
) -> str:
    """Send a message to an agent via the inbox system.

    Writes an inbox file to the agent's inbox/ folder, then delivers
    a short pointer to the agent's iTerm window. The agent reads the
    full message from disk.

    Priority tiers:
      - info: auto-delivered immediately (status updates, FYI)
      - action: queued in agents/inbox-queue/ for Duong's approval

    Args:
        name: Target agent name
        message: Message to send
        sender: Who is sending
        priority: 'info' (default, immediate) or 'action' (queued for approval)
        conversation: Optional conversation title for threading
        context: Optional one-line summary of prior conversation context
    """
    if not WORKSPACE:
        raise ToolError('WORKSPACE_PATH not set')

    recipient = name.strip().lower()
    greeting = recipient.capitalize()

    # Write inbox file
    inbox_path = _write_inbox_message(
        sender=sender or 'system',
        recipient=recipient,
        message=message,
        priority=priority,
        conversation=conversation,
        context=context,
    )

    # For action priority, copy to central queue for Duong's approval
    if priority == 'action':
        queue_dir = _inbox_queue_dir()
        queue_path = queue_dir / inbox_path.name
        shutil.copy2(inbox_path, queue_path)
        return f'Message queued for approval in inbox-queue/ (also saved to {greeting} inbox)'

    # For info priority, deliver immediately via iTerm
    iterm_windows = _get_iterm_agent_windows()
    existing_window = None
    for w in iterm_windows:
        if w['name'].lower() == recipient:
            existing_window = w
            break

    pointer = f'[inbox] {inbox_path}'

    if existing_window:
        _send_to_iterm_window(existing_window['window_id'], pointer)
        return f'Delivered to {greeting} (existing session) via inbox'

    # Agent not running — caller should use launch_agent first
    return f'{greeting} is not running. Use launch_agent to start them first.'


# ── session management ───────────────────────────────────────────────────

CLAUDE_PROJECTS_DIR = Path.home() / '.claude' / 'projects'


def _workspace_project_dir() -> Path:
    if not WORKSPACE:
        raise ToolError('WORKSPACE_PATH not set')
    encoded = WORKSPACE.replace('/', '-')
    project_dir = CLAUDE_PROJECTS_DIR / encoded
    if not project_dir.is_dir():
        raise ToolError(f'Claude project directory not found: {project_dir}')
    return project_dir


def _find_agent_sessions(agent_names: set[str]) -> dict[str, str]:
    """Find the most recent Claude session ID for each agent.

    Scans JSONL transcript files looking for 'Hey <AgentName>' patterns
    in user messages to identify which session belongs to which agent.
    """
    project_dir = _workspace_project_dir()
    jsonl_files = sorted(project_dir.glob('*.jsonl'), key=lambda f: f.stat().st_mtime, reverse=True)

    found = {}
    for jf in jsonl_files[:50]:
        session_id = jf.stem
        try:
            with open(jf) as f:
                for line in f:
                    data = json.loads(line)
                    if data.get('type') != 'user':
                        continue
                    content = data.get('message', {}).get('content', '')
                    if isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict) and block.get('type') == 'text':
                                content = block.get('text', '')
                                break
                        else:
                            content = ''
                    if isinstance(content, str):
                        match = re.match(r'Hey\s+(\w+)', content, re.IGNORECASE) or \
                                re.match(r'\[autonomous\]\s+(\w+)', content, re.IGNORECASE)
                        if match:
                            name = match.group(1).lower()
                            if name in agent_names and name not in found:
                                found[name] = session_id
                    break
        except (json.JSONDecodeError, OSError):
            continue

        if len(found) >= len(agent_names):
            break

    return found


def _get_iterm_agent_windows() -> list[dict[str, str]]:
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


def _send_to_iterm_window(window_id: str, text: str) -> bool:
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


@mcp.tool()
async def restart_agents(exclude: Optional[list[str]] = None) -> dict[str, Any]:
    """Restart all running agent sessions.

    Sends /exit to each agent window, waits, then resumes the session
    using the session ID found in the JSONL transcript files.

    Args:
        exclude: Optional list of agent names to skip
    """
    if not WORKSPACE:
        raise ToolError('WORKSPACE_PATH not set')

    exclude_set = {n.lower() for n in (exclude or [])}

    all_agents = _scan_agents()
    agent_names = {a['name'] for a in all_agents}

    # Find agent windows in iTerm
    iterm_windows = _get_iterm_agent_windows()
    agent_windows = []
    for w in iterm_windows:
        name_lower = w['name'].lower()
        if name_lower in agent_names and name_lower not in exclude_set:
            agent_windows.append({'name': name_lower, 'display': w['name'], 'window_id': w['window_id']})

    if not agent_windows:
        return {'restarted': [], 'skipped': list(exclude_set), 'message': 'No agent windows found to restart.'}

    # Find session IDs
    target_names = {aw['name'] for aw in agent_windows}
    session_map = _find_agent_sessions(target_names)

    # Restart each agent
    restarted = []
    failed = []

    for aw in agent_windows:
        name = aw['name']
        display = aw['display']
        wid = aw['window_id']
        session_id = session_map.get(name)

        if not session_id:
            failed.append({'name': display, 'reason': 'session ID not found in JSONL files'})
            continue

        log.info(f'Restarting {display} (session {session_id[:8]}...)')
        _send_to_iterm_window(wid, '/exit')
        await asyncio.sleep(4)

        _send_to_iterm_window(wid, f'claude --resume {session_id}')
        restarted.append({'name': display, 'session_id': session_id})
        await asyncio.sleep(2)

    return {
        'restarted': restarted,
        'failed': failed,
        'skipped': list(exclude_set),
    }


@mcp.tool()
async def end_all_sessions(exclude: Optional[list[str]] = None) -> dict[str, Any]:
    """End all running agent sessions.

    Messages each agent with instructions to follow the session closing protocol
    (end_session tool, journal, handoff note, memory update, learnings).

    Args:
        exclude: Optional list of agent names to skip
    """
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


# ── conversations ────────────────────────────────────────────────────────

def _conversations_dir() -> Path:
    ops = _ops_root()
    if ops:
        d = ops / 'conversations'
    else:
        if not AGENTS_DIR:
            raise ToolError('AGENTS_PATH not configured.')
        d = Path(AGENTS_DIR) / 'conversations'
    d.mkdir(parents=True, exist_ok=True)
    return d


def _slugify(title: str) -> str:
    slug = re.sub(r'[^\w\s-]', '', title.lower().strip())
    slug = re.sub(r'[\s_]+', '-', slug)
    return slug[:80].strip('-')


def _timestamp() -> str:
    return datetime.now().strftime('%Y-%m-%d %H:%M')


# ── agent status registry (Phase 1) ─────────────────────────────────────

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


def _is_stale(last_heartbeat: str, threshold_minutes: int = 5) -> bool:
    try:
        ts = datetime.fromisoformat(last_heartbeat.replace('Z', '+00:00'))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return datetime.now(timezone.utc) - ts > timedelta(minutes=threshold_minutes)
    except (ValueError, TypeError):
        return True


@mcp.tool()
async def agent_status(name: Optional[str] = None) -> dict:
    """Check agent status from the health registry.

    If name is given, returns that agent's status.
    If omitted, returns all agents with their status.
    Agents are marked offline if their last heartbeat is older than 5 minutes.

    Args:
        name: Optional agent name. If omitted, returns all.
    """
    registry = _read_registry()

    if name:
        name = name.lower().strip()
        entry = registry.get(name, {})
        if not entry:
            return {'name': name, 'status': 'offline'}
        if _is_stale(entry.get('last_heartbeat', '')):
            entry['status'] = 'offline'
        entry['name'] = name
        return entry

    all_agents = _scan_agents()
    result = {}
    for agent in all_agents:
        n = agent['name']
        entry = registry.get(n, {})
        status = entry.get('status', 'offline')
        if entry and _is_stale(entry.get('last_heartbeat', '')):
            status = 'offline'
        result[n] = {
            'role': agent['role'],
            'status': status,
            'last_heartbeat': entry.get('last_heartbeat'),
            'platform': entry.get('platform'),
            'current_task': entry.get('current_task'),
        }
    return result


def _set_agent_status(name: str, status: str, platform: str = 'cli', task: Optional[str] = None):
    registry = _read_registry()
    registry[name] = {
        'status': status,
        'last_heartbeat': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S'),
        'platform': platform,
        'current_task': task,
    }
    _write_registry(registry)


# ── delivery confirmation (Phase 2) ─────────────────────────────────────

def _parse_inbox_frontmatter(path: Path) -> dict[str, str]:
    try:
        text = path.read_text()
        if not text.startswith('---'):
            return {}
        end = text.index('---', 3)
        fm = {}
        for line in text[3:end].strip().splitlines():
            if ':' in line:
                k, v = line.split(':', 1)
                fm[k.strip()] = v.strip()
        return fm
    except (OSError, ValueError):
        return {}


@mcp.tool()
async def check_inbox_status(
    recipient: str,
    sender: Optional[str] = None,
    since_minutes: int = 30,
) -> list[dict]:
    """Check delivery status of messages sent to an agent.

    Args:
        recipient: Agent whose inbox to check
        sender: Optional filter by sender
        since_minutes: Only check messages from the last N minutes (default 30)
    """
    inbox = _inbox_dir(recipient.lower().strip())
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=since_minutes)
    results = []
    for f in sorted(inbox.glob('*.md'), reverse=True):
        fm = _parse_inbox_frontmatter(f)
        if not fm:
            continue
        if sender and fm.get('from', '') != sender.lower():
            continue
        try:
            ts = datetime.strptime(fm.get('timestamp', ''), '%Y-%m-%d %H:%M').replace(tzinfo=timezone.utc)
            if ts < cutoff:
                continue
        except ValueError:
            continue
        results.append({
            'filename': f.name,
            'from': fm.get('from', ''),
            'status': fm.get('status', 'unknown'),
            'timestamp': fm.get('timestamp', ''),
            'conversation': fm.get('conversation', ''),
        })
    return results


@mcp.tool()
async def acknowledge_message(
    agent: str,
    filename: str,
    response: str = 'acknowledged',
) -> str:
    """Mark an inbox message as acknowledged and optionally record a short response.

    Args:
        agent: The agent acknowledging (must match the 'to' field)
        filename: Inbox filename to acknowledge
        response: Optional short response text
    """
    agent = agent.lower().strip()
    inbox = _inbox_dir(agent)
    path = inbox / filename
    if not path.exists():
        raise ToolError(f'Inbox file not found: {filename}')

    text = path.read_text()
    parts = text.split('---', 2)
    if len(parts) >= 3:
        fm = re.sub(r'^status:\s*\w+', f'status: acknowledged', parts[1], count=1, flags=re.MULTILINE)
        if 'response:' not in fm:
            fm = fm.rstrip('\n') + f'\nresponse: {response}\n'
        text = '---' + fm + '---' + parts[2]
    path.write_text(text)
    return f'Message {filename} acknowledged'


# ── turn-based conversations ─────────────────────────────────────────────

def _turn_conversation_path(title: str) -> Path:
    return _conversations_dir() / f'{_slugify(title)}.turn.md'


def _parse_turn_frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text()
    if not text.startswith('---'):
        raise ToolError('Invalid turn conversation file: missing frontmatter')
    end = text.index('---', 3)
    fm: dict[str, Any] = {}
    for line in text[3:end].strip().splitlines():
        if ':' not in line:
            continue
        k, v = line.split(':', 1)
        k = k.strip()
        v = v.strip()
        if k in ('participants', 'turn_order'):
            fm[k] = [x.strip().strip('[]') for x in v.split(',')]
        elif k == 'round':
            fm[k] = int(v)
        elif k == 'read_cursors':
            # parsed separately below
            pass
        else:
            fm[k] = v
    # Parse read_cursors block
    rc_match = re.search(r'read_cursors:\n((?:\s+\w+:\s*\d+\n?)+)', text[:end + 3])
    if rc_match:
        fm['read_cursors'] = {}
        for rc_line in rc_match.group(1).strip().splitlines():
            if ':' in rc_line:
                agent, val = rc_line.strip().split(':', 1)
                fm['read_cursors'][agent.strip()] = int(val.strip())
    else:
        fm['read_cursors'] = {}
    return fm


def _get_message_count(path: Path) -> int:
    text = path.read_text()
    return len(re.findall(r'^## \[\d+\]', text, re.MULTILINE))


def _write_turn_frontmatter(path: Path, fm: dict[str, Any]):
    text = path.read_text()
    end = text.index('---', 3) + 3
    body = text[end:]

    lines = ['---']
    lines.append(f'title: {fm["title"]}')
    lines.append(f'mode: turn-based')
    if fm.get('started_by'):
        lines.append(f'started_by: {fm["started_by"]}')
    lines.append(f'participants: [{", ".join(fm["participants"])}]')
    lines.append(f'turn_order: [{", ".join(fm["turn_order"])}]')
    lines.append(f'current_turn: {fm["current_turn"]}')
    lines.append(f'round: {fm["round"]}')
    lines.append(f'created: {fm["created"]}')
    if fm.get('status'):
        lines.append(f'status: {fm["status"]}')
    lines.append('read_cursors:')
    # Include starter in read_cursors if they exist
    all_cursor_agents = list(fm['turn_order'])
    if fm.get('started_by') and fm['started_by'] not in all_cursor_agents:
        all_cursor_agents.append(fm['started_by'])
    for agent in all_cursor_agents:
        lines.append(f'  {agent}: {fm["read_cursors"].get(agent, 0)}')
    lines.append('---')

    path.write_text('\n'.join(lines) + body)


def _get_messages_after_cursor(path: Path, cursor: int) -> list[str]:
    text = path.read_text()
    messages = re.findall(r'(^## \[\d+\].*?)(?=^## \[|\Z)', text, re.MULTILINE | re.DOTALL)
    result = []
    for msg in messages:
        m = re.match(r'^## \[(\d+)\]', msg)
        if m and int(m.group(1)) > cursor:
            result.append(msg.strip())
    return result


def _advance_turn(fm: dict[str, Any]):
    order = fm['turn_order']
    current_idx = order.index(fm['current_turn'])
    next_idx = (current_idx + 1) % len(order)
    fm['current_turn'] = order[next_idx]
    if next_idx == 0:
        fm['round'] = fm.get('round', 1) + 1


def _notify_next_agent(title: str, fm: dict[str, Any]):
    next_agent = fm['current_turn']
    round_num = fm['round']
    try:
        _write_inbox_message(
            sender='system',
            recipient=next_agent,
            message=f"It's your turn in conversation '{title}' (round {round_num}). Use read_new_messages(title={_slugify(title)}, agent={next_agent}) then speak_in_turn(title={_slugify(title)}, sender={next_agent}, message=<your message>).",
            priority='info',
            conversation=_slugify(title),
        )
        # Try to deliver via iTerm
        iterm_windows = _get_iterm_agent_windows()
        inbox = _inbox_dir(next_agent)
        latest = max(inbox.glob('*.md'), key=lambda p: p.stat().st_mtime, default=None)
        if latest:
            for w in iterm_windows:
                if w['name'].lower() == next_agent:
                    _send_to_iterm_window(w['window_id'], f'[inbox] {latest}')
                    break
    except ToolError:
        pass


@mcp.tool()
async def start_turn_conversation(
    title: str,
    sender: str,
    participants: list[str],
    turn_order: list[str],
    message: str,
) -> dict[str, str]:
    """Start a new turn-based multi-agent conversation.

    Creates a .turn.md file with strict turn enforcement.
    The sender posts the first message and the turn advances to the next agent.
    The sender does NOT need to be in turn_order — they can start a conversation
    as an observer (e.g., Evelynn delegating to other agents).

    Args:
        title: Conversation title (used as slug identifier)
        sender: Agent starting the conversation (need not be in turn_order)
        participants: List of all participant agent names
        turn_order: Ordered list for turn rotation
        message: Opening message
    """
    path = _turn_conversation_path(title)
    if path.exists():
        raise ToolError(f"Turn conversation '{title}' already exists.")

    sender = sender.lower().strip()
    participants = [p.lower().strip() for p in participants]
    turn_order = [t.lower().strip() for t in turn_order]

    for t in turn_order:
        if t not in participants:
            raise ToolError(f'{t} is in turn_order but not in participants')

    # Sender gets a read cursor whether or not they're in turn_order
    read_cursors = {p: 0 for p in turn_order}
    is_observer = sender not in turn_order
    if is_observer:
        read_cursors[sender] = 0

    now = _timestamp()
    first_turn = turn_order[0]

    fm = {
        'title': title,
        'participants': participants,
        'turn_order': turn_order,
        'current_turn': first_turn,
        'round': 1,
        'created': now,
        'status': 'active',
        'read_cursors': read_cursors,
    }
    if is_observer:
        fm['started_by'] = sender

    # Write initial file
    lines = ['---']
    lines.append(f'title: {title}')
    lines.append('mode: turn-based')
    if is_observer:
        lines.append(f'started_by: {sender}')
    lines.append(f'participants: [{", ".join(participants)}]')
    lines.append(f'turn_order: [{", ".join(turn_order)}]')
    lines.append(f'current_turn: {first_turn}')
    lines.append('round: 1')
    lines.append(f'created: {now}')
    lines.append('status: active')
    lines.append('read_cursors:')
    for agent in turn_order:
        lines.append(f'  {agent}: 0')
    if is_observer:
        lines.append(f'  {sender}: 0')
    lines.append('---')
    lines.append('')
    lines.append(f'## [1] {sender.capitalize()} — {now}')
    lines.append(message)
    lines.append('')

    path.write_text('\n'.join(lines))

    # Update read cursor for starter
    fm['read_cursors'][sender] = 1
    _write_turn_frontmatter(path, fm)

    # Notify next agent
    _notify_next_agent(title, fm)

    return {
        'conversation': title,
        'file': str(path),
        'participants': ', '.join(participants),
        'current_turn': fm['current_turn'],
        'round': str(fm['round']),
        'status': 'started',
    }


@mcp.tool()
async def speak_in_turn(
    title: str,
    sender: str,
    message: str,
) -> dict[str, Any]:
    """Speak in a turn-based conversation. Rejects if it's not the sender's turn.

    Internally reads new messages first (read-before-write), then appends
    the message and advances the turn to the next agent.

    Args:
        title: Conversation title
        sender: Agent speaking (must be current_turn)
        message: Message to post
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)

    if fm.get('status') == 'ended':
        raise ToolError(f"Conversation '{title}' has ended.")
    if fm.get('status') == 'escalated':
        raise ToolError(f"Conversation '{title}' is escalated. Use resolve_escalation to resume.")

    if fm['current_turn'] != sender:
        raise ToolError(f"Not {sender}'s turn. Current turn: {fm['current_turn']}")

    # Read-before-write: get new messages for this agent
    cursor = fm['read_cursors'].get(sender, 0)
    new_messages = _get_messages_after_cursor(path, cursor)

    # Append message
    msg_count = _get_message_count(path) + 1
    now = _timestamp()
    with open(path, 'a') as f:
        f.write(f'\n## [{msg_count}] {sender.capitalize()} — {now}\n{message}\n')

    # Update frontmatter
    fm['read_cursors'][sender] = msg_count
    _advance_turn(fm)
    _write_turn_frontmatter(path, fm)

    # Notify next agent
    _notify_next_agent(title, fm)

    return {
        'conversation': title,
        'sender': sender,
        'message_index': msg_count,
        'new_messages_read': len(new_messages),
        'messages_before_write': new_messages,
        'current_turn': fm['current_turn'],
        'round': fm['round'],
    }


@mcp.tool()
async def pass_turn(
    title: str,
    sender: str,
    reason: str = 'Nothing to add this round.',
) -> dict[str, Any]:
    """Pass your turn in a turn-based conversation without contributing content.

    Posts a [PASS] message and advances the turn.

    Args:
        title: Conversation title
        sender: Agent passing (must be current_turn)
        reason: Optional reason for passing
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)

    if fm.get('status') == 'ended':
        raise ToolError(f"Conversation '{title}' has ended.")
    if fm.get('status') == 'escalated':
        raise ToolError(f"Conversation '{title}' is escalated. Use resolve_escalation to resume.")

    if fm['current_turn'] != sender:
        raise ToolError(f"Not {sender}'s turn. Current turn: {fm['current_turn']}")

    msg_count = _get_message_count(path) + 1
    now = _timestamp()
    with open(path, 'a') as f:
        f.write(f'\n## [{msg_count}] {sender.capitalize()} — {now} [PASS]\n{reason}\n')

    fm['read_cursors'][sender] = msg_count
    _advance_turn(fm)
    _write_turn_frontmatter(path, fm)

    _notify_next_agent(title, fm)

    return {
        'conversation': title,
        'sender': sender,
        'action': 'pass',
        'message_index': msg_count,
        'current_turn': fm['current_turn'],
        'round': fm['round'],
    }


@mcp.tool()
async def end_turn_conversation(
    title: str,
    sender: str,
) -> dict[str, Any]:
    """Propose ending a turn-based conversation.

    Posts an [END] message and advances the turn. The conversation closes
    when all remaining agents in the round either END or PASS.

    Args:
        title: Conversation title
        sender: Agent proposing end (must be current_turn)
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)

    if fm.get('status') == 'ended':
        raise ToolError(f"Conversation '{title}' has already ended.")
    if fm.get('status') == 'escalated':
        raise ToolError(f"Conversation '{title}' is escalated. Use resolve_escalation to resume.")

    if fm['current_turn'] != sender:
        raise ToolError(f"Not {sender}'s turn. Current turn: {fm['current_turn']}")

    msg_count = _get_message_count(path) + 1
    now = _timestamp()
    with open(path, 'a') as f:
        f.write(f'\n## [{msg_count}] {sender.capitalize()} — {now} [END]\nProposing to end conversation.\n')

    fm['read_cursors'][sender] = msg_count
    _advance_turn(fm)

    # Check if conversation should close: scan messages in the current round
    # for END/PASS from all agents after the END proposer
    text = path.read_text()
    current_round = fm['round']
    order = fm['turn_order']

    # Find all END/PASS messages in recent history
    end_pass_agents = set()
    for m in re.finditer(r'^## \[\d+\] (\w+) — .+? \[(END|PASS)\]', text, re.MULTILINE):
        end_pass_agents.add(m.group(1).lower())

    # Check if all agents have END or PASS (conversation should close)
    all_done = all(agent in end_pass_agents for agent in order)
    if all_done:
        fm['status'] = 'ended'
        fm['current_turn'] = 'none'

    _write_turn_frontmatter(path, fm)

    if not all_done:
        _notify_next_agent(title, fm)

    return {
        'conversation': title,
        'sender': sender,
        'action': 'end_proposed',
        'message_index': msg_count,
        'conversation_ended': all_done,
        'current_turn': fm['current_turn'],
        'round': fm['round'],
    }


@mcp.tool()
async def read_new_messages(
    title: str,
    agent: str,
) -> dict[str, Any]:
    """Read only new messages since the agent's last read cursor.

    Updates the agent's read cursor after reading.

    Args:
        title: Conversation title
        agent: Agent reading messages
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    agent = agent.lower().strip()
    fm = _parse_turn_frontmatter(path)

    allowed = set(fm.get('participants', []) + fm.get('turn_order', []))
    if fm.get('started_by'):
        allowed.add(fm['started_by'])
    if agent not in allowed:
        raise ToolError(f'{agent} is not a participant in this conversation.')

    cursor = fm['read_cursors'].get(agent, 0)
    new_messages = _get_messages_after_cursor(path, cursor)

    # Update read cursor to latest message
    latest = _get_message_count(path)
    if latest > cursor:
        fm['read_cursors'][agent] = latest
        _write_turn_frontmatter(path, fm)

    return {
        'conversation': title,
        'agent': agent,
        'previous_cursor': cursor,
        'new_cursor': latest,
        'message_count': len(new_messages),
        'messages': new_messages,
    }


@mcp.tool()
async def get_turn_status(
    title: str,
) -> dict[str, Any]:
    """Get the current status of a turn-based conversation.

    Returns current_turn, round, read_cursors, and participant info.

    Args:
        title: Conversation title
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    fm = _parse_turn_frontmatter(path)
    msg_count = _get_message_count(path)

    return {
        'conversation': title,
        'status': fm.get('status', 'active'),
        'current_turn': fm['current_turn'],
        'round': fm['round'],
        'turn_order': fm['turn_order'],
        'participants': fm['participants'],
        'read_cursors': fm['read_cursors'],
        'total_messages': msg_count,
    }


@mcp.tool()
async def escalate_conversation(
    title: str,
    sender: str,
    reason: str,
) -> dict[str, Any]:
    """Escalate a turn-based conversation. Pauses the conversation and notifies Evelynn.

    Only the current_turn agent can escalate. Posts an [ESCALATE] message,
    sets status to escalated, and sends an inbox notification to Evelynn.

    Args:
        title: Conversation title
        sender: Agent escalating (must be current_turn)
        reason: Reason for escalation
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)

    if fm.get('status') == 'ended':
        raise ToolError(f"Conversation '{title}' has ended.")
    if fm.get('status') == 'escalated':
        raise ToolError(f"Conversation '{title}' is already escalated.")

    if fm['current_turn'] != sender:
        raise ToolError(f"Not {sender}'s turn. Current turn: {fm['current_turn']}")

    msg_count = _get_message_count(path) + 1
    now = _timestamp()
    with open(path, 'a') as f:
        f.write(f'\n## [{msg_count}] {sender.capitalize()} — {now} [ESCALATE]\n{reason}\n')

    fm['read_cursors'][sender] = msg_count
    fm['status'] = 'escalated'
    _write_turn_frontmatter(path, fm)

    # Notify Evelynn via inbox
    escalate_msg = f"[ESCALATE] Conversation '{title}' escalated by {sender}. Reason: {reason}. Use resolve_escalation(title={_slugify(title)}, sender=evelynn, resolution=<your resolution>, action=resume) to unpause, or action=escalate_to_duong to escalate further."
    try:
        inbox_path = _write_inbox_message(
            sender=sender,
            recipient='evelynn',
            message=escalate_msg,
            priority='info',
            conversation=_slugify(title),
            context=f'Escalation from {sender} in "{title}"',
        )
        iterm_windows = _get_iterm_agent_windows()
        for w in iterm_windows:
            if w['name'].lower() == 'evelynn':
                _send_to_iterm_window(w['window_id'], f'[inbox] {inbox_path}')
                break
    except ToolError:
        pass

    return {
        'conversation': title,
        'sender': sender,
        'action': 'escalated',
        'message_index': msg_count,
        'status': 'escalated',
        'current_turn': fm['current_turn'],
    }


@mcp.tool()
async def resolve_escalation(
    title: str,
    sender: str,
    resolution: str,
    action: str = 'resume',
) -> dict[str, Any]:
    """Resolve an escalated turn-based conversation.

    Either resumes the conversation or escalates further to Duong.

    Args:
        title: Conversation title
        sender: Agent resolving (typically Evelynn)
        resolution: Resolution message
        action: 'resume' to unpause conversation, or 'escalate_to_duong' to escalate further
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)

    if fm.get('status') != 'escalated':
        raise ToolError(f"Conversation '{title}' is not escalated (status: {fm.get('status')}).")

    if action not in ('resume', 'escalate_to_duong'):
        raise ToolError(f"Invalid action: {action}. Must be 'resume' or 'escalate_to_duong'.")

    msg_count = _get_message_count(path) + 1
    now = _timestamp()

    if action == 'resume':
        with open(path, 'a') as f:
            f.write(f'\n## [{msg_count}] {sender.capitalize()} — {now} [RESOLVED]\n{resolution}\n')

        fm['status'] = 'active'
        if sender in fm['read_cursors']:
            fm['read_cursors'][sender] = msg_count
        _write_turn_frontmatter(path, fm)

        # Notify the agent whose turn it still is
        _notify_next_agent(title, fm)

        return {
            'conversation': title,
            'sender': sender,
            'action': 'resumed',
            'message_index': msg_count,
            'status': 'active',
            'current_turn': fm['current_turn'],
            'round': fm['round'],
        }
    else:
        with open(path, 'a') as f:
            f.write(f'\n## [{msg_count}] {sender.capitalize()} — {now} [ESCALATE_TO_DUONG]\n{resolution}\n')

        if sender in fm['read_cursors']:
            fm['read_cursors'][sender] = msg_count
        _write_turn_frontmatter(path, fm)

        # Notify Duong via a special inbox message
        duong_msg = f"[ESCALATED TO YOU] Conversation '{title}' needs your attention. Context: {resolution}. Use resolve_escalation(title={_slugify(title)}, sender=duong, resolution=<decision>, action=resume) when ready."
        try:
            _write_inbox_message(
                sender=sender,
                recipient='duong',
                message=duong_msg,
                priority='action',
                conversation=_slugify(title),
                context=f'Escalation to Duong from {sender}',
            )
        except ToolError:
            pass

        return {
            'conversation': title,
            'sender': sender,
            'action': 'escalated_to_duong',
            'message_index': msg_count,
            'status': 'escalated',
            'current_turn': fm['current_turn'],
        }


@mcp.tool()
async def invite_to_conversation(
    title: str,
    sender: str,
    agent: str,
    position: Optional[int] = None,
) -> dict[str, Any]:
    """Invite a new agent into an active turn-based conversation.

    Any current participant (in turn_order) can invite. Does NOT require it to be
    the sender's turn. The new agent gets full history on first read_new_messages.

    Args:
        title: Conversation title
        sender: Agent sending the invite (must be in turn_order)
        agent: New agent to add
        position: Optional index in turn_order to insert at (default: append to end)
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    agent = agent.lower().strip()
    fm = _parse_turn_frontmatter(path)

    # Validate conversation status
    status = fm.get('status', 'active')
    if status in ('ended', 'escalated'):
        raise ToolError(f"Cannot invite into a conversation with status '{status}'.")

    # Sender must be in turn_order (not just started_by)
    if sender not in fm['turn_order']:
        raise ToolError(f'{sender.capitalize()} is not in turn_order and cannot invite.')

    # Agent must not already be in turn_order
    if agent in fm['turn_order']:
        raise ToolError(f'{agent.capitalize()} is already in turn_order.')

    # Validate the agent exists
    _find_agent(agent)

    # Insert into turn_order
    if position is not None and 0 <= position <= len(fm['turn_order']):
        fm['turn_order'].insert(position, agent)
    else:
        fm['turn_order'].append(agent)

    # Add to participants if not already there
    if agent not in fm['participants']:
        fm['participants'].append(agent)

    # Set read cursor to 0 — full history on first read
    fm['read_cursors'][agent] = 0

    # Post system JOIN message
    msg_count = _get_message_count(path) + 1
    now = _timestamp()
    with open(path, 'a') as f:
        f.write(f'\n## [{msg_count}] System — {now} [JOIN] {agent.capitalize()} invited by {sender.capitalize()}\n')

    # Write updated frontmatter
    _write_turn_frontmatter(path, fm)

    # Notify the new agent
    try:
        slug = _slugify(title)
        inbox_path = _write_inbox_message(
            sender='system',
            recipient=agent,
            message=f"You've been invited to conversation '{title}'. Use read_new_messages(title={slug}, agent={agent}) to read the full history, then wait for your turn.",
            priority='info',
            conversation=slug,
        )
        iterm_windows = _get_iterm_agent_windows()
        for w in iterm_windows:
            if w['name'].lower() == agent:
                _send_to_iterm_window(w['window_id'], f'[inbox] {inbox_path}')
                break
    except ToolError:
        pass

    return {
        'conversation': title,
        'invited': agent,
        'invited_by': sender,
        'position': fm['turn_order'].index(agent),
        'message_index': msg_count,
        'current_turn': fm['current_turn'],
    }


def _git(args: list[str], cwd: str | None = None) -> subprocess.CompletedProcess:
    """Run a git command and return the result."""
    return subprocess.run(
        ['git'] + args,
        cwd=cwd or WORKSPACE,
        capture_output=True,
        text=True,
    )


@mcp.tool()
async def commit_agent_state_to_main() -> dict[str, Any]:
    """Commit all agent state files to main branch and push.

    Stages agent memory, learnings, journals, and wip files (excluding inbox),
    commits to main with a standard message, and pushes to origin.
    Designed to be called by Evelynn as the final step of session closing.
    """
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
            pattern_path = Path(WORKSPACE) / pattern
            if pattern_path.exists():
                add_result = _git(['add', pattern])
                if add_result.returncode == 0:
                    # Check what was actually staged from this pattern
                    diff = _git(['diff', '--cached', '--name-only', '--', pattern])
                    if diff.stdout.strip():
                        staged_files.extend(diff.stdout.strip().splitlines())

        # Remove any inbox files that got staged
        unstage_inbox = _git(['reset', 'HEAD', '--', f'{agents_rel}/*/inbox/'])
        # Ignore errors — inbox dir may not exist or have nothing staged

        # Check if anything is staged
        check = _git(['diff', '--cached', '--name-only'])
        if not check.stdout.strip():
            # Nothing to commit — restore and return
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
        # Emergency cleanup
        if not on_main:
            _git(['checkout', original_branch])
            if stashed:
                _git(['stash', 'pop'])
        raise ToolError(f'Unexpected error: {str(e)}')


if __name__ == '__main__':
    log.info('Starting Agent Manager MCP in stdio mode')
    mcp.run(transport='stdio')
