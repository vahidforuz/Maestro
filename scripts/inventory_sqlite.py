"""Read-only inventory of candidate legacy databases before an import plan.

Prints table counts and a file fingerprint, never row contents. Run while the
legacy application is stopped so its database file stays stable during hashing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCES = (
    ROOT / "data/music_school.db",
    ROOT / "maestro-api/data/music_school.db",
    ROOT / "maestro-desktop/data/music_school.db",
)


def inspect(source: Path) -> dict:
    source = source.resolve(strict=True)
    if not source.is_file():
        raise ValueError(f"Not a database file: {source}")
    digest = hashlib.sha256()
    with source.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    # URI mode=ro and query_only guard against accidental writes. No ATTACH.
    connection = sqlite3.connect(source.as_uri() + "?mode=ro", uri=True)
    try:
        connection.execute("pragma query_only = on")
        tables = [row[0] for row in connection.execute(
            "select name from sqlite_master where type = 'table' "
            "and name not like 'sqlite_%' order by name"
        )]
        counts = {}
        for table in tables:
            quoted = '"' + table.replace('"', '""') + '"'
            counts[table] = connection.execute(
                f"select count(*) from {quoted}"
            ).fetchone()[0]
        integrity = connection.execute("pragma integrity_check").fetchone()[0]
        foreign_key_violations = len(connection.execute(
            "pragma foreign_key_check"
        ).fetchall())
    finally:
        connection.close()
    return {
        "source": str(source),
        "sha256": digest.hexdigest(),
        "bytes": source.stat().st_size,
        "tables": counts,
        "integrity_check": integrity,
        "foreign_key_violations": foreign_key_violations,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", nargs="*", type=Path,
                        help="SQLite files; defaults to the three known candidates")
    args = parser.parse_args()
    sources = args.sources or DEFAULT_SOURCES
    print(json.dumps([inspect(source) for source in sources], indent=2))


if __name__ == "__main__":
    main()
