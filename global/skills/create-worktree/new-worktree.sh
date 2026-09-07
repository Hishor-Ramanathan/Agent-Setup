#!/usr/bin/env bash
# Create (or repair) a git worktree that shares the source worktree's local config:
#   .env        -> copied  (dev scripts; each worktree gets its own)
#   .claude     -> junction back to source (shared skills/settings)
#   .codegraph  -> fresh per-worktree index (so the graph reflects THIS branch's code)
#
# Usage: new-worktree.sh <branch> [worktree-dir]
#   branch        new or existing branch to check out
#   worktree-dir  optional; defaults to a sibling of the source named after the branch leaf
#
# Idempotent: re-running on an existing worktree only fills in missing config.
set -euo pipefail

BRANCH="${1:?Usage: new-worktree.sh <branch> [worktree-dir]}"
DIR="${2:-}"

SRC="$(git rev-parse --show-toplevel)"
[[ -z "$DIR" ]] && DIR="$(dirname "$SRC")/${BRANCH##*/}"

# --- worktree ---
if [[ -d "$DIR/.git" || -f "$DIR/.git" ]]; then
  echo "worktree exists, repairing config only: $DIR"
elif git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git worktree add "$DIR" "$BRANCH"
else
  git worktree add -b "$BRANCH" "$DIR"
fi

# --- .env: real copy ---
# ponytail: full copy of the .env dir. Ceiling: if a script inside hardcodes the
# source path, the copy still targets the source. Edit paths there if that bites.
if [[ -e "$SRC/.env" && ! -e "$DIR/.env" ]]; then
  cp -r "$SRC/.env" "$DIR/.env"
  echo "copied .env"
fi

# --- .claude: junction to source (shared skills/settings) ---
link() { # $1 link, $2 target
  MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$1")" "$(cygpath -w "$2")"
}
if [[ -e "$SRC/.claude" && ! -e "$DIR/.claude" ]]; then
  link "$DIR/.claude" "$SRC/.claude" && echo "junctioned .claude"
fi

# --- .codegraph: fresh index for THIS branch (not shared) ---
if command -v codegraph >/dev/null 2>&1 && [[ ! -e "$DIR/.codegraph" ]]; then
  codegraph init "$DIR" && echo "indexed .codegraph"
fi

echo "done: $DIR (branch $BRANCH)"
