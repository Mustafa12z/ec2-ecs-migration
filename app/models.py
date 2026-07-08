"""
Database layer: engine construction, connection-pool sizing, and ORM models.

Importing this module has NO side effects — it never connects to the database
or creates tables. Schema is owned by Alembic migrations; the engine/session
are constructed explicitly by the application factory (and by Alembic's env).
"""

import os
from datetime import datetime

from sqlalchemy import create_engine, String, Integer, Float, DateTime
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def get_database_url() -> str:
    """Build the SQLAlchemy URL from env, or fall back to local SQLite.

    In production, DB_* come from ECS-injected Secrets Manager values.
    """
    host = os.getenv("DB_HOST")
    if not host:
        return "sqlite:///local-dev.db"

    user = os.getenv("DB_USER", "appuser")
    password = os.getenv("DB_PASSWORD", "")
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("DB_NAME", "legacyapi")
    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{name}"


def _int_env(key: str, default: int) -> int:
    try:
        return int(os.getenv(key, str(default)))
    except (TypeError, ValueError):
        return default


def create_db_engine(url: str | None = None) -> Engine:
    """Create a configured Engine.

    Pool sizing matters on ECS: total connections =
        tasks x gunicorn_workers x (pool_size + max_overflow)
    Keep this under the RDS instance's max_connections. Defaults below give
    up to 10 connections per worker; tune via env for larger fleets.
    """
    url = url or get_database_url()
    kwargs: dict = {
        "pool_pre_ping": True,   # recycle connections dropped by RDS/NAT idle timeout
        "pool_recycle": 1800,
        "future": True,
    }

    # SQLite (local dev) doesn't use a real connection pool.
    if not url.startswith("sqlite"):
        kwargs.update(
            pool_size=_int_env("DB_POOL_SIZE", 5),
            max_overflow=_int_env("DB_MAX_OVERFLOW", 5),
            pool_timeout=_int_env("DB_POOL_TIMEOUT", 30),
        )

    return create_engine(url, **kwargs)


class Base(DeclarativeBase):
    pass


class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    price: Mapped[float] = mapped_column(Float, nullable=False)
    stock: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    def to_dict(self) -> dict:
        return {"id": self.id, "name": self.name, "price": self.price, "stock": self.stock}


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    product_id: Mapped[int] = mapped_column(Integer, nullable=False)
    product_name: Mapped[str] = mapped_column(String(255), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    total_price: Mapped[float] = mapped_column(Float, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "product_id": self.product_id,
            "product_name": self.product_name,
            "quantity": self.quantity,
            "total_price": self.total_price,
            "created_at": self.created_at.isoformat(),
        }


# Canonical seed data, used by the `flask seed` command.
SEED_PRODUCTS = [
    {"id": 1, "name": "Widget A", "price": 29.99, "stock": 100},
    {"id": 2, "name": "Widget B", "price": 39.99, "stock": 50},
    {"id": 3, "name": "Widget C", "price": 49.99, "stock": 75},
]
