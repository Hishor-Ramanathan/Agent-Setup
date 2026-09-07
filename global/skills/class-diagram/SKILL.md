---
name: class-diagram
description: Use when the user asks for a class diagram / UML of Python code (e.g. "/class-diagram tds/parsers", "class diagram of the parsers", "diagram the readers", "mermaid diagram for the MR"). Runs pyreverse to emit either a mermaid `.md` (renders inline in GitLab MRs) or an editable draw.io `.drawio` into .claude/docs/diagrams/generated — deterministic, NO hand-drawing, minimal tokens.
---

# class-diagram

Generate a class diagram from Python source, deterministically. Two formats:

| Format | When | How |
|---|---|---|
| **mermaid** `.md` + `.mmd` (default) | `.md` for MR descriptions — GitLab renders ` ```mermaid ` fences inline. `.mmd` is the same diagram standalone, for Obsidian (mermaid-view plugin) and VS Code preview | `pyreverse -o mmd`, kept raw as `.mmd` and wrapped in a fence as `.md` |
| **draw.io** `.drawio` | he wants to hand-tune layout / move boxes | `pyreverse -o dot` → `graphviz2drawio` |

**pyreverse** ships in pylint (already installed) and speaks `.mmd` natively — no
converter for the mermaid path. `graphviz2drawio` pulls a `pygraphviz` wheel with
Graphviz **bundled** — no system Graphviz install needed.

## Rules (token discipline)

- **Do NOT read the source files. Do NOT hand-draw the diagram.** Just run the command.
- Run from the repo root that owns the code (default: `C:/Projects/Document_Analyzer/cmthub`).
- Report the output path in one line. Only show the diagram inline if the user asks.

## Output layout (IMPORTANT — never overwrite the user's edits)

- The skill ALWAYS writes to
  `C:/Projects/Document_Analyzer/.claude/docs/diagrams/generated/<name>.{md,drawio}` —
  machine-owned, overwritten every run.
- The user's hand-edited "live" copies live in `.claude/docs/diagrams/` (root).
  **NEVER write there.** To tune a diagram, the user copies it up to the root and edits.

## Steps

1. **Target** — from the user's request (a path like `tds/parsers`, a single module like
   `tds/parsers/readers/pdf.py`, or a dotted package). Default `tds/parsers`.
2. **Name** — the target with `/` and `.` replaced by `_` (e.g. `tds_parsers`).
3. **Run** (substitute `NAME` and `TARGET`).

**Mermaid (default):**

```bash
OUT="C:/Projects/Document_Analyzer/.claude/docs/diagrams/generated"; mkdir -p "$OUT"
uv run --directory C:/Projects/Document_Analyzer/cmthub pyreverse -o mmd -p NAME -d "$OUT" TARGET
mv "$OUT/classes_NAME.mmd" "$OUT/NAME.mmd"
{ echo '# NAME — class diagram (GENERATED — do not edit here; copy to ../NAME.md to tune)'; echo
  echo '```mermaid'; cat "$OUT/NAME.mmd"; echo '```'; } > "$OUT/NAME.md"
rm -f "$OUT/packages_NAME.mmd"
```

**draw.io (only when he wants to move boxes by hand):**

```bash
OUT="C:/Projects/Document_Analyzer/.claude/docs/diagrams/generated"
TMP="/tmp/pyrev"; mkdir -p "$OUT" "$TMP"
uv run pyreverse -o dot -p NAME -d "$TMP" TARGET
uv run --with graphviz2drawio graphviz2drawio "$TMP/classes_NAME.dot" -o "$OUT/NAME.drawio"
rm -f "$TMP/classes_NAME.dot" "$TMP/packages_NAME.dot"
```

4. **Report:** wrote `generated/NAME.md` (+ `NAME.mmd`) — paste the fenced block straight
   into the MR description, GitLab renders it; open the `.mmd` in Obsidian/VS Code to view
   the diagram on its own. (draw.io path: open in the desktop app, the VS Code
   Draw.io Integration extension, or `http://localhost:3333/`.)
   To tune either: copy to `docs/diagrams/NAME.{md,drawio}` — the skill won't touch it.

## Useful flags (only if the user asks)

- `-k` only class names (compact) · `-A` include ancestors (`ABC`, `Exception`)
- `-c <Class>` centre on one class + everything related to it

## Limits (say this if the user asks "how it works" / call flow)

Class diagrams show **structure** (classes, attrs, inheritance, type-annotated
associations). They MISS relationships inside method bodies (a method constructing
another class). For call-flow / "who calls whom", use CodeGraph, not this skill.
