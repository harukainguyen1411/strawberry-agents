"""
Evelynn MCP Server
==================
Evelynn-only tools: session management, agent state commits.

Sender enforcement is honor-system (MCP has no built-in caller identity).
The sender parameter is checked but any caller could pass sender="evelynn".
This server should only be registered in Evelynn's session for real enforcement.

Environment Variables:
  Required:
    WORKSPACE_PATH       — path to workspace root
    AGENTS_PATH          — path to agents/ root (contains agent folders)
    ITERM_PROFILES_PATH  — path to iTerm2 DynamicProfiles/agents.json
  Optional:
    OPS_PATH             — path for operational data (health registry).
                           Falls back to in-repo paths under AGENTS_PATH if not set.
    TELEGRAM_BOT_TOKEN   — Telegram bot token from @BotFather
    TELEGRAM_CHAT_ID     — Telegram chat ID for Duong
"""
import asyncio
import logging
import os
import sys
from datetime import datetime
from typing import Any, Optional

import httpx
from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError

# Add parent dir to path so we can import shared helpers
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from shared.helpers import (
    scan_agents, get_iterm_agent_windows, send_to_iterm_window,
    set_agent_status, git, find_agent_session, WORKSPACE, AGENTS_DIR,
)

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('evelynn')

mcp = FastMCP('evelynn')


def _enforce_evelynn(sender: str):
    """Honor-system sender check. See module docstring for limitations."""
    if sender.lower().strip() != 'evelynn':
        raise ToolError('Only Evelynn can invoke this tool.')


def _safe_stash_pop(warnings: list[str]):
    """Attempt git stash pop; append warning if it fails instead of silently losing work."""
    pop = git(['stash', 'pop'])
    if pop.returncode != 0:
        warnings.append(f'git stash pop failed: {pop.stderr.strip()}. Run "git stash pop" manually to recover your work.')


# ── tools ────────────────────────────────────────────────────────────────

@mcp.tool()
async def end_all_sessions(sender: str, exclude: Optional[list[str]] = None) -> dict[str, Any]:
    """End all running agent sessions. Restricted to Evelynn only (honor-system).

    Messages each agent with instructions to follow the session closing protocol
    (end_session tool, journal, handoff note, memory update, learnings).

    Args:
        sender: Agent invoking this tool (must be 'evelynn')
        exclude: Optional list of agent names to skip
    """
    _enforce_evelynn(sender)
    all_agents = scan_agents()
    agent_names = {a['name'] for a in all_agents}
    exclude_set = {n.lower() for n in (exclude or [])}

    iterm_windows = get_iterm_agent_windows()
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
        send_to_iterm_window(w['window_id'], end_message)
        set_agent_status(name_lower, 'offline')
        ended.append(w['name'])
        await asyncio.sleep(1)

    return {
        'ended': ended,
        'skipped': skipped,
        'message': f'Sent end-session instructions to {len(ended)} agent(s).',
    }


@mcp.tool()
async def commit_agent_state_to_main(sender: str) -> dict[str, Any]:
    """Commit all agent state files to main branch and push. Restricted to Evelynn only (honor-system).

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
    warnings: list[str] = []

    # Record current branch
    result = git(['branch', '--show-current'])
    if result.returncode != 0:
        raise ToolError(f'Failed to get current branch: {result.stderr.strip()}')
    original_branch = result.stdout.strip()
    on_main = original_branch == 'main'

    stashed = False

    try:
        # Stash if not on main and working tree is dirty
        if not on_main:
            dirty = git(['status', '--porcelain'])
            if dirty.stdout.strip():
                stash_result = git(['stash', '--include-untracked'])
                if stash_result.returncode != 0:
                    raise ToolError(f'Failed to stash: {stash_result.stderr.strip()}')
                stashed = True

            # Checkout main
            checkout = git(['checkout', 'main'])
            if checkout.returncode != 0:
                if stashed:
                    _safe_stash_pop(warnings)
                raise ToolError(f'Failed to checkout main: {checkout.stderr.strip()}')

        # Pull latest
        pull = git(['pull', 'origin', 'main'])
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
            add_result = git(['add', pattern])
            if add_result.returncode == 0:
                diff = git(['diff', '--cached', '--name-only', '--', pattern])
                if diff.stdout.strip():
                    staged_files.extend(diff.stdout.strip().splitlines())

        # Remove any inbox files that got staged
        git(['reset', 'HEAD', '--', f'{agents_rel}/*/inbox/'])

        # Check if anything is staged
        check = git(['diff', '--cached', '--name-only'])
        if not check.stdout.strip():
            if not on_main:
                git(['checkout', original_branch])
                if stashed:
                    _safe_stash_pop(warnings)
            result_dict: dict[str, Any] = {'status': 'no_changes', 'message': 'No agent state changes to commit.'}
            if warnings:
                result_dict['warnings'] = warnings
            return result_dict

        final_files = check.stdout.strip().splitlines()
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M')

        # Commit
        commit = git(['commit', '-m', f'chore: update agent state [{timestamp}]'])
        if commit.returncode != 0:
            git(['reset', 'HEAD'])
            if not on_main:
                git(['checkout', original_branch])
                if stashed:
                    _safe_stash_pop(warnings)
            raise ToolError(f'Failed to commit: {commit.stderr.strip()}')

        # Get commit hash
        hash_result = git(['rev-parse', '--short', 'HEAD'])
        commit_hash = hash_result.stdout.strip()

        # Push
        push = git(['push', 'origin', 'main'])
        push_failed = push.returncode != 0
        push_error = push.stderr.strip() if push_failed else None

        # Restore original branch
        if not on_main:
            git(['checkout', original_branch])
            if stashed:
                _safe_stash_pop(warnings)

        result_dict = {
            'status': 'committed',
            'commit': commit_hash,
            'files': final_files,
            'files_count': len(final_files),
            'pushed': not push_failed,
        }
        if push_failed:
            result_dict['push_error'] = push_error
        if warnings:
            result_dict['warnings'] = warnings

        return result_dict

    except ToolError:
        raise
    except Exception as e:
        # Safety net: restore branch
        if not on_main:
            git(['checkout', original_branch])
            if stashed:
                _safe_stash_pop(warnings)
        error_msg = f'Unexpected error: {e}'
        if warnings:
            error_msg += f' | Warnings: {"; ".join(warnings)}'
        raise ToolError(error_msg)


@mcp.tool()
async def restart_evelynn(sender: str) -> dict[str, Any]:
    """Restart Evelynn's iTerm session. Any agent except Evelynn can call this.

    Finds Evelynn's iTerm window, sends /exit, waits, then resumes using
    the session ID from the JSONL transcript files.

    Args:
        sender: Agent invoking this tool (must NOT be 'evelynn')
    """
    if sender.lower().strip() == 'evelynn':
        raise ToolError('Evelynn cannot restart herself. Ask another agent.')

    # Find Evelynn's iTerm window
    iterm_windows = get_iterm_agent_windows()
    evelynn_window = None
    for w in iterm_windows:
        if w['name'].lower() == 'evelynn':
            evelynn_window = w
            break

    if not evelynn_window:
        raise ToolError('Evelynn iTerm window not found.')

    # Find session ID
    session_id = find_agent_session('evelynn')
    if not session_id:
        raise ToolError('Could not find Evelynn session ID in JSONL transcript files.')

    # Restart: /exit, wait for exit, resume
    wid = evelynn_window['window_id']
    short_id = session_id[:8]
    log.info(f'Restarting Evelynn (session {short_id}...)')
    send_to_iterm_window(wid, '/exit')

    # Wait for /exit to complete — poll window name for shell prompt
    # If still showing claude after 15s, proceed anyway (best effort)
    for _ in range(6):
        await asyncio.sleep(3)
        windows = get_iterm_agent_windows()
        still_running = any(
            w['window_id'] == wid and 'claude' in w.get('raw_name', '').lower()
            for w in windows
        )
        if not still_running:
            break

    send_to_iterm_window(wid, f'claude --resume {session_id}')

    # Notify Evelynn's inbox that restart completed
    try:
        from pathlib import Path as _P
        inbox_dir = _P(AGENTS_DIR) / 'evelynn' / 'inbox'
        inbox_dir.mkdir(parents=True, exist_ok=True)
        ts = datetime.now()
        filename = f'{ts.strftime("%Y%m%d-%H%M")}-system-info.md'
        (_P(inbox_dir) / filename).write_text(
            f'---\nfrom: system\nto: evelynn\npriority: info\n'
            f'timestamp: {ts.strftime("%Y-%m-%d %H:%M")}\nstatus: pending\n---\n\n'
            f'Restart complete. Restarted by {sender} (session {short_id}...).\n'
        )
    except Exception:
        pass  # Best effort — don't fail the restart over notification

    return {
        'status': 'restarted',
        'session_id': short_id,
        'message': f'Evelynn restarted (session {short_id}...)',
    }


# ── telegram ─────────────────────────────────────────────────────────────

TELEGRAM_BOT_TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN', '')
TELEGRAM_CHAT_ID = os.environ.get('TELEGRAM_CHAT_ID', '')
TELEGRAM_API_BASE = 'https://api.telegram.org/bot{token}'
_telegram_update_offset: int = 0  # tracks last processed update_id


@mcp.tool()
async def telegram_send_message(
    sender: str,
    message: str,
    parse_mode: Optional[str] = None,
) -> dict[str, Any]:
    """Send a message to Duong on Telegram. Restricted to Evelynn only (honor-system).

    Args:
        sender: Agent invoking this tool (must be 'evelynn')
        message: Text message to send
        parse_mode: Optional formatting — 'HTML' or 'Markdown'
    """
    _enforce_evelynn(sender)

    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        raise ToolError(
            'Telegram not configured. Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID env vars.'
        )

    payload: dict[str, Any] = {
        'chat_id': TELEGRAM_CHAT_ID,
        'text': message[:4096],  # Telegram message limit
    }
    if parse_mode in ('HTML', 'Markdown'):
        payload['parse_mode'] = parse_mode

    url = f'{TELEGRAM_API_BASE.format(token=TELEGRAM_BOT_TOKEN)}/sendMessage'
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(url, json=payload)

    if resp.status_code != 200:
        raise ToolError(f'Telegram API error ({resp.status_code}): {resp.text}')

    data = resp.json()
    return {
        'status': 'sent',
        'message_id': data.get('result', {}).get('message_id'),
    }


@mcp.tool()
async def telegram_poll_messages(sender: str) -> dict[str, Any]:
    """Poll Telegram for new messages from Duong. Restricted to Evelynn only (honor-system).

    Uses long polling (15s) with offset tracking to avoid duplicates.
    Returns any new messages received since the last poll.

    Args:
        sender: Agent invoking this tool (must be 'evelynn')
    """
    global _telegram_update_offset
    _enforce_evelynn(sender)

    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        raise ToolError(
            'Telegram not configured. Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID env vars.'
        )

    params: dict[str, Any] = {
        'timeout': 15,
        'allowed_updates': ['message'],
    }
    if _telegram_update_offset:
        params['offset'] = _telegram_update_offset

    url = f'{TELEGRAM_API_BASE.format(token=TELEGRAM_BOT_TOKEN)}/getUpdates'
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(url, params=params)

    if resp.status_code != 200:
        raise ToolError(f'Telegram API error ({resp.status_code}): {resp.text}')

    data = resp.json()
    if not data.get('ok'):
        raise ToolError(f'Telegram API returned error: {data}')

    updates = data.get('result', [])
    messages = []

    for update in updates:
        _telegram_update_offset = update['update_id'] + 1
        msg = update.get('message')
        if not msg:
            continue
        # Only include messages from Duong's chat
        if str(msg.get('chat', {}).get('id')) != TELEGRAM_CHAT_ID:
            continue
        messages.append({
            'message_id': msg.get('message_id'),
            'text': msg.get('text', ''),
            'date': msg.get('date'),
        })

    return {
        'status': 'ok',
        'messages': messages,
        'count': len(messages),
    }


# ── entry point ──────────────────────────────────────────────────────────

if __name__ == '__main__':
    mcp.run(transport='stdio')
