"""
PreToolUse hook: the first edit of cmthub code (or of a test) in a session
loads the matching style contract into context, so the gate no longer
depends on remembering to read it. `--reset` forgets the session's markers,
wired to PreCompact so the contract returns after a compaction.
"""

import sys
import tempfile
from pathlib import Path

from cmthub import hook_input, respond, worktree_root

PROMPTS = Path(__file__).resolve().parents[1] / "reference" / "prompts"


def contract(kind: str) -> str:
    """
    The paste-ready block of the code contract, or the whole test contract.
    """
    if kind == "test":
        return (PROMPTS / "test-style-prompt.md").read_text(encoding="utf-8")
    text = (PROMPTS / "code-style-prompt.md").read_text(encoding="utf-8")
    return text.split("````")[1]


def marker(session_id: str, kind: str) -> Path:
    """
    The per-session file whose existence means the contract was already loaded.
    """
    return Path(tempfile.gettempdir()) / f"claude-style-{session_id}-{kind}"


def main() -> None:
    data = hook_input()
    session_id = data.get("session_id", "")
    if "--reset" in sys.argv:
        for kind in ("code", "test"):
            marker(session_id, kind).unlink(missing_ok=True)
        return

    path = (data.get("tool_input", {}).get("file_path") or "").replace("\\", "/")
    if not path.endswith(".py") or worktree_root(path) is None:
        return
    kind = "test" if "/tests/" in path else "code"
    if (seen := marker(session_id, kind)).exists():
        return
    seen.touch()
    respond(
        "PreToolUse",
        additionalContext=(
            f"STYLE GATE ({kind}), loaded once per session. Every edit below must satisfy it:\n"
            + contract(kind)
        ),
    )


if __name__ == "__main__":
    main()
