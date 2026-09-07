"""
Shared plumbing for the project hooks: reads the hook payload, finds the
worktree a file belongs to, runs tools through that worktree's uv env.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def hook_input() -> dict:
    """
    The JSON Claude Code pipes to every hook on stdin.
    """
    return json.load(sys.stdin)


def worktree_root(path: str) -> Path | None:
    """
    The nearest ancestor holding a pyproject.toml, or None for files outside
    any project worktree.
    """
    for parent in Path(path).resolve().parents:
        if (parent / "pyproject.toml").exists():
            return parent
    return None


def uv(
    root: Path, *args: str, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess:
    """
    Runs a tool inside the worktree's uv environment and directory, without
    syncing, so paths relative to the worktree resolve.
    """
    return subprocess.run(
        ["uv", "run", "--project", str(root), "--no-sync", *args],
        capture_output=True,
        text=True,
        check=False,
        cwd=root,
        env={**os.environ, **(env or {})},
    )


def respond(event: str, **fields: str) -> None:
    """
    Emits the hookSpecificOutput JSON Claude Code reads from stdout.
    """
    payload = {"hookSpecificOutput": {"hookEventName": event, **fields}}
    sys.stdout.write(json.dumps(payload) + "\n")
