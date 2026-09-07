# Hook wiring

The hooks in [`hooks/`](hooks/) are working examples from a Django + uv project.
They aren't wired in `settings.json` because every command carries an **absolute
path** that differs per project. Paste the block below into a project's
`.claude/settings.json` and fix the paths.

Why hooks and not CLAUDE.md prose: prose is a suggestion the model can drift from
over a long session. A hook is code — it fires every time.

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        { "type": "command",
          "command": "python <PROJECT>/.claude/hooks/inject_style_contract.py",
          "timeout": 10,
          "statusMessage": "Style gate" },
        { "type": "command",
          "command": "python <PROJECT>/.claude/hooks/check_new_imports.py",
          "timeout": 30,
          "statusMessage": "Checking imports" }
      ]
    },
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command",
          "command": "python <PROJECT>/.claude/hooks/check_commit.py",
          "timeout": 300,
          "statusMessage": "Commit gate" }
      ]
    }
  ],
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        { "type": "command",
          "command": "python <PROJECT>/.claude/hooks/lint_on_save.py",
          "timeout": 60,
          "statusMessage": "Linting" }
      ]
    }
  ]
}
```

## What each one does

| Hook | Event | Behaviour |
|------|-------|-----------|
| `inject_style_contract.py` | `PreToolUse` Write\|Edit | Injects `reference/prompts/code-style-prompt.md` (or `test-style-prompt.md` for `test_*.py`) into context before the edit. The hard gate. |
| `check_new_imports.py` | `PreToolUse` Write\|Edit | Returns `ask` when the edit adds a third-party import that isn't already used in the project. Stops silent dependency creep. |
| `check_commit.py` | `PreToolUse` Bash | Matches `git commit`, runs the whole-tree lint/type/pylint gate, blocks on failure. **Judge pylint by exit code, not score** — 4 = fixme, 8 = R6103 walrus, 16 = convention. |
| `lint_on_save.py` | `PostToolUse` Write\|Edit | ruff format + `--fix`; failures come back as feedback so the model self-corrects. |
| `hooks_common.py` | — | Shared helper, not itself a hook. |

## The gotcha that will bite you

Hooks run with `cwd` = **project root**, which in the umbrella layout has no
`pyproject.toml`. A bare `uv run …` therefore resolves the wrong environment — or
none. Every subprocess call routes through `hooks_common.py::uv()`, which passes
`--project <worktree>` and sets `cwd`. Rename that module per project; keep the
wrapper.

## Adapting to another stack

Only `lint_on_save.py` and `check_commit.py` are Python-specific — swap ruff/mypy
for the equivalent (`eslint --fix`, `tsc --noEmit`, `gofmt`). The style-contract
and import hooks are language-agnostic; they only read the file path and the diff.
