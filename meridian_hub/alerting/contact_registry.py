import sqlite3
from dataclasses import dataclass, fields


@dataclass(frozen=True)
class Contact:
    contact_id: str
    resident_id: str
    phone_number: str
    role: str  # "caregiver" | "emergency_contact" | "family"
    priority: int  # lower contacted first


class ContactRegistry:
    """SQLite-backed caregiver/emergency-contact directory per resident,
    used to resolve who to SMS when an alert fires. Kept local to the
    Hub for this POC -- a real deployment would sync this from the
    facility's backend, but the Hub still needs a local copy so alerting
    keeps working if connectivity to the backend drops (same offline-
    first principle as the rest of this codebase)."""

    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(db_path)
        self._conn.execute(
            """CREATE TABLE IF NOT EXISTS contacts (
                contact_id TEXT PRIMARY KEY, resident_id TEXT,
                phone_number TEXT, role TEXT, priority INTEGER
            )"""
        )
        self._conn.commit()

    def add_contact(self, contact: Contact) -> None:
        cols = [f.name for f in fields(Contact)]
        placeholders = ", ".join("?" for _ in cols)
        values = [getattr(contact, c) for c in cols]
        self._conn.execute(
            f"INSERT INTO contacts ({', '.join(cols)}) VALUES ({placeholders}) "
            f"ON CONFLICT(contact_id) DO UPDATE SET "
            + ", ".join(f"{c}=excluded.{c}" for c in cols if c != "contact_id"),
            values,
        )
        self._conn.commit()

    def contacts_for_resident(self, resident_id: str) -> list[Contact]:
        rows = self._conn.execute(
            "SELECT contact_id, resident_id, phone_number, role, priority "
            "FROM contacts WHERE resident_id = ? ORDER BY priority",
            (resident_id,),
        ).fetchall()
        return [Contact(*row) for row in rows]
