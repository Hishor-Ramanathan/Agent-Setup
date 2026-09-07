"""
PreToolUse hook on Bash: a `git commit` goes through only when the subject
line is conventional, no AI trailer rides along, and the staged python passes
ruff, mypy and pylint, the same gates CI runs on the whole tree.
"""

import re
import subprocess
from pathlib import Path

from hooks_common import hook_input, respond, uv

# a commit at the start of a shell segment; a quoted mention elsewhere is not one
COMMIT_RE = re.compile(r"(?:^|&&|\|\||;)\s*git\s+(?:-C\s+\S+\s+)?commit\b")
SUBJECT_RE = re.compile(
    r"^(feat|fix|refactor|test|docs|chore|perf|ci|build|style)(\([\w./-]+\))?!?: \S"
)
# ponytail: the three spellings Claude uses; `git commit -F` is not one of them
MESSAGE_RE = re.compile(
    r"-m\s+(?:\"\$\(cat\s+<<'?EOF'?\n(.*?)\nEOF|\"(.*?)\"|'(.*?)')", re.DOTALL
)
NOT_AN_AUTHOR = ("co-authored-by", "generated with", "claude")
PYLINT_ENV = {"DJANGO_SETTINGS_MODULE": "<project>.settings.prod"}


def repo_root(command: str, cwd: str) -> Path | None:
    """
    The git toplevel the commit targets, honouring `git -C <dir>` and a
    leading `cd <dir> &&`.
    """
    start = Path(cwd)
    if hop := re.search(r"git\s+-C\s+(\S+)", command) or re.match(
        r"\s*cd\s+(\S+)\s*&&", command
    ):
        start = start / hop.group(1)
    result = subprocess.run(
        ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    return Path(result.stdout.strip()) if result.returncode == 0 else None


def commit_message(command: str) -> str:
    """
    The text behind -m, whether quoted inline or fed through a heredoc.
    """
    if (found := MESSAGE_RE.search(command)) is None:
        return ""
    return next(group for group in found.groups() if group is not None)


def message_problems(message: str) -> list[str]:
    """
    Subject not conventional, or a trailer that is not Hishor.
    """
    subject = message.strip().splitlines()[0] if message.strip() else ""
    problems = []
    if not SUBJECT_RE.match(subject):
        problems.append(f"subject must read `type(scope): summary`, got {subject!r}")
    for phrase in NOT_AN_AUTHOR:
        if phrase in message.lower():
            problems.append(f"message mentions {phrase!r}; Hishor is the only author")
    return problems


def staged_python(root: Path) -> list[str]:
    """
    Python files added or modified in the index.
    """
    result = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "diff",
            "--cached",
            "--name-only",
            "--diff-filter=ACMR",
            "--",
            "*.py",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.split()


def gate_problems(root: Path, files: list[str]) -> list[str]:
    """
    Output of every CI gate that fails on the staged files.
    """
    checks: list[tuple[str, list[str], dict[str, str]]] = [
        ("ruff", ["ruff", "check", *files], {}),
        ("ruff format", ["ruff", "format", "--check", *files], {}),
        ("mypy", ["mypy", *files], {}),
    ]
    production = [f for f in files if "/tests/" not in f and "/migrations/" not in f]
    if production:
        checks.append(
            ("pylint", ["pylint", "--output-format=text", *production], PYLINT_ENV)
        )
    problems = []
    for name, args, env in checks:
        result = uv(root, *args, env=env)
        if result.returncode:
            problems.append(
                f"{name} exit {result.returncode}:\n{(result.stdout + result.stderr).strip()}"
            )
    return problems


def main() -> None:
    data = hook_input()
    command = data.get("tool_input", {}).get("command") or ""
    if not COMMIT_RE.search(command):
        return
    problems = message_problems(commit_message(command))
    if (root := repo_root(command, data.get("cwd", "."))) is None:
        problems.append("no git repository found for this command")
    elif files := staged_python(root):
        problems += gate_problems(root, files)
    if problems:
        respond(
            "PreToolUse",
            permissionDecision="deny",
            permissionDecisionReason="commit blocked:\n\n" + "\n\n".join(problems),
        )


if __name__ == "__main__":
    main()
