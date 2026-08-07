"""Static verification for the Supabase migrations.

This machine has no Docker, no supabase CLI and no psql, so the migrations
cannot be executed here. These tests are the next best thing: every migration
must parse as PostgreSQL, and the objects a migration claims to create must
actually exist in its parsed AST. A migration that no longer parses fails the
suite instead of failing silently at deploy time.

Important: this is a *read-only* check. The migrations are the source of truth
and several of them are already deployed against the live project -- the parser
must be adapted to the SQL, never the other way round.
"""
import re
from pathlib import Path

import sqlglot
from sqlglot import exp

MIGRATIONS = Path("supabase/migrations")

# sqlglot's postgres dialect cannot parse a schema-qualified target in
# `drop trigger ... on public.foo` / `drop policy ... on public.foo`, even
# though that is valid PostgreSQL and is the style used throughout these
# migrations. Strip the qualifier *in memory only* so the rest of the file
# still gets parsed. Rewriting the migrations themselves to satisfy the
# parser would mean changing deployed SQL to work around a tooling gap --
# see https://github.com/tobymao/sqlglot for dialect coverage.
_DROP_ON_PUBLIC = re.compile(
    r"(?i)\b(drop\s+(?:trigger|policy)\s+(?:if\s+exists\s+)?\S+\s+on\s+)public\.",
)


def _parseable(sql: str) -> str:
    return _DROP_ON_PUBLIC.sub(r"\1", sql)


def _parse(migration: Path) -> list[exp.Expression]:
    return sqlglot.parse(_parseable(migration.read_text(encoding="utf-8")), dialect="postgres")


def _created_table_names(expressions: list[exp.Expression]) -> set[str]:
    names: set[str] = set()
    for expression in expressions:
        if not isinstance(expression, exp.Create) or not isinstance(expression.this, exp.Schema):
            continue
        table = expression.this.this
        if isinstance(table, exp.Table):
            names.add(table.name)
    return names


def test_every_supabase_migration_parses_as_postgres():
    migrations = sorted(MIGRATIONS.glob("*.sql"))
    assert migrations, "no migrations found -- check the MIGRATIONS path"
    for migration in migrations:
        expressions = _parse(migration)
        assert expressions, f"{migration} parsed to no statements"


def test_meridian_hub_migration_creates_its_claimed_tables_in_the_ast():
    expressions = _parse(MIGRATIONS / "20260807000000_meridian_hub_resident_surface.sql")
    assert {
        "resident_hub_devices",
        "assistance_requests",
        "visitor_verification_prompts",
    } <= _created_table_names(expressions)


def test_resident_hub_views_never_expose_face_crypto_material():
    """Slide 6's promise, enforced at the resident surface.

    The resident's Hub is the least-trusted screen in the building: it sits in
    an unlocked room and asks "is this person expected?". It may show the
    caregiver-facing description and timing, and nothing else. If a future edit
    joins a face embedding, ciphertext, digest, nonce or key id into one of
    these views, this fails.
    """
    forbidden = (
        "face_embedding", "embedding_ciphertext", "ciphertext", "digest",
        "nonce", "key_id", "person_photo", "encrypted",
    )
    sql = (MIGRATIONS / "20260807000000_meridian_hub_resident_surface.sql").read_text(encoding="utf-8")
    views, offenders = [], []
    for match in re.finditer(
        r"(?is)create\s+or\s+replace\s+view\s+public\.(resident_hub_\w+)\s+as\s+(.*?);\s*\n",
        sql,
    ):
        view, body = match.group(1), match.group(2).lower()
        views.append(view)
        offenders += [f"{view} selects '{term}'" for term in forbidden if term in body]

    # A guard that silently matches nothing is worse than no guard.
    assert views, "no resident_hub_* views matched -- this test is not checking anything"
    assert not offenders, "resident Hub views expose face crypto material:\n" + "\n".join(offenders)


def test_migrations_keep_schema_qualified_drop_targets():
    """The repo's house style schema-qualifies every DDL target (`public.foo`,
    `storage.objects`).

    Guarding it here means the next person who hits the sqlglot parse error
    fixes the parser shim above rather than quietly de-qualifying deployed SQL.
    """
    unqualified = re.compile(r"(?i)^\s*drop\s+(?:trigger|policy)\s+.*?\son\s+(\S+)")
    offenders: list[str] = []
    for migration in sorted(MIGRATIONS.glob("*.sql")):
        for i, line in enumerate(migration.read_text(encoding="utf-8").splitlines(), 1):
            match = unqualified.match(line)
            if match and "." not in match.group(1):
                offenders.append(f"{migration.name}:{i}: {line.strip()}")
    assert not offenders, "unqualified DDL drop targets:\n" + "\n".join(offenders)
