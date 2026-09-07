# Pre-MR prompt — cmthub backend

_Written 2026-07-27, cut to the actionable parts 2026-08-20 after a pipeline went red on a rule
this file did not carry._

**Read this in full before pushing an MR.** These are the local equivalents of the two GitLab jobs
(`backend:lint`, `backend:test`) in `.gitlab/ci/backend.yml` — pass here, pass there.

## 1. The sequence

From the worktree root, in a shell that has sourced `.env/backend/variables.sh`:

```bash
uv run poe format                                          # rewrites files — run first
uv run poe lint                                            # ruff + djlint + dead fixtures
uv run poe types                                           # mypy .
uv run poe pylint                                          # pylint, whole tree
uv run poe check-deploy                                    # manage.py check --deploy
uv run python manage.py makemigrations --check --dry-run   # model change without a migration?
uv run pytest --no-cov                                     # full suite
```

**Always whole-tree, never a path argument.** CI runs `mypy .` and `pylint --recursive=y .`; a
scoped run misses errors your change caused in sibling files. (Pylint's `ignore-paths` skips
`tests/` — mypy does not.)

## 2. Reading pylint's exit code — where MRs actually die

Pylint exits non-zero on **any** message and GitLab fails the job on that, so a 10.00/10 rating
still fails. The code is a bitmask, and it is the only signal you get: in CI `poe pylint` writes to
`pylint_results.xml`, so **the job trace shows no error text at all**.

| Exit | Category | The trap in this repo |
|---|---|---|
| 4 | warning (W) | `fixme` (W0511) is not disabled — **a `# TODO:` comment fails the job.** |
| 8 | refactor (R) | `.pylintrc` loads `pylint.extensions.code_style`, so **`consider-using-assignment-expr` (R6103) demands the walrus operator.** |
| 16 | convention (C) | e.g. `bad-classmethod-argument` — a `@classmethod` whose first parameter is named `self`. |

R6103 is what killed pipeline `71271095` on 2026-08-12. Assigning a name and testing it on the very
next line must be one walrus guard:

```python
# NO — exit 8
known_term = TERMS.get(term)
if known_term is None:
    return ()
# YES
if (known_term := TERMS.get(term)) is None:
    return ()
```

This is the one place the walrus is required; inside a comprehension filter it stays banned —
see `code-style-prompt.md` "UNROLL PACKED EXPRESSIONS". The commit hook (`.claude/hooks/check_commit.py`)
runs pylint on the staged production files with prod settings, so R6103 now surfaces at commit time,
not in CI.

Run `uv run poe pylint` locally to see the messages: it defaults to `--output-format=text`.

## 3. Local-only setup that is NOT in the git tree

**`cmthub/settings/local.py` is flagged `skip-worktree` in the `cmthub` worktree.** It is tracked,
but git ignores every local edit to it, so the `CACHALOT_ENABLED = False` line there never appears
in `git status` and cannot be committed by accident. Confirm with:

```bash
git ls-files -v cmthub/settings/     # S = skip-worktree, H = normal
```

**A new worktree does not inherit the flag.** As of 2026-08-20 `cmthub2` shows `H` for `local.py`
and has no cachalot line. If a fresh worktree behaves differently from `cmthub`, check this first:

```bash
git update-index --skip-worktree cmthub/settings/local.py
```

**Tests themselves need no workaround.** `pyproject.toml` sets
`DJANGO_SETTINGS_MODULE = "cmthub.settings.testing"`, and `testing.py` carries
`CACHALOT_ENABLED = False` on `main` (commit `326f4c10`). Plain `uv run pytest` is enough — any
older instruction to create `cmthub/settings/test.py` and pass `--ds=cmthub.settings.test` is dead,
that module does not exist.

Why cachalot has to be off at all: it defers cache invalidation to transaction commit, `migrate`
runs inside one long transaction, so `post_migrate` reads a pre-transaction cache, believes no
content types exist, re-inserts them, and dies on a duplicate key while building `test_dephant`.

## 4. Known local failures — not yours

5 failures in `bom/tests/test_view_review_attachment.py` (`assert 400 == 201` on upload).
`.env/backend/variables.sh` sets no S3 variables while CI sets four; exporting them fixes 2 of the
5, and the remaining 3 are pre-existing and unrelated to `tds`.

```bash
export STORAGE_CLASS_S3=s3mock
export AWS_S3_ENDPOINT_URL=http://localhost:9090
export AWS_S3_REGION_NAME=eu-west-1
export AWS_S3_BUCKET_NAME=cmthub-local
```

## 5. If the test database wedges

A run killed mid-flight leaves a half-built `test_dephant`, and the next run reports
`database "test_dephant" already exists`. Drop it — `dephant` (your dev data) is a different
database and is untouched:

```bash
uv run python -c "
import psycopg
with psycopg.connect(host='127.0.0.1', port=5432, user='postgres', password='postgres',
                     dbname='postgres', autocommit=True) as c:
    c.execute('DROP DATABASE IF EXISTS test_dephant WITH (FORCE)')
"
```

If that is not enough a stale connection is holding it open — `pg_terminate_backend` the sessions
on `test_dephant` first.

## Sources

- `.gitlab/ci/backend.yml` — the authoritative list of what CI runs
- `pyproject.toml` `[tool.poe.tasks]` — what each `poe` task expands to
- pylint exit codes — https://pylint.readthedocs.io/en/stable/user_guide/usage/run.html#exit-codes
- `consider-using-assignment-expr` — https://pylint.readthedocs.io/en/stable/user_guide/messages/refactor/consider-using-assignment-expr.html
