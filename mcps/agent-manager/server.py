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
import sys
import textwrap
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError

# Import shared helpers
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from shared.helpers import (
    ops_root as _ops_root,
    agents_root as _agents_root,
    is_agent_dir as _is_agent_dir,
    read_section as _read_section,
    read_agent_info as _read_agent_info,
    scan_agents as _scan_agents,
    registry_path as _registry_path,
    read_registry as _read_registry,
    write_registry as _write_registry,
    set_agent_status as _set_agent_status,
    touch_heartbeat as _touch_heartbeat,
    get_iterm_agent_windows as _get_iterm_agent_windows,
    send_to_iterm_window as _send_to_iterm_window,
    WORKSPACE, AGENTS_DIR, ITERM_PROFILES, OPS_PATH,
)

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('agent-manager')

mcp = FastMCP('agent-manager')


def _find_agent(name: str) -> Path:
    """Find agent directory. Raises ToolError if not found."""
    name = name.lower().strip()
    root = _agents_root()
    agent_dir = root / name
    if _is_agent_dir(agent_dir):
        return agent_dir
    raise ToolError(f"Agent '{name}' not found.")


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

    # Resolve model tier for this agent
    AGENT_MODELS = {
        'evelynn': 'opus', 'syndra': 'opus', 'swain': 'opus', 'pyke': 'opus', 'bard': 'opus',
    }
    model_flag = AGENT_MODELS.get(recipient, 'sonnet')

    # Read agent GitHub token if available
    # Token is read from file at launch via $(cat ...) to avoid printing the secret
    # in terminal scrollback. The token propagates to all child processes (MCP servers,
    # Bash tool invocations) — this is intentional so agents can use gh/git commands.
    import stat
    token_file = os.path.join(WORKSPACE, 'secrets', 'agent-github-token')
    use_token = False
    if os.path.exists(token_file):
        st = os.stat(token_file)
        if st.st_mode & 0o077:
            log.warning(f'Token file {token_file} is too open (mode {oct(st.st_mode)}). Run: chmod 600 {token_file}')
        else:
            use_token = True

    if use_token:
        # Use $(cat ...) so the actual token value never appears in terminal scrollback
        quoted_path = token_file.replace("'", "'\\''")
        # Export token AND set git credential helper to lock auth to agent account
        launch_cmd = (
            f"export GH_TOKEN=$(cat '{quoted_path}') && export GITHUB_TOKEN=$(cat '{quoted_path}') && "
            f"cd {WORKSPACE} && "
            f"git config --local credential.https://github.com.helper "
            f"\"!f() {{ echo password=$(cat '{quoted_path}'); }}; f\" && "
            f"claude --model {model_flag}"
        )
    else:
        launch_cmd = f'cd {WORKSPACE} && claude --model {model_flag}'

    # Escape for AppleScript embedding
    launch_cmd_escaped = launch_cmd.replace('\\', '\\\\').replace('"', '\\"')

    slot = _count_agent_windows() % GRID_SLOTS
    open_script = f"""
tell application "iTerm"
    activate
    set newWindow to (create window with profile "{greeting}")
    tell current session of current tab of newWindow
        set name to "{greeting}"
        write text "{launch_cmd_escaped}"
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

    # Touch sender's heartbeat — every outbound message proves the sender is active
    if sender:
        _touch_heartbeat(sender.lower().strip())

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


@mcp.tool()
async def restart_agents(sender: str, exclude: Optional[list[str]] = None) -> dict[str, Any]:
    """Restart all running agents (exit + resume same session).

    Does NOT end sessions or trigger closing protocol.
    Use this when Duong says 'restart'.

    Sends /exit to each agent window, waits, then resumes the session
    using the session ID found in the JSONL transcript files.
    The sender is automatically excluded to prevent self-restart.

    Args:
        sender: Agent invoking this tool (auto-excluded from restart)
        exclude: Optional list of agent names to skip
    """
    if not WORKSPACE:
        raise ToolError('WORKSPACE_PATH not set')

    exclude_set = {n.lower() for n in (exclude or [])}
    exclude_set.add(sender.lower().strip())

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


# ── agent status registry ─────────────────────────────────────────────

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


# ── context health monitoring ─────────────────────────────────────────

VALID_WEIGHTS = ('light', 'medium', 'heavy', 'critical')


@mcp.tool()
async def report_context_health(
    agent: str,
    turn_count: int,
    estimated_weight: str,
    compression_events: int = 0,
    notes: str = '',
) -> dict[str, Any]:
    """Report context health for the current agent session.

    Agents should call this every ~10 turns, or immediately when
    compression occurs (with compression_events incremented).

    Args:
        agent: Agent name
        turn_count: Number of user/assistant turns in this session
        estimated_weight: Self-assessed weight — light, medium, heavy, or critical
        compression_events: How many times the system has compressed prior messages
        notes: Optional notes (e.g., "large file reads", "compression just happened")
    """
    agent = agent.lower().strip()
    if estimated_weight not in VALID_WEIGHTS:
        raise ToolError(f'Invalid estimated_weight: {estimated_weight}. Must be one of: {", ".join(VALID_WEIGHTS)}')

    registry = _read_registry()
    entry = registry.get(agent, {})
    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S')

    entry['context_health'] = {
        'turn_count': turn_count,
        'estimated_weight': estimated_weight,
        'compression_events': compression_events,
        'notes': notes,
        'last_report': now,
        'session_start': entry.get('context_health', {}).get('session_start', now),
    }
    entry['last_heartbeat'] = now
    registry[agent] = entry
    _write_registry(registry)

    return {
        'agent': agent,
        'status': 'reported',
        'context_health': entry['context_health'],
    }


@mcp.tool()
async def get_agent_health_summary() -> dict[str, Any]:
    """Get context health summary for all running agents.

    Returns per-agent: turn_count, estimated_weight, compression_events,
    session_duration, and a recommendation (ok/restart-soon/restart-now).
    """
    registry = _read_registry()
    now = datetime.now(timezone.utc)
    summary = {}

    for agent_name, entry in registry.items():
        status = entry.get('status', 'offline')
        if _is_stale(entry.get('last_heartbeat', '')):
            status = 'offline'

        ch = entry.get('context_health', {})
        if not ch:
            summary[agent_name] = {'status': status, 'context_health': None, 'recommendation': 'unknown'}
            continue

        # Calculate session duration
        session_start = ch.get('session_start', '')
        duration_hours = 0.0
        if session_start:
            try:
                start_ts = datetime.fromisoformat(session_start.replace('Z', '+00:00'))
                if start_ts.tzinfo is None:
                    start_ts = start_ts.replace(tzinfo=timezone.utc)
                duration_hours = (now - start_ts).total_seconds() / 3600
            except (ValueError, TypeError):
                pass

        weight = ch.get('estimated_weight', 'light')
        compressions = ch.get('compression_events', 0)
        turn_count = ch.get('turn_count', 0)

        # Recommendation logic
        if weight == 'critical' or compressions >= 2 or duration_hours > 5:
            recommendation = 'restart-now'
        elif weight == 'heavy' or compressions >= 1 or duration_hours > 3:
            recommendation = 'restart-soon'
        else:
            recommendation = 'ok'

        summary[agent_name] = {
            'status': status,
            'turn_count': turn_count,
            'estimated_weight': weight,
            'compression_events': compressions,
            'session_hours': round(duration_hours, 1),
            'recommendation': recommendation,
            'notes': ch.get('notes', ''),
        }

    return summary


# ── task delegation tracking ──────────────────────────────────────────

def _delegations_dir() -> Path:
    ops = _ops_root()
    if ops:
        d = ops / 'delegations'
    else:
        if not AGENTS_DIR:
            raise ToolError('AGENTS_PATH not configured.')
        d = Path(AGENTS_DIR) / 'delegations'
    d.mkdir(parents=True, exist_ok=True)
    return d


def _next_delegation_id() -> str:
    ts = datetime.now().strftime('%Y%m%d-%H%M%S')
    rand = os.urandom(3).hex()
    return f'd-{ts}-{rand}'


def _parse_deadline(deadline: str) -> Optional[str]:
    """Parse deadline string. Accepts '5m', '15m', '30m', '1h', '2h' or ISO timestamp."""
    if not deadline:
        return None
    deadline = deadline.strip()
    now = datetime.now(timezone.utc)
    if deadline.endswith('m'):
        try:
            minutes = int(deadline[:-1])
            return (now + timedelta(minutes=minutes)).strftime('%Y-%m-%dT%H:%M:%SZ')
        except ValueError:
            pass
    if deadline.endswith('h'):
        try:
            hours = int(deadline[:-1])
            return (now + timedelta(hours=hours)).strftime('%Y-%m-%dT%H:%M:%SZ')
        except ValueError:
            pass
    # Validate as ISO timestamp
    try:
        datetime.fromisoformat(deadline.replace('Z', '+00:00'))
        return deadline
    except (ValueError, TypeError):
        raise ToolError(f'Invalid deadline format: {deadline}. Use "5m", "15m", "1h" or ISO timestamp.')


def _read_delegation(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def _write_delegation(path: Path, data: dict[str, Any]):
    path.write_text(json.dumps(data, indent=2) + '\n')


@mcp.tool()
async def delegate_task(
    sender: str,
    agent: str,
    task: str,
    deadline: str = '',
) -> dict[str, Any]:
    """Delegate a tracked task to an agent.

    Creates a delegation record and delivers the task via inbox.
    The receiving agent must call complete_task when done.

    Args:
        sender: Who is delegating (usually evelynn)
        agent: Who is receiving the task
        task: Task description
        deadline: Optional — '5m', '15m', '30m', '1h', '2h', or ISO timestamp
    """
    sender = sender.lower().strip()
    agent = agent.lower().strip()
    _find_agent(agent)

    delegation_id = _next_delegation_id()
    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    parsed_deadline = _parse_deadline(deadline)

    record = {
        'id': delegation_id,
        'sender': sender,
        'agent': agent,
        'task': task,
        'status': 'pending',
        'created': now,
        'deadline': parsed_deadline,
        'completed_at': None,
        'report': None,
    }

    path = _delegations_dir() / f'{delegation_id}.json'
    _write_delegation(path, record)

    # Build inbox message with delegation ID and completion instructions
    deadline_line = f'\nDeadline: {parsed_deadline}' if parsed_deadline else ''
    inbox_msg = (
        f'[TASK {delegation_id}] {task}'
        f'{deadline_line}\n'
        f'When done: complete_task(agent={agent}, delegation_id={delegation_id}, report=<summary>)'
    )

    try:
        inbox_path = _write_inbox_message(
            sender=sender,
            recipient=agent,
            message=inbox_msg,
            priority='info',
        )
        # Deliver via iTerm if running
        iterm_windows = _get_iterm_agent_windows()
        for w in iterm_windows:
            if w['name'].lower() == agent:
                _send_to_iterm_window(w['window_id'], f'[inbox] {inbox_path}')
                break
    except ToolError:
        pass

    return {
        'delegation_id': delegation_id,
        'agent': agent,
        'task': task,
        'deadline': parsed_deadline,
        'status': 'delegated',
    }


@mcp.tool()
async def complete_task(
    agent: str,
    delegation_id: str,
    report: str,
) -> dict[str, Any]:
    """Mark a delegated task as complete with a summary report.

    Automatically notifies the delegating agent.

    Args:
        agent: Agent completing the task
        delegation_id: Delegation ID from the task assignment
        report: Summary of what was done
    """
    agent = agent.lower().strip()
    path = _delegations_dir() / f'{delegation_id}.json'

    if not path.exists():
        raise ToolError(f'Delegation {delegation_id} not found.')

    record = _read_delegation(path)
    if not record:
        raise ToolError(f'Could not read delegation {delegation_id}.')

    if record.get('agent') != agent:
        raise ToolError(f'Delegation {delegation_id} is assigned to {record.get("agent")}, not {agent}.')

    if record.get('status') == 'completed':
        raise ToolError(f'Delegation {delegation_id} is already completed.')

    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    record['status'] = 'completed'
    record['completed_at'] = now
    record['report'] = report
    _write_delegation(path, record)

    # Notify the delegator
    delegator = record.get('sender', '')
    if delegator:
        try:
            notify_msg = (
                f'[TASK COMPLETE {delegation_id}] {record.get("task", "")}\n'
                f'Agent: {agent}\n'
                f'Report: {report}'
            )
            inbox_path = _write_inbox_message(
                sender=agent,
                recipient=delegator,
                message=notify_msg,
                priority='info',
            )
            iterm_windows = _get_iterm_agent_windows()
            for w in iterm_windows:
                if w['name'].lower() == delegator:
                    _send_to_iterm_window(w['window_id'], f'[inbox] {inbox_path}')
                    break
        except ToolError:
            pass

    # Touch completing agent's heartbeat
    _touch_heartbeat(agent)

    return {
        'delegation_id': delegation_id,
        'status': 'completed',
        'agent': agent,
        'report': report,
    }


@mcp.tool()
async def check_delegations(
    sender: str = '',
    agent: str = '',
    status: str = '',
) -> list[dict[str, Any]]:
    """Check status of delegated tasks.

    Returns all matching delegations. Auto-marks tasks as overdue
    if past deadline and still pending.

    Args:
        sender: Filter by who delegated (optional)
        agent: Filter by who received (optional)
        status: Filter — pending, completed, overdue (optional)
    """
    sender = sender.lower().strip() if sender else ''
    agent = agent.lower().strip() if agent else ''
    status = status.lower().strip() if status else ''
    now = datetime.now(timezone.utc)

    d = _delegations_dir()
    results = []

    for f in sorted(d.glob('d-*.json'), reverse=True):
        record = _read_delegation(f)
        if not record:
            continue

        # Auto-mark overdue
        if record.get('status') == 'pending' and record.get('deadline'):
            try:
                dl = datetime.fromisoformat(record['deadline'].replace('Z', '+00:00'))
                if dl.tzinfo is None:
                    dl = dl.replace(tzinfo=timezone.utc)
                if now > dl:
                    record['status'] = 'overdue'
                    try:
                        _write_delegation(f, record)
                    except OSError as e:
                        log.warning(f'Failed to write overdue status for {f.name}: {e}')
            except (ValueError, TypeError):
                pass

        # Apply filters
        if sender and record.get('sender') != sender:
            continue
        if agent and record.get('agent') != agent:
            continue
        if status and record.get('status') != status:
            continue

        results.append(record)

    return results


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
        if k in ('participants', 'turn_order', 'spoken_this_round'):
            items = [x.strip().strip('[]') for x in v.split(',')]
            fm[k] = [x for x in items if x]  # filter empty strings from '[]'
        elif k in ('round', 'round_start_msg'):
            fm[k] = int(v)
        elif k == 'read_cursors':
            # parsed separately below
            pass
        elif k == 'suggested_next':
            # In flexible mode, suggested_next maps to current_turn internally
            fm['current_turn'] = v
            fm[k] = v
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

    is_flexible = fm.get('conversation_mode') == 'flexible'
    lines = ['---']
    lines.append(f'title: {fm["title"]}')
    lines.append(f'conversation_mode: {fm.get("conversation_mode", "ordered")}')
    if fm.get('started_by'):
        lines.append(f'started_by: {fm["started_by"]}')
    lines.append(f'participants: [{", ".join(fm["participants"])}]')
    lines.append(f'turn_order: [{", ".join(fm["turn_order"])}]')
    if is_flexible:
        lines.append(f'suggested_next: {fm["current_turn"]}')
        spoken = fm.get('spoken_this_round', [])
        lines.append(f'spoken_this_round: [{", ".join(spoken)}]')
    else:
        lines.append(f'current_turn: {fm["current_turn"]}')
    lines.append(f'round: {fm["round"]}')
    if fm.get('round_start_msg'):
        lines.append(f'round_start_msg: {fm["round_start_msg"]}')
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


def _advance_turn(fm: dict[str, Any], msg_count: int = 0):
    order = fm['turn_order']
    current_idx = order.index(fm['current_turn'])
    next_idx = (current_idx + 1) % len(order)
    fm['current_turn'] = order[next_idx]
    if next_idx == 0:
        fm['round'] = fm.get('round', 1) + 1
        fm['round_start_msg'] = msg_count


def _advance_flexible(fm: dict[str, Any], speaker: str, msg_count: int = 0):
    """Advance state in flexible mode after a speak/pass/end.

    Tracks who has spoken this round. When all turn_order agents have spoken
    or passed, the round advances and spoken_this_round resets.
    suggested_next rotates to the next agent who hasn't spoken this round.
    """
    spoken = fm.get('spoken_this_round', [])
    if speaker not in spoken:
        spoken.append(speaker)
    fm['spoken_this_round'] = spoken

    order = fm['turn_order']

    # Check if all agents in turn_order have spoken/passed this round
    if all(agent in spoken for agent in order):
        fm['round'] = fm.get('round', 1) + 1
        fm['round_start_msg'] = msg_count
        fm['spoken_this_round'] = []
        fm['current_turn'] = order[0]
    else:
        # Rotate suggested_next to next agent who hasn't spoken this round
        current_idx = order.index(fm['current_turn']) if fm['current_turn'] in order else 0
        for i in range(1, len(order) + 1):
            candidate = order[(current_idx + i) % len(order)]
            if candidate not in spoken:
                fm['current_turn'] = candidate
                break


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
    mode: str = 'ordered',
) -> dict[str, str]:
    """Start a new turn-based multi-agent conversation.

    Creates a .turn.md file with turn tracking. Supports two modes:
    - 'ordered' (default): Strict round-robin turn enforcement.
    - 'flexible': Any participant can speak at any time. A suggested_next hint
      rotates round-robin but is not enforced.

    The sender posts the first message and the turn advances to the next agent.
    The sender does NOT need to be in turn_order — they can start a conversation
    as an observer (e.g., Evelynn delegating to other agents).

    Args:
        title: Conversation title (used as slug identifier)
        sender: Agent starting the conversation (need not be in turn_order)
        participants: List of all participant agent names
        turn_order: Ordered list for turn rotation
        message: Opening message
        mode: 'ordered' (strict turns) or 'flexible' (any participant can speak)
    """
    if mode not in ('ordered', 'flexible'):
        raise ToolError(f"Invalid mode: {mode}. Must be 'ordered' or 'flexible'.")
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
        'conversation_mode': mode,
    }
    if mode == 'flexible':
        fm['spoken_this_round'] = []
    if is_observer:
        fm['started_by'] = sender

    # Write initial file
    lines = ['---']
    lines.append(f'title: {title}')
    lines.append(f'conversation_mode: {mode}')
    if is_observer:
        lines.append(f'started_by: {sender}')
    lines.append(f'participants: [{", ".join(participants)}]')
    lines.append(f'turn_order: [{", ".join(turn_order)}]')
    if mode == 'flexible':
        lines.append(f'suggested_next: {first_turn}')
        lines.append('spoken_this_round: []')
    else:
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
    """Speak in a turn-based conversation.

    In ordered mode, rejects if it's not the sender's turn.
    In flexible mode, any participant can speak at any time.

    Internally reads new messages first (read-before-write), then appends
    the message and advances the turn to the next agent.

    Args:
        title: Conversation title
        sender: Agent speaking (must be current_turn in ordered mode, any participant in flexible)
        message: Message to post
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)
    is_flexible = fm.get('conversation_mode') == 'flexible'

    if fm.get('status') == 'ended':
        raise ToolError(f"Conversation '{title}' has ended.")
    if fm.get('status') == 'escalated':
        raise ToolError(f"Conversation '{title}' is escalated. Use resolve_escalation to resume.")

    if is_flexible:
        # In flexible mode, any participant or turn_order member can speak
        allowed = set(fm.get('participants', []) + fm.get('turn_order', []))
        if fm.get('started_by'):
            allowed.add(fm['started_by'])
        if sender not in allowed:
            raise ToolError(f'{sender} is not a participant in this conversation.')
    else:
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
    prev_turn = fm['current_turn']
    prev_round = fm['round']
    if is_flexible:
        _advance_flexible(fm, sender, msg_count)
    else:
        _advance_turn(fm, msg_count)
    _write_turn_frontmatter(path, fm)

    # Notify next agent — in flexible mode, only if suggested_next changed or round advanced
    if not is_flexible or fm['current_turn'] != prev_turn or fm['round'] != prev_round:
        _notify_next_agent(title, fm)

    # Touch sender's heartbeat — every conversation turn proves the sender is active
    _touch_heartbeat(sender)

    result = {
        'conversation': title,
        'sender': sender,
        'message_index': msg_count,
        'new_messages_read': len(new_messages),
        'messages_before_write': new_messages,
        'round': fm['round'],
    }
    if is_flexible:
        result['suggested_next'] = fm['current_turn']
        result['spoken_this_round'] = fm.get('spoken_this_round', [])
    else:
        result['current_turn'] = fm['current_turn']
    return result


@mcp.tool()
async def pass_turn(
    title: str,
    sender: str,
    reason: str = 'Nothing to add this round.',
) -> dict[str, Any]:
    """Pass your turn in a turn-based conversation without contributing content.

    Posts a [PASS] message and advances the turn.
    In flexible mode, any participant can pass at any time.

    Args:
        title: Conversation title
        sender: Agent passing (must be current_turn in ordered mode, any participant in flexible)
        reason: Optional reason for passing
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)
    is_flexible = fm.get('conversation_mode') == 'flexible'

    if fm.get('status') == 'ended':
        raise ToolError(f"Conversation '{title}' has ended.")
    if fm.get('status') == 'escalated':
        raise ToolError(f"Conversation '{title}' is escalated. Use resolve_escalation to resume.")

    if is_flexible:
        allowed = set(fm.get('participants', []) + fm.get('turn_order', []))
        if fm.get('started_by'):
            allowed.add(fm['started_by'])
        if sender not in allowed:
            raise ToolError(f'{sender} is not a participant in this conversation.')
    else:
        if fm['current_turn'] != sender:
            raise ToolError(f"Not {sender}'s turn. Current turn: {fm['current_turn']}")

    msg_count = _get_message_count(path) + 1
    now = _timestamp()
    with open(path, 'a') as f:
        f.write(f'\n## [{msg_count}] {sender.capitalize()} — {now} [PASS]\n{reason}\n')

    fm['read_cursors'][sender] = msg_count
    prev_turn = fm['current_turn']
    prev_round = fm['round']
    if is_flexible:
        _advance_flexible(fm, sender, msg_count)
    else:
        _advance_turn(fm, msg_count)
    _write_turn_frontmatter(path, fm)

    if not is_flexible or fm['current_turn'] != prev_turn or fm['round'] != prev_round:
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
    In flexible mode, any participant can propose ending.

    Args:
        title: Conversation title
        sender: Agent proposing end (must be current_turn in ordered mode, any participant in flexible)
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)
    is_flexible = fm.get('conversation_mode') == 'flexible'

    if fm.get('status') == 'ended':
        raise ToolError(f"Conversation '{title}' has already ended.")
    if fm.get('status') == 'escalated':
        raise ToolError(f"Conversation '{title}' is escalated. Use resolve_escalation to resume.")

    if is_flexible:
        allowed = set(fm.get('participants', []) + fm.get('turn_order', []))
        if fm.get('started_by'):
            allowed.add(fm['started_by'])
        if sender not in allowed:
            raise ToolError(f'{sender} is not a participant in this conversation.')
    else:
        if fm['current_turn'] != sender:
            raise ToolError(f"Not {sender}'s turn. Current turn: {fm['current_turn']}")

    msg_count = _get_message_count(path) + 1
    now = _timestamp()
    with open(path, 'a') as f:
        f.write(f'\n## [{msg_count}] {sender.capitalize()} — {now} [END]\nProposing to end conversation.\n')

    fm['read_cursors'][sender] = msg_count
    if is_flexible:
        _advance_flexible(fm, sender, msg_count)
    else:
        _advance_turn(fm, msg_count)

    # Check if conversation should close: scan only current round's messages
    text = path.read_text()
    order = fm['turn_order']
    round_start = fm.get('round_start_msg', 0)

    # Find END/PASS messages only from current round (index > round_start)
    end_pass_agents = set()
    for m in re.finditer(r'^## \[(\d+)\] (\w+) — .+? \[(END|PASS)\]', text, re.MULTILINE):
        if int(m.group(1)) > round_start:
            end_pass_agents.add(m.group(2).lower())

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

    is_flexible = fm.get('conversation_mode') == 'flexible'
    result = {
        'conversation': title,
        'mode': fm.get('conversation_mode', 'ordered'),
        'status': fm.get('status', 'active'),
        'round': fm['round'],
        'turn_order': fm['turn_order'],
        'participants': fm['participants'],
        'read_cursors': fm['read_cursors'],
        'total_messages': msg_count,
    }
    if is_flexible:
        result['suggested_next'] = fm['current_turn']
        result['spoken_this_round'] = fm.get('spoken_this_round', [])
    else:
        result['current_turn'] = fm['current_turn']
    return result


@mcp.tool()
async def escalate_conversation(
    title: str,
    sender: str,
    reason: str,
) -> dict[str, Any]:
    """Escalate a turn-based conversation. Pauses the conversation and notifies Evelynn.

    In ordered mode, only the current_turn agent can escalate.
    In flexible mode, any participant can escalate.

    Args:
        title: Conversation title
        sender: Agent escalating (must be current_turn in ordered mode, any participant in flexible)
        reason: Reason for escalation
    """
    path = _turn_conversation_path(title)
    if not path.exists():
        raise ToolError(f"Turn conversation '{title}' not found.")

    sender = sender.lower().strip()
    fm = _parse_turn_frontmatter(path)
    is_flexible = fm.get('conversation_mode') == 'flexible'

    if fm.get('status') == 'ended':
        raise ToolError(f"Conversation '{title}' has ended.")
    if fm.get('status') == 'escalated':
        raise ToolError(f"Conversation '{title}' is already escalated.")

    if is_flexible:
        allowed = set(fm.get('participants', []) + fm.get('turn_order', []))
        if fm.get('started_by'):
            allowed.add(fm['started_by'])
        if sender not in allowed:
            raise ToolError(f'{sender} is not a participant in this conversation.')
    else:
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

    # Sender must be in turn_order or be started_by
    if sender not in fm['turn_order'] and sender != fm.get('started_by'):
        raise ToolError(f'{sender.capitalize()} is not in turn_order and cannot invite.')

    # Agent must not already be in turn_order (but allow observer→participant upgrade)
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

    # Notify the new agent — auto-launch if not running
    try:
        slug = _slugify(title)
        is_flexible = fm.get('conversation_mode') == 'flexible'
        if is_flexible:
            invite_msg = f"You've been invited to conversation '{title}' (flexible mode — you can speak any time). Use read_new_messages(title={slug}, agent={agent}) to read the full history."
        else:
            invite_msg = f"You've been invited to conversation '{title}'. Use read_new_messages(title={slug}, agent={agent}) to read the full history, then wait for your turn."
        inbox_path = _write_inbox_message(
            sender='system',
            recipient=agent,
            message=invite_msg,
            priority='info',
            conversation=slug,
        )
        iterm_windows = _get_iterm_agent_windows()
        agent_running = False
        for w in iterm_windows:
            if w['name'].lower() == agent:
                _send_to_iterm_window(w['window_id'], f'[inbox] {inbox_path}')
                agent_running = True
                break
        if not agent_running:
            # Auto-launch the agent so they can pick up the invite
            await launch_agent(agent, task=f'[inbox] {inbox_path}')
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


if __name__ == '__main__':
    log.info('Starting Agent Manager MCP in stdio mode')
    mcp.run(transport='stdio')
