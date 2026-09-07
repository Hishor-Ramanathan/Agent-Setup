# Test conventions — cmthub

_Merged 2026-07-27; rewritten 2026-08-20 against the tests shipped in MR !759
(`tds/tests/conftest.py`, `tds/tests/test_parser_pdf.py`) and the refactor-validators rule tests._

**Read this in full before writing or editing any test.** It is the single source for test style,
the way `code-style-prompt.md` is for production code. Match it; do not invent a new style.

_Exemplars are the `tds` parser and rule tests named above, plus `bom/` and `risk_assessment/`.
Where this file and shipped tests disagree, the shipped tests win — say so and fix this file._

## 1. What to test — each concern once, at the layer that owns it

Each layer verifies only what it uniquely can and trusts the inner layers for the rest
(Fowler, test pyramid). Re-testing inner logic at an outer layer is slower and flakier for a
check you already have.

| Layer | Tests | Example |
|-------|-------|---------|
| **Unit (logic)** | helpers, parsers, rules — in isolation, fast, the bulk | `test_parser_pdf.py`, `test_rule_regex.py` |
| **View / API (boundary)** | what a unit test structurally cannot reach: the auth matrix, data isolation, the exact JSON keys the frontend depends on, HTTP semantics | `test_view_*.py` |

A bare happy-path `assert 200` that only mirrors the framework is low value — keep those minimal.

**Do not test:** framework behaviour (DRF pagination, the ORM), trivial getters and pure glue,
the same logic at two layers, coverage for its own sake.

## 2. Layout

- One flat file per unit: `test_<module>.py` / `test_view_<name>.py`, flat in `app/tests/`.
  No nested `tests/parsers/` directories.
- Fixtures used by more than one file go in that app's `tests/conftest.py`.
- Object builders used by one file stay in that file, as module-level `_helpers` (§ 5).

## 3. Structure

- Group tests in `class Test<Subject>:` — one class per unit under test.
  `TestBookmarkHeadingSource`, `TestRegister`, `TestRequiredPattern`.
- One behaviour per test. Cover empty / unknown / falsy / boundary / not-found / unauthorized.
- `def test_<behaviour_in_words>(self, ...) -> None:` — the name reads as the behaviour, and the
  `-> None` is explicit.
- **Every test method carries a block docstring**: one terse imperative "must" sentence, no
  em-dashes, no justification tail.
  ```python
  def test_bookmark_without_a_target_page_is_skipped(self) -> None:
      """
      A bookmark pypdf cannot resolve to a page must be dropped, not emitted with
      an empty page.
      """
  ```
  The other apps (`bom`, `cra`, `ltb`, `risk_assessment`, `users`) write no test docstrings — the
  name alone carries the behaviour. In `tds` they are kept on purpose (2026-07-27: the parser is
  complex enough to warrant them).
- No `__init__`. Shared state comes from `@pytest.fixture(autouse=True)`; when it guards global
  state it is module-level and underscore-prefixed, and restores on the way out:
  ```python
  @pytest.fixture(autouse=True)
  def _pristine_registry() -> Iterator[None]:
      """
      Restores CHECKS after each test, so registrations do not leak.
      """
      saved = dict(CHECKS)
      yield
      CHECKS.clear()
      CHECKS.update(saved)
  ```
- In `tds`, test methods take plain `self` (`risk_assessment` sometimes marks them
  `@staticmethod` — match the app you are in).

## 4. Doubles — a real object or a `MagicMock`, nothing else

**Real objects wherever the thing is plain data.** `Section`, `Document`, `Heading`, a
`list[str]` of pages — construct them. Mock only at the third-party or IO boundary, which in
`tds` means pypdf and Celery.

**Every double is a `MagicMock`.** Never a hand-rolled stub class; the attributes are just
constructor kwargs.

```python
# NO — six lines of class to hold two attributes
class FakeBookmark:
    def __init__(self, title: str, page: int) -> None:
        self.title = title
        self.page = page

# YES
MagicMock(title="1 Intro", page=0)
```

**`spec=` whenever the mock stands in for a real class**, so a renamed member fails the test
instead of returning another mock: `MagicMock(spec=pypdf.PdfReader)`,
`MagicMock(spec=BaseValidator)`.

**Behaviour goes on the mock, not into a subclass.**

```python
# NO — overriding a method to compute a return value
class FakeReader(pypdf.PdfReader):
    def get_destination_page_number(self, bookmark): return bookmark.page

# YES
reader.get_destination_page_number.side_effect = lambda bookmark: bookmark.page
```

**A double that needs arguments is a fixture factory.** The fixture returns a `build` callable,
and the module exports a `Callable` alias so test signatures can type it:

```python
MockReaderFactory = Callable[[list[Destination | list]], MagicMock]

@pytest.fixture
def mock_reader() -> MockReaderFactory:
    """
    Builds a pypdf reader mock holding the given bookmark outline, where each
    bookmark resolves to its own page attribute.
    """
    def build(outline: list[Destination | list]) -> MagicMock:
        reader = MagicMock(spec=pypdf.PdfReader)
        reader.outline = outline
        reader.get_destination_page_number.side_effect = lambda bookmark: bookmark.page
        return reader

    return build
```

**The one exception to "no stub classes":** when the code under test reads *class* attributes or
checks subclass identity, a `MagicMock` cannot stand in. Then declare a tiny module-private
subclass with a block docstring saying what it exists for — `_StampRule`, `_AnyFormatRule`,
`_EchoRule`. That is a test fixture of the abstract base, not a stub of a collaborator.

**Assert the result, not the call.** Reach for `assert_called_with` only when the call itself is
the observable effect (a dispatched Celery task, an S3 upload).

**Faker belongs in `factories.py`, never in a test module** — `factory.Faker("sentence")` on the
factory field. DB-backed tests inject the factory *class* through conftest
(`document_analyzer_job_factory`), usually inside `with transaction.atomic():`. Reach for the ORM
only when the unit truly needs it.

## 5. Builders and constants

Module-level `_helpers` above the test classes build the domain objects, each with one terse
docstring:

```python
def _scope(text: str) -> Scope:
    """
    A numbered section holding the given text.
    """
    return Scope(section=Section(title="Scope", number="3.2", page=46), text=text)
```

A config repeated across a class becomes a module constant, varied by merge rather than retyped:

```python
REQUIRED = {"subject": "SIEMENS", "error_on_presence": False}
...
findings = _run(document, REQUIRED | {"severity": "error"})
```

## 6. Table-driven cases

```python
@pytest.mark.parametrize(
    "case_sensitive, expected",
    [(True, 0), (False, 1)],
)
def test_a_case_sensitive_config_matches_only_that_spelling(
    self, case_sensitive: bool, expected: int
) -> None:
```

Parameters are typed on the method signature. To parametrize over *fixtures* — including the
permission matrix — use `pytest_lazy_fixtures.lf("some_factory")` inside the values.

## 7. Error cases

`with pytest.raises(SomeError, match="substring"):` around the call, then assert on
`exc_info.value` when the payload matters (e.g. `exc_info.value.message_dict`).

## 8. Running

- Single app, fast: `uv run pytest tds/tests --no-cov` (needs no env sourcing).
- On save the hook runs ruff's pytest-style rules (`PT`, minus `PT006`) on `tests/` and hands the
  violations back; fix them before moving on. `git commit` runs ruff + mypy on the staged files.
- Before an MR the gates are whole-tree — see `pre-mr-prompt.md`.
- A wedged test database is a known failure with a known fix; it is recorded in memory
  (`cmthub-testdb-offline-verify`), not repeated here.

## Sources

- Fowler, "The Practical Test Pyramid" — https://martinfowler.com/articles/practical-test-pyramid.html
- Fowler, "Test Pyramid" (bliki) — https://martinfowler.com/bliki/TestPyramid.html
