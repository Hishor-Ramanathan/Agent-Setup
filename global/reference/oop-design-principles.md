# OOP design — how I think about structure

_My working belief: **the fastest way to clean code is to abstract it into
cohesive, intent-named classes.** You should understand what a method is *for*
just from the class it lives in. This pairs with `clean-code-principles.md` —
that one is about the small (names, functions); this one is about the shape._

**The core promise:** a class name is a contract about what's inside. When you
read `TocHeadingSource`, you already know every method in it exists to pull
headings out of a table of contents. Loose module-level functions feel "homeless"
— you can't tell what they're for without reading them. Classes make code
*navigable*.

---

## 1. Cohesion first — one class, one reason to exist
- A class should do **one thing**, named for that thing (SRP — Single
  Responsibility Principle). If you need "and" to describe it, it's two classes.
- High cohesion = the methods and fields all serve the same job. Low cohesion (a
  `Utils` grab-bag) is the smell.
- **Java analogy:** you already do this — `PdfReader` reads PDFs, `HeadingSource`
  yields headings. You'd never put `sendEmail()` on `PdfReader`. Same instinct,
  applied everywhere.

## 2. Place things by who uses them
This is the rule that decides *where* code lives:

| Users | Put it |
|-------|--------|
| **one** class uses it | **inside** that class (private method) |
| **many** classes use it | a neutral, well-named module (e.g. `text.py`) |
| it's a **contract** (interface/ABC) implementers share | the shared base layer where they all reach it |
| a concrete class **only one** caller uses | leave it *local* until a 2nd user appears |

Don't hoist a helper to a shared module "just in case." Move it when a second
real user shows up — not before.

## 3. Data-variance → optional field. Behaviour-variance → subclass.
The most common over-modelling mistake is subclassing for *data* differences.
- If two things differ only in **what data they carry** (a PDF heading has a page
  number, an HTML heading doesn't) → **one class, an optional field** (`page: int | None`).
  Subclassing here forces ugly `isinstance` checks downstream (downcasting).
- If two things differ in **how they behave** (bookmarks vs. printed-ToC extraction
  are *different algorithms*) → **subclass / strategy** behind a shared interface.
- **Java analogy:** you wouldn't make `PdfUser extends User` just because PDF users
  have an extra nullable field. You *would* make `PdfReader` and `WordReader`
  implement a `DocumentReader` interface, because they *read differently*.

## 4. Kill abstractions nothing branches on (YAGNI)
- An enum, interface, or config value earns its place only when **something
  actually branches on it**. A `SectionKind` enum that nothing switches on is
  noise — a plain field (or nothing) is cleaner.
- One implementation of an interface is not an abstraction, it's ceremony. Add the
  interface when the **second** implementation arrives.
- Dead flexibility is a cost: every reader has to understand it, and it lies about
  what the code actually varies on.

## 5. Program to the interface, inject the dependency
- Depend on the **contract** (the ABC / interface), not the concrete class, at the
  seams where things vary (Dependency Inversion). The orchestrator holds a
  `DocumentReader`, not a `PdfReader`.
- This is what makes the code testable (swap a fake) and extensible (add a reader
  without touching the orchestrator) — the Open/Closed Principle in practice.

---

## The mental checklist when designing
1. What are the **nouns** (data) and the **verbs that vary** (behaviour)?
2. Verbs that vary → an interface + one class per variant.
3. Data that varies → one class, optional fields — *not* subclasses.
4. Each class gets an **intent-revealing name**; if you can't name it in one noun
   phrase, its responsibility is muddy — split it.
5. Every helper: **who uses it?** → that decides where it lives.
6. Anything nothing branches on → **delete it.**

---

## Sources
- Robert C. Martin — SOLID principles (SRP, OCP, LSP, ISP, DIP): https://en.wikipedia.org/wiki/SOLID
- Cohesion & coupling — https://en.wikipedia.org/wiki/Cohesion_(computer_science)
- "Composition over inheritance" — https://en.wikipedia.org/wiki/Composition_over_inheritance
- John Ousterhout, *A Philosophy of Software Design* — "deep modules" (simple interface, real work hidden).
