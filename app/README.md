# API service

Flask API using an application factory, SQLAlchemy 2.0 models, and Alembic for
schema management. Importing the app has **no** side effects — it never creates
tables or seeds data. Schema is applied out-of-band with Alembic; seed data via
a Flask CLI command.

## Layout

| File | Responsibility |
|------|----------------|
| `models.py` | Engine construction + pool sizing, ORM models, seed data. No side effects on import. |
| `app.py` | `create_app()` factory, routes, request-scoped sessions, `seed` / `create-all` CLI commands. |
| `wsgi.py` | Gunicorn entry point (`gunicorn wsgi:app`). |
| `alembic.ini` + `migrations/` | Schema versioning. |

## Configuration (env)

| Var | Default | Notes |
|-----|---------|-------|
| `DB_HOST` | _(unset)_ | If unset, falls back to local SQLite (`local-dev.db`). |
| `DB_PORT` | `5432` | |
| `DB_NAME` | `legacyapi` | |
| `DB_USER` | `appuser` | |
| `DB_PASSWORD` | _(empty)_ | Injected from Secrets Manager on ECS. |
| `DB_POOL_SIZE` | `5` | Persistent connections per worker. |
| `DB_MAX_OVERFLOW` | `5` | Burst connections per worker. |
| `DB_POOL_TIMEOUT` | `30` | Seconds to wait for a free connection. |

**Connection budget:** total DB connections =
`tasks × gunicorn_workers × (DB_POOL_SIZE + DB_MAX_OVERFLOW)`.
With defaults and 4 workers that is up to 40 connections per task — keep the sum
under the RDS instance's `max_connections`, or lower the pool vars for small
instance classes.

## Local development

```bash
pip install -r requirements.txt

# SQLite fallback (no DB_HOST set)
alembic upgrade head        # create schema
flask --app app seed        # insert baseline products
flask --app app run --port 5000
```

## Migrations

```bash
# Apply all migrations (run once per deploy, before traffic shifts)
alembic upgrade head

# Autogenerate a new migration after changing models.py
alembic revision --autogenerate -m "describe change"
```

On ECS, run `alembic upgrade head` as a **one-off task** (or a CI step) before
the blue/green cut-over — never on every container start, which would race
across tasks. The Gunicorn `CMD` intentionally only serves traffic.

Seeding is idempotent (`flask --app app seed` is a no-op if products exist) and
should also be run as a one-off task after the first migration.
