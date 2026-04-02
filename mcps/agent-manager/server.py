"""
Agent Manager MCP Server
=========================
Manages agents: list, look up, create, delete, launch, and restart.

Environment Variables:
  Required:
    WORKSPACE_PATH       — path to workspace root
    AGENTS_PATH          — path to agents/ root (contains agent folders)
    ITERM_PROFILES_PATH  — path to iTerm2 DynamicProfiles/agents.json
"""
import asyncio
import json
import logging
import os
import re
import shutil
import subprocess
import textwrap
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('agent-manager')

WORKSPACE = os.environ.get('WORKSPACE_PATH', '')
AGENTS_DIR = os.environ.get('AGENTS_PATH', '')
ITERM_PROFILES = os.environ.get('ITERM_PROFILES_PATH', '')

mcp = FastMCP('agent-manager')


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


@mcp.tool()
async def delete_agent(name: str) -> dict:
    """Delete an agent and its iTerm2 profile.

    Removes the agent directory and its iTerm2 dynamic profile entry.
    """
    agent_dir = _find_agent(name)
    shutil.rmtree(agent_dir)
    iterm_result = _remove_iterm_profile(name.lower().strip())
    return {
        'deleted': name,
        'iterm_profile': iterm_result,
        'note': 'Update routing tables in CLAUDE.md if needed.',
    }


# ── inbox ────────────────────────────────────────────────────────────────

def _inbox_dir(agent_name: str) -> Path:
    """Get (and ensure) the inbox directory for an agent."""
    agent_dir = _find_agent(agent_name)
    d = agent_dir / 'inbox'
    d.mkdir(exist_ok=True)
    return d


def _inbox_queue_dir() -> Path:
    """Central queue for action-priority messages awaiting Duong's approval."""
    d = _agents_root() / 'inbox-queue'
    d.mkdir(exist_ok=True)
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

def _log_message(sender: str, recipient: str, message: str, conversation: Optional[str] = None):
    convos = _conversations_dir()
    is_new = False
    if conversation:
        path = convos / f'{_slugify(conversation)}.md'
        if not path.exists():
            is_new = True
            with open(path, 'w') as f:
                f.write(f'---\ntitle: {conversation}\nparticipants: {sender.lower()}, {recipient.lower()}\ncreated: {_timestamp()}\n---\n')
    else:
        pair = sorted([sender.lower(), recipient.lower()])
        path = convos / f'{pair[0]}-{pair[1]}.md'
        if not path.exists():
            is_new = True
            with open(path, 'w') as f:
                f.write(f'---\ntitle: {pair[0]} & {pair[1]}\nparticipants: {pair[0]}, {pair[1]}\ncreated: {_timestamp()}\n---\n')
    _append_message(path, sender, message)
    if is_new:
        subprocess.Popen(['open', str(path)])


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

    # Log the message in conversations if sender provided
    if sender:
        _log_message(sender, recipient, message, conversation)

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
                    if isinstance(content, str):
                        match = re.match(r'Hey\s+(\w+)', content, re.IGNORECASE)
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
        ended.append(w['name'])
        await asyncio.sleep(1)

    return {
        'ended': ended,
        'skipped': skipped,
        'message': f'Sent end-session instructions to {len(ended)} agent(s).',
    }


# ── conversations ────────────────────────────────────────────────────────

def _conversations_dir() -> Path:
    if not AGENTS_DIR:
        raise ToolError('AGENTS_PATH not configured.')
    d = Path(AGENTS_DIR) / 'conversations'
    d.mkdir(exist_ok=True)
    return d


def _slugify(title: str) -> str:
    slug = re.sub(r'[^\w\s-]', '', title.lower().strip())
    slug = re.sub(r'[\s_]+', '-', slug)
    return slug[:80].strip('-')


def _conversation_path(title: str) -> Path:
    return _conversations_dir() / f'{_slugify(title)}.md'


def _timestamp() -> str:
    return datetime.now().strftime('%Y-%m-%d %H:%M')


def _append_message(path: Path, sender: str, message: str):
    with open(path, 'a') as f:
        f.write(f'\n## {sender.capitalize()} — {_timestamp()}\n{message}\n')


def _read_participants(path: Path) -> list[str]:
    try:
        text = path.read_text()
        match = re.search(r'^participants:\s*(.+)$', text, re.MULTILINE)
        if match:
            return [p.strip().lower() for p in match.group(1).split(',')]
    except OSError:
        pass
    return []


async def _ping_agents(participants: list[str], sender: str, title: str, message: str):
    """Ping conversation participants via inbox system."""
    iterm_windows = _get_iterm_agent_windows()
    window_map = {w['name'].lower(): w['window_id'] for w in iterm_windows}

    reply_hint = f'Reply with message_in_conversation(title={_slugify(title)}, sender=<your name>, message=<your reply>). Only use read_conversation if you need older context.'
    ping_message = f'[Conversation: {title}] {sender.capitalize()} says: {message} — {reply_hint}'

    for name in participants:
        if name.lower() == sender.lower():
            continue

        # Write inbox file with conversation context
        try:
            inbox_path = _write_inbox_message(
                sender=sender,
                recipient=name.lower(),
                message=ping_message,
                priority='info',
                conversation=_slugify(title),
                context=f'{sender.capitalize()} posted in "{title}"',
            )

            # Deliver pointer if agent has an iTerm window
            wid = window_map.get(name.lower())
            if wid:
                _send_to_iterm_window(wid, f'[inbox] {inbox_path}')
        except ToolError:
            # Agent not found — skip silently
            pass


@mcp.tool()
async def start_conversation(
    title: str,
    sender: str,
    participants: list[str],
    message: str,
) -> dict[str, str]:
    """Start a new multi-agent conversation.

    Creates a conversation file and pings all participants.

    Args:
        title: Conversation title (used as identifier)
        sender: Who is starting the conversation
        participants: List of agent names to include
        message: Opening message
    """
    path = _conversation_path(title)
    if path.exists():
        raise ToolError(f"Conversation '{title}' already exists. Use message_in_conversation to continue it.")

    participant_str = ', '.join(p.lower() for p in participants)
    with open(path, 'w') as f:
        f.write(f'---\ntitle: {title}\nparticipants: {participant_str}\ncreated: {_timestamp()}\n---\n')

    _append_message(path, sender, message)
    subprocess.Popen(['open', str(path)])

    await _ping_agents([p.lower() for p in participants], sender, title, message)

    return {
        'conversation': title,
        'file': str(path),
        'participants': participant_str,
        'status': 'started',
    }


@mcp.tool()
async def message_in_conversation(
    title: str,
    sender: str,
    message: str,
) -> dict[str, str]:
    """Reply to an existing conversation.

    Appends the message and pings other participants.

    Args:
        title: Conversation title
        sender: Who is replying
        message: Reply message
    """
    path = _conversation_path(title)
    if not path.exists():
        raise ToolError(f"Conversation '{title}' not found. Use start_conversation first.")

    _append_message(path, sender, message)

    participants = _read_participants(path)
    await _ping_agents(participants, sender, title, message)

    return {
        'conversation': title,
        'file': str(path),
        'sender': sender,
        'status': 'replied',
    }


@mcp.tool()
async def read_conversation(title: str) -> dict[str, str]:
    """Read the full content of a conversation.

    Args:
        title: Conversation title
    """
    path = _conversation_path(title)
    if not path.exists():
        raise ToolError(f"Conversation '{title}' not found.")
    return {
        'title': title,
        'file': str(path),
        'content': path.read_text(),
    }


@mcp.tool()
async def list_conversations() -> list[dict[str, str]]:
    """List all conversations, most recently modified first."""
    convos_dir = _conversations_dir()
    results = []
    for f in sorted(convos_dir.glob('*.md'), key=lambda p: p.stat().st_mtime, reverse=True):
        participants = _read_participants(f)
        results.append({
            'title': f.stem,
            'participants': ', '.join(participants),
            'last_modified': datetime.fromtimestamp(f.stat().st_mtime).strftime('%Y-%m-%d %H:%M'),
            'file': str(f),
        })
    return results


if __name__ == '__main__':
    log.info('Starting Agent Manager MCP in stdio mode')
    mcp.run(transport='stdio')
