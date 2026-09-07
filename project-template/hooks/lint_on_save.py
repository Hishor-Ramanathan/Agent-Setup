"""
PostToolUse hook: formats the saved file, then hands back whatever ruff still
objects to under the repo config plus the house rules, so the fix happens
now and not in review.
"""

import os
import subprocess
from pathlib import Path

from hooks_common import hook_input, respond, uv, worktree_root

# each family backs a line of the style contract; families that fired on the
# exemplar apps (ARG, FBT, N, PLR2004, SLF) were left out on purpose
HOUSE_RULES = "BLE,ERA,FIX,RET,C901,PLR0911,PLR0912,PLR0915,PLR1714,TRY002,TRY201,PLW,PIE,A,ISC,RSE,T20"
TEST_RULES = "PT,BLE,ERA,FIX,PLW"
TEST_IGNORES = "PT006"  # house parametrize names are one comma string, not a tuple


def lint_python(root: Path, path: str) -> str:
    """
    Formats and autofixes, then returns the remaining violations as concise
    ruff lines, empty when clean.
    """
    uv(root, "ruff", "format", path)
    uv(root, "ruff", "check", "--fix", path)
    is_test = "/tests/" in path.replace("\\", "/")
    args = ["ruff", "check", "--output-format", "concise", "--extend-select"]
    args += [TEST_RULES, "--ignore", TEST_IGNORES] if is_test else [HOUSE_RULES]
    result = uv(root, *args, path)
    return "" if result.returncode == 0 else result.stdout.strip()


def format_frontend(root: Path, path: str) -> None:
    """
    Runs the worktree's own prettier on an Angular source file.
    """
    binary = "prettier.cmd" if os.name == "nt" else "prettier"
    prettier = root / "frontend" / "node_modules" / ".bin" / binary
    if prettier.exists():
        subprocess.run(
            [str(prettier), "--write", path], capture_output=True, check=False
        )


def main() -> None:
    data = hook_input()
    path = data.get("tool_input", {}).get("file_path") or ""
    root = worktree_root(path)
    if root is None:
        return
    if path.endswith((".ts", ".html", ".scss")) and "frontend" in path:
        format_frontend(root, path)
        return
    if not path.endswith(".py"):
        return
    if violations := lint_python(root, path):
        respond(
            "PostToolUse",
            additionalContext=(
                f"ruff (repo config + house rules) on {Path(path).name}:\n{violations}\n"
                "Fix these before moving on. A noqa needs Hishor's ok."
            ),
        )


if __name__ == "__main__":
    main()
