# Style contracts

`inject_style_contract.py` injects the file in this folder that matches what's
being edited, before the edit happens:

| Editing | File it injects |
|---------|-----------------|
| any source file | `code-style-prompt.md` |
| a test file | `test-style-prompt.md` |

These are **project content, not template content** — they encode one codebase's
house voice, so they ship empty here. Write your own.

## What makes one work

- **Paste-ready contract, not advice.** A fenced block the model can follow
  literally. "Prefer clarity" does nothing; a `# NO` / `# YES` pair does.
- **Name the exemplars by path.** "Imitate `app/foo/`, never `app/legacy/`" beats
  any abstract description of the style.
- **List the enforced lint rules** and what each one is for, so the model writes
  code that passes the `PostToolUse` linter on the first try instead of ping-ponging.
- **Keep it one screen.** It's injected on every session; length is a running cost.
- **Say what the linter can't check** — naming, comment density, when to unroll a
  packed expression, which abstractions are banned.

Same for `test-style-prompt.md`: fixture conventions, what may be mocked, what
must be real, where test data comes from.

## Optional third contract

Add `pre-mr-prompt.md` for the pre-push checklist — the whole-tree lint/type
commands, environment setup, and the failure modes that waste an hour. Point
`CLAUDE.md` at it as a hard gate before pushing.
