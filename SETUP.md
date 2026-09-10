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
- `voice` + `remoteControlAtStartup` — see below.

**Restart Claude Code.** Verify with `/plugin` and `/status`.

Machine-specific things deliberately **not** in this repo: MCP server config
(`~/.claude.json` — add codegraph and any hosted servers in-app), auth state, the
`remote.defaultEnvironmentId`, and `statusline-context.py` if you use a custom one.

### Set the output style

`/output-style concise` — or per project via `outputStyle` in the project
`settings.json`.

### Voice — two separate things

They solve different problems and can both be on. Start with the first.

#### a. Built-in dictation — speech *in*

Transcription runs on Anthropic's servers, so there is **no API key, no cloud
project and no local model**. It needs a Claude.ai login (not API-key auth —
Bedrock/Vertex/Foundry are out), a microphone, and nothing else.

```json
"voice": { "enabled": true, "mode": "hold" }
```

`hold` is push-to-talk: hold **Space** in an empty prompt, speak, release to
send. `tap` starts and stops on separate taps. Toggle in-session with `/voice`,
`/voice tap`, `/voice off`.

| Also under `voice` | Does |
|---|---|
| `autoSubmit` | send on release (`hold`), or on 3+ words (`tap`) |
| `language` | dictation language; falls back to the global `language` |
| `pushToTalk` | the hold key — rebind in `~/.claude/keybindings.json` |

**Windows:** works natively. Allow desktop apps under Settings → Privacy &
security → Microphone. On WSL2 you need WSLg.

Docs: <https://code.claude.com/docs/en/voice-dictation>

#### b. VoiceMode MCP — spoken conversation, fully local

Dictation only carries words *in*. **VoiceMode** adds the reply out loud, so the
session becomes a conversation instead of typing at a wall. It's an MCP server
with local speech engines, so nothing leaves the machine.

Its official installer **rejects Windows outright** (`RuntimeError("Unsupported
operating system")`) even though the runtime itself is fine. So it has to be
hand-wired. That procedure is its own repo:

> **[voicemode-windows-setup](https://github.com/Hishor-Ramanathan/voicemode-windows-setup)**
> — VoiceMode on native Windows: the hand-wired setup that works when the
> installer says no.

What it stands up:

| Piece | Runs |
|---|---|
| VoiceMode | the MCP server, over stdio |
| speaches (faster-whisper-small) | speech-to-text, Docker, port 2022 |
| kokoro-fastapi | text-to-speech, Docker, port 8880 |
| sounddevice | mic and speakers via Windows WASAPI, no WSL layer |

The traps it documents: install with `--no-deps` to dodge the `simpleaudio`
wheel, put ffmpeg on PATH for MP3, pre-download the Whisper model and run
speaches offline with fixed model aliases. A `voice.ps1` toggles the containers,
because leaving two of them running all day is not free.

**MCP registration is machine-specific and stays out of this repo** — see the
note above. Follow that repo, then register `voicemode.exe` in-app.

### Remote Control at startup

`"remoteControlAtStartup": true` starts every session already connected, instead
of typing `/rc` each time. One connection per session; needs the claude.ai login.

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
