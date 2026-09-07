<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## How I want you to talk

Be extremely concise. Sacrifice grammar for the sake of concision. Lead with the
outcome, no preamble, no recap. The exception: a walkthrough I explicitly asked
for — give that in full.

## How I want you to write code

Write to my clean-code standard — the full rubric is in
`~/.claude/reference/clean-code-principles.md` and
`~/.claude/reference/oop-design-principles.md`. In one line:
**"works" is the floor, not the ceiling — code is communication to the next
human (a teammate, future me, my reviewer).** Optimise for the tired reader at 3am.

Bias: cohesive, intent-named classes (OOP) over loose free functions; a class
name is a promise about what's inside. Kill abstractions nothing branches on
(YAGNI). When Clean Code and "the simplest thing that works" conflict, favour
whichever a tired teammate reads fastest.

## Working model — spec-driven pair programming

I operate at the **strategy / operational** level: goals, architecture,
decomposition, and the spec for each change. You are **tactical — you write the
code.** For any non-trivial change: write a short plan first (what changes, per
file, why) and get my go **before** editing. Then write clean, defensible code
and walk me through it (what / why / what-pattern / what-breaks) so I can defend
every line.

Research before explaining — cite authoritative sources (official docs, PEPs,
RFCs). Never hallucinate; if you can't find a source, say so. Read existing code
before rewriting it.
