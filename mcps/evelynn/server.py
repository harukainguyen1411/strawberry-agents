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
"""
import asyncio
import logging
import os
import sys
from datetime import datetime
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError

# Add parent dir to path so we can import shared helpers
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from shared.helpers import (
    scan_agents, get_iterm_agent_windows, send_to_iterm_window,
    set_agent_status, git, WORKSPACE, AGENTS_DIR,
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


# ── entry point ──────────────────────────────────────────────────────────

if __name__ == '__main__':
    mcp.run(transport='stdio')
