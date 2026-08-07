import sqlite3
from dataclasses import dataclass, fields


@dataclass
class CameraRecord:
    camera_id: str
    facility_id: str
    building_id: str
    floor_id: str
    room_id: str
    resident_id: str | None
    source: str
    privacy_state: str


class CameraRegistry:
    """PRD section 15.1: camera_id -> facility/building/floor/room/resident
    mapping. SQLite-backed for the POC."""

    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(db_path)
        self._conn.execute(
            """CREATE TABLE IF NOT EXISTS cameras (
                camera_id TEXT PRIMARY KEY, facility_id TEXT, building_id TEXT,
                floor_id TEXT, room_id TEXT, resident_id TEXT,
                source TEXT, privacy_state TEXT
            )"""
        )
        self._conn.commit()

    def register(self, record: CameraRecord) -> None:
        cols = [f.name for f in fields(CameraRecord)]
        placeholders = ", ".join("?" for _ in cols)
        values = [getattr(record, c) for c in cols]
        self._conn.execute(
            f"INSERT INTO cameras ({', '.join(cols)}) VALUES ({placeholders}) "
            f"ON CONFLICT(camera_id) DO UPDATE SET "
            + ", ".join(f"{c}=excluded.{c}" for c in cols if c != "camera_id"),
            values,
        )
        self._conn.commit()

    def get(self, camera_id: str) -> CameraRecord | None:
        row = self._conn.execute(
            "SELECT camera_id, facility_id, building_id, floor_id, room_id, "
            "resident_id, source, privacy_state FROM cameras WHERE camera_id = ?",
            (camera_id,),
        ).fetchone()
        return CameraRecord(*row) if row else None

    def list_all(self) -> list[CameraRecord]:
        rows = self._conn.execute(
            "SELECT camera_id, facility_id, building_id, floor_id, room_id, "
            "resident_id, source, privacy_state FROM cameras"
        ).fetchall()
        return [CameraRecord(*row) for row in rows]

    def close(self) -> None:
        """Release the SQLite handle for orderly process/test shutdown."""
        self._conn.close()
