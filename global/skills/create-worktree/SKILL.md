---
name: create-worktree
description: Use when creating a new git worktree for this repo, or when a freshly-added worktree is missing its local config (.env, .claude, .codegraph) — sets up a worktree that copies .env, junctions .claude back to the source worktree, and builds a fresh per-branch .codegraph index.
---

# create-worktree

Local config (`.env`, `.claude`, `.codegraph`) is gitignored/untracked, so `git worktree add` never brings it along — a fresh worktree runs bare. This wires it up.

- **`.env`** → copied (each worktree gets its own dev scripts)
- **`.claude`** → Windows junction to the source worktree (shared skills/settings)
- **`.codegraph`** → fresh `codegraph init` (own index, reflects this branch's code)

## Usage

Run from the worktree that HAS the config (the source), giving the branch name:

```bash
bash ~/.claude/skills/create-worktree/new-worktree.sh <branch> [worktree-dir]
```

- `worktree-dir` defaults to a sibling folder named after the branch's last path segment
  (e.g. `feat/tds/multilanguage-support` → `../multilanguage-support`).
- New branch is created if it doesn't exist; existing branch is checked out.
- Idempotent — re-run on an existing worktree to fill in only the missing config.

## Notes

- Junctions (`mklink /J`) need no admin rights; symlinks would.
- Each worktree gets its OWN `.codegraph`, so the graph always matches that branch's
  code. Costs ~23MB + a one-time index per worktree; the daemon auto-syncs it after.
- Skipped if the `codegraph` CLI isn't on PATH — the worktree still works, just unindexed.
