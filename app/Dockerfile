FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# ---- build stage: install dependencies into an isolated prefix ----
FROM base AS builder

# Upgrade the packaging toolchain first: python:3.11-slim ships an old
# setuptools whose vendored jaraco.context/wheel copies carry known CVEs
# (e.g. CVE-2026-23949, CVE-2026-24049). Upgrading replaces those vendored
# copies even though nothing in requirements.txt depends on them directly.
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- runtime stage ----
FROM base AS runner

# Non-root user for the container process
RUN useradd --create-home --uid 10001 appuser

# Bring the runtime's own pip/setuptools/wheel up to the same patched
# versions (they ship separately from the /install prefix above).
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

COPY --from=builder /install /usr/local
COPY . .

# /app must be writable by appuser: the local-dev SQLite fallback (used when
# DB_HOST is unset) creates its file here.
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

# No --preload: the app factory builds a fresh engine per worker after fork,
# so each worker owns its own connection pool (no shared-fd corruption).
# Schema is applied out-of-band via `alembic upgrade head` (see README).
CMD ["gunicorn", "wsgi:app", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "4", \
     "--timeout", "60", \
     "--access-logfile", "-", \
     "--error-logfile", "-"]
