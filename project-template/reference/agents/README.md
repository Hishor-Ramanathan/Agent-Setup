# Agent configs — how mattpocock-skills is wired to this project

The `mattpocock-skills` plugin ships ~35 skills that are **deliberately generic**.
Three config files tell them what *this* project does. Without them the skills
guess: they'll invent labels you don't use and file issues where you don't want
them.

Generate them once per project:

```
/setup-matt-pocock-skills
```

It interviews you (which issue tracker, which triage labels, where docs live) and
writes three files. **Don't hand-write them and don't copy them between projects**
— they'd drift from whatever the plugin currently expects.

| File | Answers |
|------|---------|
| `issue-tracker.md` | Where issues live. What "create an issue" / "fetch the ticket" / "publish to the tracker" resolve to. Whether PRs count as an incoming request surface. |
| `triage-labels.md` | How the five canonical roles — `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` — map onto this project's real vocabulary. |
| `domain.md` | Single-context or multi-context. Where `CONTEXT.md` and `docs/adr/` live, and what to read before exploring the code. |

## The path deviation

The setup skill writes to **`docs/agents/`** by default. This template puts them
in **`.claude/reference/agents/`** instead, because in the umbrella layout
`.claude/` sits outside every worktree — so the configs survive branch switches
and never show up as tracked changes in a shared repo. After running the setup
skill, move the three files and fix the pointers in `CLAUDE.md`.

Same reason `CONTEXT.md` and `docs/adr/` go under `.claude/` rather than the
repo root.

## The override that matters

If you run a two-stage tracker (local notes first, remote tracker only for
refined tickets), say so explicitly in `issue-tracker.md`. It **inverts the
skills' default**, so it has to be stated, not implied:

> When a skill says "create an issue", it means write a local note. Only the
> explicit promotion step reaches the remote tracker.

## The one that bit me: where a spec lands

`to-spec` doesn't take a path. It "publishes to the issue tracker", which means
**`issue-tracker.md` decides where specs go** — and under the two-stage
inversion above, the literal reading is *a vault note*, not a spec file.

If you keep specs somewhere specific, add a line saying so:

> A spec from `/to-spec` is not an issue note. Write it to
> `.claude/mrs/<mr-slug>/spec.md` and leave the tracker alone.

Otherwise the skill does exactly what you told it to, in the wrong folder.
