"""SQLAlchemy column types (cross-dialect)."""

from sqlalchemy import BigInteger, Integer


def bigint_primary_key():
    """SQLite autoincrement works reliably with INTEGER PK; keep BIGINT on PostgreSQL."""
    return BigInteger().with_variant(Integer, "sqlite")
