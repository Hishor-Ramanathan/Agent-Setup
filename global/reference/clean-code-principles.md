# Clean code — the standard (the rubric)

_Standard: Robert C. Martin, *Clean Code* (2008), calibrated for real projects
and "don't over-engineer." This is the constraint set for any code written for/with
me. Pairs with `oop-design-principles.md`._

**The bar, in one line:** "works" is the floor, not the ceiling. Code is
communication to the next human — a teammate, future you, your reviewer.
Optimise for the tired reader at 3am.

---

## 1. Meaningful names
- Names reveal intent — a reader shouldn't need a comment to know what a thing is.
- Good shape: `build_tree`, `split_preamble`, `body_lines`, `seen_numbered`. Bad shape: `tmp`, `data`, `x`, `idx`.
- Booleans read as predicates: `is_big`, `has_toc`. Variables read as prose: `toc_end`, `by_number`.
- No abbreviations unless domain-standard (`pdf`, `toc` ok; `bl`, `pg` not).

## 2. Functions do ONE thing
- One level of abstraction per function — don't mix orchestration with low-level detail. (Martin's strongest, least-controversial rule.)
- The orchestrator reads like a table of contents; each helper does one job.
- Smell: you can't name it without "and" (`parse_and_validate`).
- Prefer pure functions (no side effects) where natural.

## 3. Comments — the WHY, not the WHAT
- Self-documenting code first; delete any comment that just restates the code.
- **KEEP** strategy docstrings and non-obvious rationale — *why* a regex is shaped
  a certain way, *why* an algorithm re-trees. That's the good kind of comment.
  (Clean Code under-rates this — see calibration.)
- No commented-out code, no changelog comments — git remembers.

## 4. Formatting
- Match the file you're in. Let the auto-formatter run on save — don't fight it.
- Vertical spacing groups related lines; a blank line between distinct ideas.

## 5. Error handling done right
- Raise exceptions, don't return error flags. Fail at the boundary with a clear type.
- Guard clauses over deep nesting; return early on bad state. Never swallow an exception silently.
- Returning `None` for *legitimate absence* is fine; returning `None` to hide an *error* is not.

## 6. Testing IS part of clean
- "No code is clean without tests." Every behaviour has a test.
- Test code is real code — same naming/clarity bar. One concept asserted per test.
- Red → green → refactor. A bug fixed = a regression test that would have caught it.

## 7. Smells to reject
- Long functions, large classes, duplicated logic, deep nesting (>2–3 levels → extract or invert with a guard).
- Duplication → extract a well-named helper. But only *real* duplication — incidental lookalikes that will evolve apart stay separate.

## 8. Craftsmanship
- Boy-Scout Rule: leave code cleaner than you found it — in small, reviewable steps, not a giant rewrite.
- Refactor continuously; care about whoever maintains it. Clean code is respect for your teammates.

---

## CALIBRATION — apply Clean Code with judgment, not as scripture

Even Martin says parts are controversial. The known traps when applying it literally:

- **Over-fragmentation is the #1 trap.** Chopping a clear 15-line function into six
  one-liners *hurts* an expert who already grasps the algorithm (Stroustrup's rule:
  experts want terse and on-point). Small ≠ maximally split. Extract only when it
  makes the *call site* read clearer.
- **Clean Code is Java/OO-centric.** Module-level **pure functions** are often
  cleaner than everything-is-a-class. Don't OO-ify what a plain function does
  cleanly. Python ≠ 2008 Java.
- **Comments: Martin under-rates them.** Redundant *what*-comments are smells;
  *why*/intent/strategy comments are essential. (This is the core of the modern
  counter-text, Ousterhout's *A Philosophy of Software Design*.)
- **When Clean Code and "simplest thing that works" conflict:** favour whichever a
  tired teammate reads fastest. No speculative abstraction, no interface with one
  implementation, no config for a value that never changes.

---

## Sources
- Robert C. Martin, *Clean Code* (2008).
- Balanced summary — https://gerlacdt.github.io/blog/posts/clean_code/
- In Defense of Clean Code — https://dev.to/thawkin3/in-defense-of-clean-code-100-pieces-of-timeless-advice-from-uncle-bob-5flk
- John Ousterhout, *A Philosophy of Software Design* (the modern complement).
