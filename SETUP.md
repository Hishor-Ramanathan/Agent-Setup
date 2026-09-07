# SETUP — reproduce this setup on a new machine

The *why* is in [`README.md`](README.md). This is the procedure.

---

## Prerequisites

| Tool | Why |
|------|-----|
| **Claude Code** (CLI) | the harness everything plugs into |
| **git** | worktrees are core to the project layout |
| **Python + [uv](https://docs.astral.sh/uv/)** | per-project `.venv`, and the hooks shell out to `uv` |
| **Node.js** | playwright + claude-hud need it |
| **[Obsidian](https://obsidian.md/)** | I open each project's `.claude/` as a vault |
| **CodeGraph** | code knowledge-graph CLI + MCP (optional, leaned on heavily) |

---

## Step 1 — Global (`~/.claude/`, once per laptop)

```bash
cp global/CLAUDE.md          ~/.claude/CLAUDE.md
cp -r global/reference       ~/.claude/reference
cp -r global/skills/*        ~/.claude/skills/
cp -r global/output-styles/* ~/.claude/output-styles/
```

Then **merge** `global/settings.json` into `~/.claude/settings.json` (don't
overwrite — yours may hold auth/remote state). The blocks that matter:

- `enabledPlugins` + `extraKnownMarketplaces` — Claude Code installs these on restart.
- `hooks.UserPromptSubmit` → `codegraph prompt-hook`. Drop it if you don't use CodeGraph.
- `statusLine` — the claude-hud command. Drop the block if you skip claude-hud (it errors without it).
- `model: opus[1m]`, `effortLevel: high`, `theme: dark`.

**Restart Claude Code.** Verify with `/plugin` and `/status`.

Machine-specific things deliberately **not** in this repo: MCP server config
(`~/.claude.json` — add codegraph and any hosted servers in-app), auth state, the
`remote.defaultEnvironmentId`, and `statusline-context.py` if you use a custom one.

### Set the output style

`/output-style concise` — or per project via `outputStyle` in the project
`settings.json`.

---

## Step 2 — Per project

```
<Project>/                    ← umbrella, NOT a git repo
├── main/                     ← git worktree
├── <feature>/                ← git worktree
├── sandbox/                  ← scratch.ipynb + own .venv
└── .claude/                  ← project-template/ goes here
```

1. `mkdir <Project>`, then add worktrees (`git worktree add …`) and `sandbox/`.
2. `cp -r project-template <Project>/.claude`
3. Fill in every `<…>` in `<Project>/.claude/CLAUDE.md`.
4. Wire the hooks you want — see [`project-template/settings-hooks.md`](project-template/settings-hooks.md).
   Fix the absolute paths in the hook commands to match the project.
5. Adapt `reference/prompts/*.md` to the project's stack. These get injected
   verbatim before every edit, so they must be *right*, not generic.
6. Open `<Project>/.claude/` as an Obsidian vault. Community plugins:
   `obsidian-excalidraw-plugin`, `mermaid-view`, `ctrl-scroll-zoom`.

**Never put a `CLAUDE.md` inside a worktree.** Context primers go in
`.claude/docs/` and are pointer-referenced from the umbrella `CLAUDE.md`, so
they're shared across branches instead of drifting per-branch.

---

## Step 3 — Sanity check

| Check | Expect |
|-------|--------|
| `/plugin` | superpowers, ponytail, context7, playwright, claude-hud, mattpocock-skills enabled |
| `/status` | model `opus[1m]`, style `concise` |
| status line | context %, cost, model (claude-hud) |
| ask Claude to edit a file | the style contract shows up in its context (hook fired) |
| `codegraph explore "<a symbol>"` | source + call paths |

---

## Maintenance

- **This repo is the source of truth.** Change the setup here, then re-copy —
  don't edit `~/.claude/` and hope to remember.
- After a plugin update, re-check any hook that references a plugin path by
  version number.
- `codegraph sync` after edits — there's no file watcher, and a stale index
  silently returns wrong symbols.
