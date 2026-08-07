"""Executable guards for the privacy, offline, latency, and multi-room deck claims."""
import ast
import builtins
import gc
import io
import json
import os
import socket
import weakref
from pathlib import Path

import cv2
import numpy as np
import pytest

from meridian_hub.alerting.notification_dispatcher import HttpResponse, NotificationDispatcher
from meridian_hub.capture.camera_registry import CameraRecord, CameraRegistry
from meridian_hub.events.event_engine import EventEngine
from meridian_hub.face.embedding_encryption import EmbeddingEncryptor
from meridian_hub.face.visitor_observation import build_visitor_observation
from meridian_hub.hub_daemon import HubDaemon
from meridian_hub.offline_queue.queue_store import QueueStore
from meridian_hub.vision.pose_types import KEYPOINT_NAMES, Keypoint, PersonDetection


class ScriptedEstimator:
    input_height = 256
    input_width = 320

    def __init__(self, frames):
        self._frames = iter(frames)

    def estimate(self, _prepared, _timestamp):
        return next(self._frames)


def _pose(t, *, fallen=False):
    points = [Keypoint(50, 100, .9) for _ in range(17)]
    if fallen:
        values = {"left_shoulder": (10, 145), "right_shoulder": (30, 145),
                  "left_hip": (70, 165), "right_hip": (90, 165),
                  "left_ankle": (60, 168), "right_ankle": (100, 168)}
        box = (10, 90, 90, 165)
    else:
        values = {"left_shoulder": (45, 40), "right_shoulder": (55, 40),
                  "left_hip": (45, 100), "right_hip": (55, 100),
                  "left_ankle": (40, 150), "right_ankle": (60, 150)}
        box = (30, 30, 70, 160)
    for name, (x, y) in values.items():
        points[KEYPOINT_NAMES.index(name)] = Keypoint(x, y, .9)
    return PersonDetection(points, box, .9, t)


def _daemon(frames, queue_path=":memory:"):
    registry = CameraRegistry(":memory:")
    for camera_id in ("cam-a", "cam-b"):
        registry.register(CameraRecord(camera_id, "fac", "bld", "floor", camera_id, "resident", "synthetic", "active"))
    queue = QueueStore(queue_path)
    return HubDaemon(ScriptedEstimator(frames), EventEngine(), queue, registry), queue, registry


def test_process_frame_cannot_write_image_or_open_network_connection(monkeypatch):
    daemon, queue, registry = _daemon([[]])
    writes, connections = [], []
    original_open = builtins.open
    original_os_open = os.open

    def guarded_open(file, mode="r", *args, **kwargs):
        if any(flag in mode for flag in ("w", "a", "x", "+")):
            writes.append(str(file))
            raise AssertionError(f"Frame processing attempted a filesystem write: {file}")
        return original_open(file, mode, *args, **kwargs)

    def guarded_connect(self, address):
        connections.append(address)
        raise AssertionError(f"Frame processing attempted an outbound network connection: {address}")

    def guarded_os_open(path, flags, *args, **kwargs):
        write_flags = os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND
        if flags & write_flags:
            writes.append(str(path))
            raise AssertionError(f"Frame processing attempted a filesystem write: {path}")
        return original_os_open(path, flags, *args, **kwargs)

    monkeypatch.setattr(builtins, "open", guarded_open)
    monkeypatch.setattr(io, "open", guarded_open)
    monkeypatch.setattr(os, "open", guarded_os_open)
    monkeypatch.setattr(socket.socket, "connect", guarded_connect)
    monkeypatch.setattr(cv2, "imwrite", lambda path, *_: pytest.fail(f"Frame processing attempted cv2.imwrite({path})"))
    daemon.process_frame("cam-a", np.zeros((20, 20, 3), dtype=np.uint8), 0.0)
    assert writes == []
    assert connections == []
    queue.close()
    registry.close()


def test_process_frame_does_not_retain_raw_pixel_array():
    daemon, queue, registry = _daemon([[]])
    frame = np.zeros((20, 20, 3), dtype=np.uint8)
    reference = weakref.ref(frame)
    daemon.process_frame("cam-a", frame, 0.0)
    del frame
    gc.collect()
    assert reference() is None, "HubDaemon retained a raw frame; it may retain only derived pose data"
    queue.close()
    registry.close()


def test_offline_event_survives_restart_then_delivers_exactly_once(tmp_path):
    db = tmp_path / "offline.sqlite3"
    daemon, queue, registry = _daemon([[_pose(0)], [_pose(.5, fallen=True)], [_pose(2.6, fallen=True)]], str(db))
    for t in (0.0, .5, 2.6):
        daemon.process_frame("cam-a", np.zeros((20, 20, 3), dtype=np.uint8), t)
    outage = NotificationDispatcher(queue, "https://backend.invalid", post_fn=lambda *_: (_ for _ in ()).throw(OSError("offline")))
    assert outage.dispatch_pending(2.6)[0].delivered is False
    queue.close()
    registry.close()

    restarted = QueueStore(str(db))
    received = []
    restored = NotificationDispatcher(restarted, "https://backend.invalid", post_fn=lambda _u, body, _h: (received.append(body["event_id"]) or HttpResponse(202, "ok")))
    assert [result.delivered for result in restored.dispatch_pending(10.0)] == [True]
    assert restored.dispatch_pending(10.0) == []
    assert len(received) == 1
    restarted.close()


def test_encrypted_outbound_observation_has_no_key_or_plaintext_embedding():
    key = b"K" * 32
    embedding = [0.111111, 0.222222, 0.333333]
    encrypted = EmbeddingEncryptor(key=key, key_id="facility-key-2026").encrypt(embedding)
    payload = build_visitor_observation(
        facility_id="fac", camera_id="entry", source_event_id="evt", detected_at=__import__("datetime").datetime(2026, 8, 7),
        match_status="unknown", quality_score=.9, match_confidence=None, encrypted=encrypted,
    ).model_dump(mode="json")
    serialized = json.dumps(payload, sort_keys=True)
    assert "KKKK" not in serialized and "0.111111" not in serialized and "0.222222" not in serialized
    assert payload["face_embedding_ciphertext"] and payload["face_embedding_algorithm"] == "AES-256-GCM"


def test_daemon_dependency_graph_excludes_third_party_visitor_photo_describer():
    root = Path(__file__).parents[1]
    modules = {}
    for path in (root / "meridian_hub").rglob("*.py"):
        module = ".".join(path.relative_to(root).with_suffix("").parts)
        tree = ast.parse(path.read_text(encoding="utf-8"))
        imports = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module:
                imports.add(node.module)
                imports.update(f"{node.module}.{alias.name}" for alias in node.names)
            elif isinstance(node, ast.Import):
                imports.update(alias.name for alias in node.names)
        modules[module] = imports
    reachable, pending = set(), ["meridian_hub.hub_daemon"]
    while pending:
        module = pending.pop()
        if module in reachable:
            continue
        reachable.add(module)
        pending.extend(item for item in modules.get(module, set()) if item in modules)
    assert "meridian_hub.face.body_description" not in reachable, "Daemon path must not depend on the Hack Club/Gemini visitor-photo describer"


def test_multi_camera_state_is_independent_and_camera_b_alerts_while_a_is_busy():
    frames = [[_pose(0)], [_pose(0)], [_pose(.5, fallen=True)]] + [[_pose(t)] for t in (.6, .7, .8, .9, 1.0)] + [[_pose(2.6, fallen=True)]]
    daemon, queue, registry = _daemon(frames)
    blank = np.zeros((20, 20, 3), dtype=np.uint8)
    assert daemon.process_frame("cam-a", blank, 0.0) == []
    assert daemon.process_frame("cam-b", blank, 0.0) == []
    assert daemon.process_frame("cam-b", blank, .5) == []
    for t in (.6, .7, .8, .9, 1.0):
        assert daemon.process_frame("cam-a", blank, t) == []
    events = daemon.process_frame("cam-b", blank, 2.6)
    assert len(events) == 1 and events[0].camera_id == "cam-b"
    assert set(daemon._trackers) == {"cam-a", "cam-b"}
    queue.close()
    registry.close()


def test_detection_threshold_contract_stays_within_five_second_deck_budget():
    # Sequence timestamps are the deterministic detection clock, not wall-clock
    # performance: this prevents a noisy CI host from weakening the safety claim.
    from tools.measure_alert_latency import run_once
    _, confirmed_seconds = run_once("confirmed")
    _, suspected_seconds = run_once("suspected")
    assert confirmed_seconds == pytest.approx(2.0)
    assert suspected_seconds == pytest.approx(3.1)
    assert max(confirmed_seconds, suspected_seconds) < 5.0
