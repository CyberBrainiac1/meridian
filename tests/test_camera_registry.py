import tempfile
from pathlib import Path

from meridian_hub.capture.camera_registry import CameraRegistry, CameraRecord


def _registry():
    db_path = Path(tempfile.mkdtemp()) / "registry.sqlite3"
    return CameraRegistry(db_path=str(db_path))


def test_register_and_lookup():
    registry = _registry()
    record = CameraRecord(
        camera_id="cam-101", facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-101", resident_id="res-9",
        source="0", privacy_state="active",
    )
    registry.register(record)
    fetched = registry.get("cam-101")
    assert fetched.room_id == "room-101"
    assert fetched.resident_id == "res-9"


def test_lookup_missing_returns_none():
    registry = _registry()
    assert registry.get("does-not-exist") is None


def test_register_upserts_existing():
    registry = _registry()
    registry.register(CameraRecord(
        camera_id="cam-1", facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id=None,
        source="0", privacy_state="active",
    ))
    registry.register(CameraRecord(
        camera_id="cam-1", facility_id="fac-1", building_id="bld-1",
        floor_id="flr-1", room_id="room-1", resident_id="res-42",
        source="0", privacy_state="active",
    ))
    assert registry.get("cam-1").resident_id == "res-42"
    assert len(registry.list_all()) == 1
