"""
PreToolUse hook: an Edit/Write on project python code that introduces an
import no tracked file of that worktree uses yet answers "ask", so Hishor
approves the new dependency before it lands.
"""

import re
import subprocess
from pathlib import Path

from hooks_common import hook_input, respond, worktree_root

IMPORT_RE = re.compile(r"^\s*(?:from|import)\s+([A-Za-z_][\w.]*)", re.MULTILINE)


def imported_modules(text: str) -> set[str]:
    """
    The top-level module of every import statement in the text.
    """
    return {name.split(".")[0] for name in IMPORT_RE.findall(text)}


def is_known(root: Path, module: str) -> bool:
    """
    Whether any tracked file in the worktree already imports the module.
    """
    result = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "grep",
            "-q",
            "-E",
            rf"^\s*(from|import)\s+{module}\b",
            "--",
            "*.py",
        ],
        capture_output=True,
        check=False,
    )
    return result.returncode == 0


def main() -> None:
    data = hook_input()
    tool_input = data.get("tool_input", {})
    path = tool_input.get("file_path") or ""
    if not path.endswith(".py") or (root := worktree_root(path)) is None:
        return

    text = tool_input.get("new_string") or tool_input.get("content") or ""
    unknown = sorted(
        module for module in imported_modules(text) if not is_known(root, module)
    )
    if not unknown:
        return

    respond(
        "PreToolUse",
        permissionDecision="ask",
        permissionDecisionReason=(
            "new import not used anywhere in this worktree yet: "
            + ", ".join(unknown)
            + " - Hishor approves new dependencies first"
        ),
    )


if __name__ == "__main__":
    main()
