# Agent-Setup — how I run Claude Code

My portable Claude Code setup: plugins, skills, hooks, output style, folder
conventions, and the day-to-day working loop. Clone it on a new laptop, follow
[`SETUP.md`](SETUP.md), and you get the same agent I work with.

This README is the **explanation** — what each piece is and why it's there.
`SETUP.md` is the **install procedure**.

---

## 1. The mental model: two layers

| Layer | Installed | Lives in | Answers |
|-------|-----------|----------|---------|
| **Global** ([`global/`](global/)) | once per laptop | `~/.claude/` | *How I work everywhere* — model, plugins, code standard, working model |
| **Per-project** ([`project-template/`](project-template/)) | once per project | `<project>/.claude/` | *What this project is* — its docs, specs, rules, hooks |

Global is the base class; each project's `.claude/` is a subclass. Almost every
"where does this go?" question is really "which layer?".

Precedence, highest wins: **project `CLAUDE.md`** › **global `CLAUDE.md`** ›
**skills** › default behaviour. Output style outranks CLAUDE.md prose — if a
style says "be terse" and CLAUDE.md says "explain fully", terse wins.

---

## 2. Plugins I actually run

Installed from marketplaces declared in `global/settings.json`. `enabledPlugins`
is the on/off switch — installed-but-`false` means it's on disk, dormant.

### On

| Plugin | Marketplace | What it buys me |
|--------|-------------|-----------------|
| **superpowers** | `claude-plugins-official` | The process layer. Skills for brainstorming, writing-plans, TDD, systematic-debugging, code-review. It forces a skill check *before* the first action — so "fix this bug" starts with systematic-debugging, not with a guess. The single highest-leverage plugin here. |
| **ponytail** | `ponytail` ([DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)) | The anti-over-engineering layer. Injects a "lazy senior dev" persona with a ladder: *does this need to exist → is it already in the codebase → stdlib → native platform → installed dep → one line → minimum code*. Stop at the first rung that holds. Counterweights my own instinct to abstract early. `/ponytail lite\|full\|ultra`. |
| **context7** | `claude-plugins-official` | Live, current library docs (Django, DRF, Angular) via MCP. Kills the "trained-on-2023-Django" hallucinations. |
| **playwright** | `claude-plugins-official` | Real browser via MCP — click through the Angular wizard, screenshot, read console errors. |
| **claude-hud** | `claude-hud` ([jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud)) | Status line: context usage, model, cost, session time. Wired via the `statusLine` command in settings.json. |
| **mattpocock-skills** | `mattpocock` ([mattpocock/skills](https://github.com/mattpocock/skills)) | Engineering skills — issue tracker, triage labels, domain docs, ADRs. This is the backbone of my issue workflow (§5). |

### Installed, off

`frontend-design`, `feature-dev`, `claude-md-management`, `code-review`,
`plugin-dev`, `skill-creator`, `sourcegraph`. Flip on per project when the work
calls for it. Off by default because every enabled plugin costs context on every
turn.

### Deliberately dropped

- **claude-teacher** — a tutor plugin that injected "NEVER WRITE CODE, quiz me"
  on *every* prompt. Great for learning a codebase, unusable for shipping. Removed
  along with its `/teacher-mode` toggle skill.
- **drawio MCP** and the mermaid pipeline — overkill. Excalidraw MCP covers
  diagrams; see §6.

---

## 3. MCP servers

| Server | Configured in | Why |
|--------|---------------|-----|
| **codegraph** | `~/.claude.json` (global) | A SQLite knowledge graph of the repo. One `codegraph_explore` call returns the verbatim source of the relevant symbols **plus the call paths between them** — including dynamic-dispatch hops grep can't follow. Replaces a grep+Read loop with one round-trip. Also wired as a `UserPromptSubmit` hook (`codegraph prompt-hook`) so relevant symbols get pre-loaded. **Gotcha:** no file watcher — run `codegraph sync` after edits or you get stale symbols. |
| **context7** | the context7 plugin | current library docs |
| **playwright** | the playwright plugin | drive a real browser |
| **Excalidraw** | claude.ai-hosted, connect in-app | draw diagrams in-panel |

CodeGraph is opt-in per repo: a `.codegraph/` directory at the repo root means
it's indexed. No directory → the global `CLAUDE.md` tells Claude to skip it
entirely. Indexing is my decision, not the agent's.

---

## 4. Skills, hooks, output style

### Global skills ([`global/skills/`](global/skills/))

| Skill | Does |
|-------|------|
| `class-diagram` | pyreverse → mermaid `.md` (renders inline in GitLab MRs) or editable `.drawio`. Deterministic, no hand-drawing, minimal tokens. |
| `create-worktree` | scaffolds a new git worktree in my umbrella layout (§5) |
| `find-skills` | searches installed skills when I can't remember the name |

### Hooks — where the rules get *enforced*

CLAUDE.md is a suggestion the model can drift from. A hook is code. These live in
[`project-template/hooks/`](project-template/hooks/) as working examples (they're
from a Django/uv project — adapt the paths):

| Hook | Event | Does |
|------|-------|------|
| `inject_style_contract.py` | `PreToolUse` on Write\|Edit | Injects the matching style contract (`code-style-prompt.md` / `test-style-prompt.md`) before *any* file edit. The hard gate — the model can't "forget" the house style. |
| `check_new_imports.py` | `PreToolUse` on Write\|Edit | Asks before a new third-party import lands. Stops silent dependency creep. |
| `lint_on_save.py` | `PostToolUse` on Write\|Edit | Runs ruff format + `--fix`, feeds failures back as feedback so the model self-corrects. |
| `check_commit.py` | `PreToolUse` on Bash(git commit) | Gate: ruff + mypy + pylint must pass. **Judge pylint by exit code, not score** — 4 = `# TODO:` fixme, 8 = R6103 walrus, 16 = convention. |
| `cmthub.py` | — | Shared helper. Hooks run with `cwd` = project root, which has no `pyproject.toml`; everything routes through its `uv()` wrapper (`--project` + `cwd`=worktree) or `uv` picks the wrong environment. |

### Output style ([`global/output-styles/concise.md`](global/output-styles/concise.md))

`concise` — lead with the outcome, fragments over sentences, code in fenced
blocks, prose out of them. The one exception: a walkthrough I explicitly asked
for gets full length.

Style beats CLAUDE.md prose, so this is the real control on verbosity.

### Permissions

`ask` on the destructive set — `git push`, `git reset --hard`, `git clean`,
`rm -rf`, `manage.py flush`. Everything else runs. I review locally and push
myself; the agent never pushes.

---

## 5. The workflow

### Project layout — umbrella + worktrees

A project isn't one repo folder. It's an umbrella directory holding several
worktrees, a sandbox, and one shared `.claude/`:

```
<Project>/                    ← umbrella (NOT a git repo)
├── main/                     ← worktree: primary branch
├── <feature-a>/              ← worktree
├── <feature-b>/              ← worktree
├── sandbox/                  ← scratch.ipynb, own .venv, throwaway probes
└── .claude/                  ← shared across every worktree
```

**Why worktrees:** several branches checked out at once, compare behaviour side by
side, no stash-dance.
**Why `.claude/` outside them:** notes and specs are shared, not duplicated per
branch — and never committed into a worktree. Worktrees get **no `CLAUDE.md`**;
context primers live in `.claude/docs/` and are pointer-referenced from the
umbrella `CLAUDE.md`.
**Why a sandbox:** prototypes go in `sandbox/scratch.ipynb`, never as throwaway
scripts in a repo root.

### Folder taxonomy — memorize this

| Folder | Holds | The test |
|--------|-------|----------|
| `docs/` | teachings, code explanations, context primers | "something I *learned* about how the code works" |
| `issues/` | issue notes (Obsidian board) | "a thing that's wrong or wanted, not yet specified" |
| `mrs/<mr>/` | `spec.md`, `plan.md`, `diagrams/` | "a deliverable for a specific change" |
| `mrs/archive/` | superseded MRs, abandoned approaches | "a decision we reversed — keep the paper trail" |
| `reference/` | this project's standards, conventions, tooling | "*how we work here* (rules)" |
| `reference/prompts/` | the hard-gate style contracts | "text a hook injects before an edit" |
| `hooks/` | the enforcement scripts | "code that runs on a tool event" |
| `tools/` | project-specific scripts | "code that only runs inside this project" |

**Guiding rule: delete facts, archive decisions.** Noise → `rm`. A reversed
decision → `mrs/archive/`, because it's the answer when someone asks "why didn't
you do X?".

Cite code as `file.py::symbol`, **never** line numbers — they rot.

### The loop: capture → triage → promote → spec → plan → build → push

1. **Capture.** Every issue starts as a note in `.claude/issues/`, opened as an
   Obsidian board. Cheap to write, zero ceremony, no tracker round-trip.
2. **Triage.** `status:` frontmatter holds one of five roles — `needs-triage`,
   `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Vault-local, not
   remote labels.
3. **Promote.** Only a fully-specified `ready-for-*` note reaches the real tracker
   (GitLab/GitHub), via a skill. Most notes never graduate — that's the point.
4. **Spec.** `.claude/mrs/<mr>/spec.md`. I write the intent; the agent writes the
   code.
5. **Plan → shape first.** For code, the plan is **class + method signatures with
   one-line docstrings, and which file each lives in**. Bodies only after my go.
   Signatures are where design errors are cheap to catch.
6. **Build.** Agent writes it. Hooks enforce style, imports, lint. Then it walks me
   through: **what / why / which pattern / what breaks** — so I can defend every
   line in review.
7. **Push.** I review locally and push. The agent never pushes and never adds
   itself as co-author.

### Division of labour

I work at the **strategy + operational** level: goals, architecture,
decomposition, the spec. The agent is **tactical** — it writes the code. Building
the loop *is* the skill; if the output is wrong, the fix is usually the spec, not
the code.

Design bias: cohesive, intent-named **classes** over loose functions — a class
name is a promise about what's inside. Deep modules, narrow interfaces. Kill
abstractions nothing branches on. Full rubric in
[`global/reference/`](global/reference/).

Readability rule that overrides everything: **human first, machine second.** Code
reads like a sentence. Unroll packed expressions (nested comprehensions,
walrus-in-filter, wrapped ternaries) into loops with named locals. Fewer lines is
never the goal.

---

## 6. Diagrams

I rubber-stamp prose specs and spot flaws in pictures, so design review happens on
a canvas.

- **Excalidraw MCP** — the agent draws in-panel; I rethink the design there.
- **Obsidian Excalidraw plugin** — I edit the same files by hand in the vault.
- **`class-diagram` skill** — pyreverse, for locking in a structure that already exists.

Rule: **Excalidraw to rethink a design, generated diagrams to lock it.** Don't
draw every turn — draw at review checkpoints.

---

## 7. What's in this repo

```
.
├── README.md                  ← this file (the why)
├── SETUP.md                   ← install procedure (the how)
├── global/                    → copy to ~/.claude/
│   ├── CLAUDE.md              universal working prefs
│   ├── settings.json          model, plugins, marketplaces, hooks, statusline
│   ├── output-styles/         concise.md
│   ├── reference/             clean-code + OOP rubrics
│   └── skills/                class-diagram, create-worktree, find-skills
└── project-template/          → copy to <project>/.claude/
    ├── CLAUDE.md              fill-in-the-blanks project brief
    ├── settings.json          output style + destructive-action prompts
    ├── settings-hooks.md      copy-paste hook wiring
    ├── hooks/                 working hook examples
    ├── reference/prompts/     the style contracts hooks inject
    └── docs/ issues/ mrs/ tools/
```
