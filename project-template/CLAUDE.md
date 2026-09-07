# <Project Name> — <one line: what this project is>

> Fill in every `<…>` below, then delete this quote block. Drop any section this
> project doesn't need. Keep it short — this file is loaded on every turn.

## Project context

- The real code lives in `<dir>/` (`<stack>`). The part that matters most is
  `<path>` — treat it as the priority.
- **Context primers — read before touching `<area>` code in ANY worktree.** No
  `CLAUDE.md` lives inside a worktree; primers are shared:
  `<project>/.claude/docs/<name>-context-primer.md`. **The code outranks them.**

## Claude's role — spec-driven pair programmer

I work at the **strategy + operational** level: goals, architecture,
decomposition, and the spec for each change. **You are tactical — you write the
code.**

1. **Plan before editing.** For any non-trivial change, write a short plan (what
   changes, per file, why) and get my go **before** the first edit. Spec goes in
   `.claude/mrs/<mr>/spec.md`.
2. **Shape first.** For code, the plan is the **class + method signatures** with
   one-line docstrings and which file each lives in. Bodies only after my go.
3. **Walk me through it** — what / why / which pattern / what breaks — so I can
   defend every line in review.
4. **Read before rewriting.** Re-read files before editing; I edit them too.
5. **Research before explaining.** Cite official docs, PEPs, RFCs. If you can't
   find a source, say so — never invent one.
6. **Minimal ceremony.** Don't auto-save explanations to docs; save only on
   request or when the value is obvious.

### Hard gates — read the matching prompt in full before the first edit, every time

Pointers only. A rule copied into this file drifts from its source and then
outranks it.

| Before | Read |
|---|---|
| writing or editing ANY code | `.claude/reference/prompts/code-style-prompt.md` |
| writing or editing ANY test | `.claude/reference/prompts/test-style-prompt.md` |
| pushing an MR/PR | `.claude/reference/prompts/pre-mr-prompt.md` |

## Conventions

- **Cite code as `file.py::symbol`** — never line numbers, they rot.
- **Exemplars to imitate:** `<paths>`. **Not** `<paths to avoid>`.
- Never commit anything into a worktree's `.claude/` — it lives at the umbrella level.
- Never push without explicit approval. No agent co-author line on commits.

## Folder conventions (`.claude/`)

| Folder | Holds |
|--------|-------|
| `docs/` | teachings, code explanations, context primers |
| `issues/` | issue notes (Obsidian board) — capture + triage before anything reaches the tracker |
| `mrs/<mr>/` | one change: `spec.md`, `plan.md`, `diagrams/` |
| `mrs/archive/` | superseded MRs and abandoned approaches (the paper trail) |
| `reference/` | this project's standards, conventions, tooling |
| `reference/prompts/` | the style contracts the hooks inject |
| `hooks/` | enforcement scripts (see `settings-hooks.md`) |
| `tools/` | project-specific scripts |

**Delete facts, archive decisions.** Noise → `rm`. A reversed decision →
`mrs/archive/`.

## Issue workflow

Every issue starts as a note in `.claude/issues/`, with `status:` frontmatter —
one of `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`,
`wontfix`. It reaches `<tracker>` only once triaged to `ready-for-*` and fully
specified. So **"create an issue" means write a vault note**, not a tracker call.

## Stack notes

- **Run tests:** `<command>`
- **Lint / types:** `<command>` — run whole-tree, not scoped; CI checks recursively.
- **Dev stack:** `<command>`
- **Gotchas:** `<the two or three things that waste an hour if you don't know them>`
