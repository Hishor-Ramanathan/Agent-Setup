# Code style contract — the single source

_Rewritten 2026-09-02 against `../agent-clean-code-research.md`; tightened 2026-09-03 when the
mechanical rules moved into hooks (`.claude/hooks/`); COMMENTS rewritten 2026-09-05 after an
over-commenting miss (docstrings on self-explanatory methods). What a linter can check is no longer prose
here: the save hook runs ruff with the house ruleset, the commit hook runs ruff + mypy + pylint on
the staged files. Maintenance rule: a miss earns a new YES/NO pair under the rule it violated, and
something else gets pruned — the fence must not grow._

The fenced block is the contract. The pre-edit hook loads it into context on the first cmthub
edit of a session; it is also written to be pasted whole into another session.

---

````
STYLE CONTRACT — cmthub backend.

EXEMPLARS carry the taste; imitate them, never improvise a style:
- DESIGN: risk_assessment/models.py (RequestInformation, the participant abstract base),
  s3_service/s3_backend.py::S3StorageBackend, bom/models.py::ReviewRequestQuerySet
- PROSE OF CODE: tds/parsers, tds/rules
Human-readable first, machine second. Fewer lines is never the goal.

THE LOOP — done means all four
1. SHAPE FIRST. Non-trivial change: class + method signatures, one-line docstrings, the file
   each lives in. Hishor's go, then bodies.
2. WRITE. The hooks are the reviewer of record: on save, ruff (repo config + house rules)
   reports what is left; on `git commit`, ruff + mypy + pylint run on the staged files.
   Fix what they report. `# noqa` / `# pylint: disable` only with Hishor's ok.
3. PROVE. `uv run pytest <app>/tests --no-cov`; report the real result, failures included.
4. WALK HIM THROUGH IT. what / why / which pattern / what breaks.

DESIGN — DEEP MODULES, ASK THE OBJECT
- A module is deep when a small public surface hides a lot of behaviour. Public is what one
  caller needs; everything else is _private. Three public methods that must be called in
  order are one method.
- Behaviour lives on the class that owns the data; callers ask the object.

```python
# YES — the object answers
for section in document.iter_sections(exclude):
# NO — an outside resolver dismantles the object
for section in resolve_scope(document, area, exclude):
```

- Domain classes own their invariants and transitions: validation in clean(), save()
  composes named private steps (_verb_noun), transitions are intent-named methods
  (set_workflow_status), never callers poking fields.
- Shared shape across sibling models -> abstract base model. Cross-model query logic ->
  custom QuerySet (.as_manager()). Views orchestrate only; business rules never leak in.
- Module-level functions only for stateless mapping (external -> domain) or cross-aggregate
  glue with no single owner. Few, short, typed.
- One traversal primitive per structure; siblings go through it, never three same-name
  variants.
- Nothing speculative: no abstraction with one implementation, no config nothing branches
  on, no new layer when a method on an existing class does the job.

NAMES REVEAL INTENT
build_tree, split_preamble, toc_end read as prose; booleans are predicates (is_big). Reuse
the codebase's word: next to standard_title() write _apply_standard_titles. No tmp/data/x;
abbreviations only when domain-standard (pdf, toc).

FUNCTIONS — ONE LEVEL OF ABSTRACTION, NOT SHREDDED
If the name needs "and", split. Extract a helper only when the CALL SITE reads clearer; a
clear 15-line function beats six one-liners. The hook's complexity limits are a ceiling,
not a target.

UNROLL PACKED EXPRESSIONS
If a reader can't spot where a name is defined, or can't print() an intermediate without
rewriting the line, it is a loop with named locals.

```python
# YES — every name visible
lines: list[str] = []
for page in self.pages:
    lines.extend(clean_lines(page).splitlines())
# NO — nested for + walrus in a comprehension
lines = [s for page in self.pages for line in page.splitlines() if (s := line.strip())]
```

```python
# YES — guard clause loop
for index, (line_page, _) in enumerate(self.lines):
    if line_page >= page:
        return index
return len(self.lines)
# NO — sentinel buried under a genexp
return next((i for i, (p, _) in enumerate(self.lines) if p >= page), len(self.lines))
```

A single `for` with a single `if` and no walrus stays compact. The one required walrus is
the guard, pylint R6103 fails CI without it:

```python
# YES
if (known_term := TERMS.get(term)) is None:
    return ()
```

COMMENTS — ONLY WHAT THE SIGNATURE CANNOT SAY
Exemplar density: bom/models.py has 1 docstring for 14 methods, s3_backend 2 for 6, one
inline comment per file and each is a why (a constraint, an issue link). Match that.
A docstring earns its place only if it carries a RULE the name hides ("untyped rules plus
those naming the type"), a TRANSFORMATION ('"missing link" -> \b(?:...)\b'), or a WHY.
Restating the name or the body = delete it. Telegraphic fragments, grammar irrelevant,
block form, 1 line preferred, 2 max. No TODO (pylint fixme fails CI), no commented-out code.

```python
# NO — the name already says it
def find_section(self, title: str) -> Section | None:
    """
    The first section bearing the title; None when no section does.
    """
# YES — nothing to add, so nothing
def find_section(self, title: str) -> Section | None:
```

```python
# NO — prose restating the code
# a flat message, not serializer.errors: the wizard's error toast can only render one line
# YES — the constraint, telegraphic
# one line: the wizard's toast renders no more
```

IMPORTS — NO SURPRISES
Only modules the worktree already imports; the pre-edit hook asks Hishor for anything new,
stdlib included. New pip packages never without explicit approval.

ERRORS — DEFINE THEM OUT, ELSE RAISE
First design so the error cannot happen: a rule with no matching section yields an empty
tuple, it does not raise. Where it can happen, fail at the boundary with a named type
(DocumentParseError), guard clause first, specific exceptions only, nothing swallowed. None
means legitimate absence (find_section), never a hidden failure.

TESTS
Every behaviour has a test at the layer that owns it; test-style-prompt.md in full.

VERIFY, DON'T ASSUME
Re-read a file before editing, Hishor edits too. Before an MR the gates are whole-tree:
`uv run poe lint && uv run poe types && uv run poe pylint` (judge pylint by exit code).
````

---

## What the hooks enforce (so the fence does not have to)

| Hook | When | Enforces |
|---|---|---|
| `inject_style_contract.py` | first cmthub `.py` edit per session (and again after compaction) | this contract, or the test contract for `tests/`, is in context |
| `check_new_imports.py` | every cmthub `.py` edit | rule IMPORTS: unknown module -> Hishor is asked |
| `lint_on_save.py` | after every cmthub `.py` edit | ruff format + autofix, then the house ruleset back into context: `BLE` (blind except), `ERA` (commented-out code), `FIX` (TODOs), `RET` (guard clauses), `C901`/`PLR091x` (complexity ceiling), `TRY002`/`TRY201`, `PLW`, `PIE`, `A`, `ISC`, `RSE`, `T20` (print); tests get `PT` (pytest style) minus `PT006` |
| `check_commit.py` | every `git commit` | conventional subject, no AI trailer, staged files pass ruff + mypy + pylint (prod settings) |

Rules that fired on the exemplar apps (`ARG`, `FBT`, `N`, `PLR2004`, `SLF`, `D401`) were rejected: a
rule the exemplars break is not house style.

## Sources

- `.claude/reference/agent-clean-code-research.md` — why this file is shaped this way.
- Colleague design exemplars mined 2026-09-02 (risk_assessment, s3_service, bom, cra, ltb).
- Robert C. Martin, *Clean Code* (2008); John Ousterhout, *A Philosophy of Software Design*
  (deep modules, define errors out of existence).
