#!/usr/bin/env bash
# Copy this machine's shared setup back into the repo, refuse if anything looks like a secret,
# then show what changed. Run from ~/Agent-Setup (Git Bash on Windows):
#   bash ~/Agent-Setup/sync.sh              # update the files the repo already has
#   bash ~/Agent-Setup/sync.sh my-skill     # also add ~/.claude/skills/my-skill
# Plugins: change enabledPlugins / extraKnownMarketplaces in global/settings.json by hand.
# Then commit on a branch and open a PR. The repo is public.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd); claude="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; g="$repo/global"

[ -f "$claude/CLAUDE.md" ] && cp "$claude/CLAUDE.md" "$g/CLAUDE.md"
for dir in reference output-styles skills; do
  for item in "$g/$dir"/*; do
    name=$(basename "$item")
    [ -e "$claude/$dir/$name" ] || continue
    rm -rf "$item"; cp -R "$claude/$dir/$name" "$g/$dir/$name"
  done
done
for skill in "$@"; do cp -R "$claude/skills/$skill" "$g/skills/"; done

# tokens, keys, private-key blocks, tailnet hostnames
pattern='sk-ant-[A-Za-z0-9_-]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}|[a-z0-9-]+\.ts\.net'
if git -C "$repo" grep -nIE --untracked "$pattern" -- . ':!sync.sh'; then
  echo "sync.sh: secret-looking text above. Remove it before committing." >&2; exit 1
fi
git -C "$repo" status --short
