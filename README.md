# Agent-Setup — how I run Claude Code

My portable Claude Code setup: plugins, skills, hooks, output style, folder
conventions, and the day-to-day working loop. Clone it on a new laptop, follow
[`SETUP.md`](SETUP.md), and you get the same agent I work with.

This README is the **explanation** — what each piece is and why it's there.
`SETUP.md` is the **install procedure**.

One companion repo, kept separate on purpose:
[**voicemode-windows-setup**](https://github.com/Hishor-Ramanathan/voicemode-windows-setup)
— getting VoiceMode running on native Windows, where its installer refuses to.
That's a fix for someone else's bug on one OS; this is how I work. See §4.

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
| **mattpocock-skills** | `mattpocock` ([mattpocock/skills](https://github.com/mattpocock/skills)) | ~35 composable engineering + productivity skills: the grilling family, issue triage, domain docs, `/teach`. This is the backbone of the whole workflow — see §5. |

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
| **VoiceMode** | `~/.claude.json` (global), after the hand-wiring in [voicemode-windows-setup](https://github.com/Hishor-Ramanathan/voicemode-windows-setup) | spoken replies, so a session becomes a conversation. Local whisper + kokoro in Docker; nothing leaves the machine. See §4. |

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
| `hooks_common.py` | — | Shared helper. Hooks run with `cwd` = project root, which has no `pyproject.toml`; everything routes through its `uv()` wrapper (`--project` + `cwd`=worktree) or `uv` picks the wrong environment. |

### Output style ([`global/output-styles/concise.md`](global/output-styles/concise.md))

`concise` — lead with the outcome, fragments over sentences, code in fenced
blocks, prose out of them. The one exception: a walkthrough I explicitly asked
for gets full length.

Style beats CLAUDE.md prose, so this is the real control on verbosity.

### Permissions

`ask` on the destructive set — `git push`, `git reset --hard`, `git clean`,
`rm -rf`, `manage.py flush`. Everything else runs. I review locally and push
myself; the agent never pushes.

### Talking to it: voice, and Remote Control

Both are on by default in `global/settings.json`, because both remove a step I
was doing by hand every session.

**Voice dictation** (`voice.mode: "hold"`) is push-to-talk on **Space**. It fits
how I work: I sit at the strategy level, so what I hand the agent is *intent* — a
paragraph of what and why, not code. That's faster spoken than typed. It's also
the honest version of the input: dictating a paragraph makes me state the goal,
where typing tempts me to shortcut into naming files. No key, no cloud project,
no local model — transcription is Anthropic-side.

**VoiceMode** is the other half, and a separate project of mine. Dictation only
carries words *in*; VoiceMode speaks the reply back, which turns a session into a
conversation — the mode I actually want for design and grilling, where I'm
pacing and thinking, not reading a diff. It runs entirely locally (whisper in,
kokoro out, both in Docker). The catch is that its installer refuses Windows
outright, so it has to be hand-wired:

> **[voicemode-windows-setup](https://github.com/Hishor-Ramanathan/voicemode-windows-setup)**
> — VoiceMode on native Windows: the hand-wired setup that works when the
> installer says no.

That's deliberately its own repo, not folded in here: it's a **fix for a broken
installer on one OS**, with a shelf life, while this repo is how I work. Sitting
next to each other but not merged is the point.

**Remote Control** (`remoteControlAtStartup: true`) makes the session reachable
from the phone the moment it opens, rather than after I remember to type `/rc`.
Same reasoning as everything else here: if I have to remember it, it isn't set
up.

Wiring for all three: [`SETUP.md`](SETUP.md#voice--two-separate-things).

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

### Wiring the skills to the project (do this first)

`mattpocock-skills` is generic on purpose. Three config files tell it what *this*
project does, and until they exist the skills guess — inventing labels you don't
use and filing issues where you don't want them. Run once per project:

```
/setup-matt-pocock-skills
```

| It writes | Which decides |
|-----------|---------------|
| `issue-tracker.md` | what "create an issue" / "fetch the ticket" resolve to |
| `triage-labels.md` | how the five canonical roles map onto your vocabulary |
| `domain.md` | single- vs multi-context; where `CONTEXT.md` and `docs/adr/` live |

I move them from the skill's default `docs/agents/` into
`.claude/reference/agents/` — same reason as everything else in `.claude/`: it
sits outside every worktree. See
[`project-template/reference/agents/README.md`](project-template/reference/agents/README.md).

### The loop: grill → capture → triage → promote → spec → plan → build → push

**0. Grill, before anything gets written down.** The
[grilling](https://aihero.dev/skills-grilling) family interviews you until nothing
is silently assumed. It works as a **design tree**: each round asks the whole
*frontier* — every decision whose prerequisites are already settled — so thirteen
questions land in about three rounds, and you're never asked something that hinges
on an answer it hasn't heard. Facts it looks up itself via subagents; decisions it
must wait for.

| What's in front of you | Skill | Leaves behind |
|---|---|---|
| An idea, no repo needed | `/grill-me` | nothing — a sharper idea in your head |
| A repo, one session's worth of change | `/grill-with-docs` | `CONTEXT.md` entries + ADRs, written as terms resolve |
| Too big for one session | `/wayfinder` | a map of tickets, with grilling inside each |
| "How should this look/feel?" — ungrillable | `/prototype` | a throwaway to react to, then come back |

`grilling` itself is the only one the model invokes on its own; the rest I type.
Run them in a **fresh conversation**, plan mode **off** — plan mode rushes toward
a plan, which is the opposite of staying in inquiry.

The failure mode to watch: answering "agreed, agreed, agreed" for forty questions.
It feels productive because it was long, and nothing was decided. **A session with
no pushback from me is a session I didn't need.**

1. **Capture.** Every issue starts as a note in `.claude/issues/`, opened as an
   Obsidian board (`issues.base`). Cheap to write, zero ceremony, no tracker
   round-trip. `/to-tickets` turns a grilling session into these.
2. **Triage.** `/triage` sets `status:` frontmatter — one of `needs-triage`,
   `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Local, not remote
   labels.
3. **Promote.** Only a fully-specified `ready-for-*` note reaches the real tracker,
   via a project skill that owns the house format. Most notes never graduate —
   that's the point. This **inverts the skills' default**, so `issue-tracker.md`
   states it explicitly.
4. **Spec.** `/to-spec` on the grilling conversation → `.claude/mrs/<mr>/spec.md`.
   Do this *instead of* clearing the context: `grill-with-docs` only persists terms
   and ADR-worthy decisions, so everything else you agreed exists solely in that
   context window.
5. **Plan → shape first.** For code, the plan is **class + method signatures with
   one-line docstrings, and which file each lives in**. Bodies only after my go.
   Signatures are where design errors are cheap to catch.
6. **Build.** Agent writes it. Hooks enforce style, imports, lint. Then it walks me
   through: **what / why / which pattern / what breaks** — so I can defend every
   line in review.
7. **Push.** I review locally and push. The agent never pushes and never adds
   itself as co-author.

### Docs: what earns a file

`grill-with-docs` and `/domain-modeling` write **lazily** — nothing is scaffolded
up front, files appear the moment something actually resolves:

| What resolved | Where it lands |
|---|---|
| A term — the project's own word for a thing | `CONTEXT.md`, inline, the moment it resolves |
| A decision that is hard to reverse **and** surprising without context **and** a real trade-off | an ADR in `docs/adr/` |
| Everything else you decided | the conversation, and nowhere else |

All three ADR gates must hold at once, so most decisions don't qualify and most
sessions produce zero ADRs. **A session that yields a sharper glossary and no ADR
is working as designed.** `CONTEXT.md` stays a glossary — no implementation
detail, no spec, no scratch notes.

This is the same instinct as *delete facts, archive decisions*: the glossary is
the project's vocabulary so humans and agents stop re-deriving it, and the ADR
folder is the answer to "why didn't you do X?".

### Other skills worth knowing

| Skill | For |
|---|---|
| `/wait-what` | the agent's last message re-pitched, because it didn't land |
| `/research` | a background agent reads primary sources, leaves a cited doc |
| `/handoff` | spin a tangent out to its own workspace without derailing the session |
| `/diagnosing-bugs`, `/tdd`, `/implement` | the build-side counterparts |
| `/code-review`, `/improve-codebase-architecture` | after the fact |

### `/teach` — learning as its own workspace

Separate from shipping. `/teach` turns a directory into a standing course on one
topic across many sessions. Two things make it different from just asking:

- **It doesn't teach from what the model already knows.** Parametric knowledge is
  treated as untrusted — it finds high-trust sources first, records them in
  `RESOURCES.md`, and cites them in every lesson.
- **It's stateful.** The mission, resources, lessons and what you've demonstrably
  learned are files, so the next session resumes from those rather than from
  whatever survived the last context window.

```
MISSION.md          why you're learning this — everything hangs off it
RESOURCES.md        the vetted sources, split Knowledge / Wisdom
lessons/*.html      the numbered lessons
reference/*.html    cheat-sheets and glossaries — what you return to
learning-records/   ADR-style notes on what you've actually learned
NOTES.md            your teaching preferences
assets/             shared stylesheet, so it reads as one course
```

It targets **storage strength** (long-term retention) over **fluency** (the
in-the-moment recall that feels like mastery while reading and is gone in a week)
— via retrieval practice, spacing, interleaving. The **mission** is what stops
lessons drifting abstract, and it plus the learning records pick the next lesson
inside your zone of proximal development.

One mission per workspace. The docs say keep it out of the project you're working
in; I keep mine at `.claude/teach/` anyway, because the vault *is* the learning
surface and Obsidian renders it. Take that as a deliberate deviation, not the
recommendation.

Reach for it when the learning **is** the project. For one idea explained in
passing, just ask.

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
    ├── reference/prompts/     how to write the style contracts hooks inject
    ├── reference/agents/      wiring mattpocock-skills to the project
    └── docs/ issues/ mrs/ teach/ tools/
```
