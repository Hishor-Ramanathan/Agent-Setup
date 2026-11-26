#!/usr/bin/env bash
# Agent-Setup installer for Linux/macOS (needs git, python3). One command:
#   curl -fsSL https://raw.githubusercontent.com/Hishor-Ramanathan/Agent-Setup/main/install.sh | bash
# Same steps as install.ps1: clone/update ~/Agent-Setup, copy global/ into ~/.claude, merge
# global/settings.json into ~/.claude/settings.json (your other keys stay), install plugins. Re-runnable.
set -euo pipefail
repo="$HOME/Agent-Setup"; claude="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; src="$repo/global"
stamp=$(date +%Y%m%d-%H%M%S)

if [ -d "$repo/.git" ]; then git -C "$repo" pull --ff-only -q
else git clone -q https://github.com/Hishor-Ramanathan/Agent-Setup.git "$repo"; fi
mkdir -p "$claude"

if [ -f "$claude/CLAUDE.md" ] && ! cmp -s "$claude/CLAUDE.md" "$src/CLAUDE.md"; then
  cp "$claude/CLAUDE.md" "$claude/CLAUDE.md.bak-$stamp"
fi
cp "$src/CLAUDE.md" "$claude/CLAUDE.md"

for dir in reference skills output-styles; do
  mkdir -p "$claude/$dir"
  for item in "$src/$dir"/*; do
    rm -rf "$claude/$dir/$(basename "$item")"
    cp -R "$item" "$claude/$dir/"
  done
done

[ -f "$claude/settings.json" ] && cp "$claude/settings.json" "$claude/settings.json.bak-$stamp"
python3 - "$src/settings.json" "$claude/settings.json" <<'PY'
import json, os, shutil, sys
shared_path, local_path = sys.argv[1:]
shared = json.load(open(shared_path))
# leave out what this machine cannot run
if not shutil.which("codegraph"):
    shared.pop("hooks", None); print("skipped: CodeGraph hook (codegraph not installed)")
if not shutil.which("node"):
    shared.pop("statusLine", None); print("skipped: claude-hud status line (node not installed)")

def merge(base, over):  # repo wins on its own keys, dicts merge, lists are unioned
    for key, value in over.items():
        if isinstance(base.get(key), dict) and isinstance(value, dict):
            merge(base[key], value)
        elif isinstance(base.get(key), list) and isinstance(value, list):
            base[key] = base[key] + [v for v in value if v not in base[key]]
        else:
            base[key] = value
    return base

assert merge({"a": {"x": 1}, "l": [1]}, {"a": {"y": 2}, "l": [1, 2], "s": 3}) == {"a": {"x": 1, "y": 2}, "l": [1, 2], "s": 3}
local = json.load(open(local_path)) if os.path.exists(local_path) and os.path.getsize(local_path) else {}
json.dump(merge(local, shared), open(local_path, "w"), indent=2)
PY

plugins=$(python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print(*[r["source"]["repo"] for r in s.get("extraKnownMarketplaces",{}).values()]); print(*[k for k,v in s.get("enabledPlugins",{}).items() if v])' "$src/settings.json")
claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || true
for m in $(echo "$plugins" | sed -n 1p); do claude plugin marketplace add "$m" >/dev/null 2>&1 || true; done
for p in $(echo "$plugins" | sed -n 2p); do
  if claude plugin install "$p" >/dev/null 2>&1; then echo "plugin ok: $p"; else echo "plugin FAILED: $p"; fi
done
echo "Agent-Setup installed into $claude. Restart Claude Code."
