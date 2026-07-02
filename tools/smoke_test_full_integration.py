"""Full end-to-end integration smoke test: real components, real data,
the entire chain wired together the way the live Hub would run it.

Chain 1 (visitor): real video frame -> InsightFace detect+embed+age/gender
  -> quality gate -> encrypt embedding AND face crop -> build the exact
  Supabase visitor-observation payload -> prove it round-trips and leaks
  no plaintext -> generate the caregiver-facing person description.

Chain 2 (fall -> alert): synthetic fall sequence -> HubDaemon full
  pipeline (pose->track->features->state machine->validator->event) ->
  canonical PRD event -> resident-first alert copy -> SMS dispatch
  (dry-run unless --send).

This is the "is EVERYTHING actually working together" check, not a unit
test -- it uses the real model files, real AES-GCM, real pydantic
schemas, and the real event engine, end to end.
"""
import argparse
import os
from datetime import datetime, timezone

import cv2
import numpy as np

from meridian_hub.alerting.alert_formatter import format_alert_message
from meridian_hub.capture.camera_registry import CameraRecord, CameraRegistry
from meridian_hub.events.event_engine import EventEngine
from meridian_hub.face.embedding_encryption import EmbeddingEncryptor
from meridian_hub.face.detector import select_best_detection, score_detection
from meridian_hub.face.person_description import describe_person
from meridian_hub.face.recognizer import FaceRecognizer
from meridian_hub.face.visitor_observation import build_visitor_observation
from meridian_hub.face.visitor_store import VisitorStore
from meridian_hub.hub_daemon import HubDaemon
from meridian_hub.offline_queue.queue_store import QueueStore
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES


def _load_env():
    if not os.path.exists(".env"):
        return
    with open(".env") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k, v)


PASS = "\033[92mPASS\033[0m"
FAIL = "\033[91mFAIL\033[0m"
results = []


def check(name, condition):
    results.append((name, condition))
    print(f"  [{PASS if condition else FAIL}] {name}")
    return condition


def chain1_visitor(face_video):
    print("\n=== CHAIN 1: visitor face -> encrypt -> Supabase observation payload ===")
    recognizer = FaceRecognizer()
    cap = cv2.VideoCapture(face_video)
    best_frame, best_detection = None, None
    for _ in range(200):
        ok, frame = cap.read()
        if not ok:
            break
        dets = recognizer.detect_and_embed(frame)
        chosen = select_best_detection(frame, dets)
        if chosen is not None:
            best_frame, best_detection = frame, chosen
            break
    cap.release()

    if not check("a real quality-gated face was found in the video", best_detection is not None):
        return
    check("embedding is a real 512-d ArcFace vector", len(best_detection.embedding) == 512)

    store = VisitorStore(db_path=":memory:")
    match = store.match(best_detection.embedding, threshold=0.5)
    check("unrecognized visitor correctly reports no match", match.person_id is None)

    encryptor = EmbeddingEncryptor.from_env()
    enc_embedding = encryptor.encrypt(best_detection.embedding)
    # encode the real face crop as jpeg bytes and encrypt it
    x1, y1, x2, y2 = (int(v) for v in best_detection.bbox)
    crop = best_frame[max(y1, 0):y2, max(x1, 0):x2]
    ok, jpeg = cv2.imencode(".jpg", crop)
    enc_image = encryptor.encrypt_image(jpeg.tobytes())

    check("embedding round-trips through decrypt", encryptor.decrypt(enc_embedding) == best_detection.embedding)
    check("face image round-trips through decrypt", encryptor.decrypt_image(enc_image) == jpeg.tobytes())

    obs = build_visitor_observation(
        facility_id="fac-poc-001", camera_id="cam-entry-1", source_event_id="evt-visitor-001",
        detected_at=datetime.now(timezone.utc), match_status="unknown",
        quality_score=score_detection(best_frame, best_detection).sharpness,
        match_confidence=match.similarity, encrypted=enc_embedding, encrypted_image=enc_image,
    )
    payload = obs.model_dump(mode="json")
    serialized = str(payload)
    check("payload has encrypted embedding ciphertext", bool(payload["face_embedding_ciphertext"]))
    check("payload has encrypted face image ciphertext", bool(payload["face_image_ciphertext"]))
    # prove no raw embedding float leaked into the outgoing payload
    leaked = any(f"{v:.5f}" in serialized for v in best_detection.embedding[:20])
    check("NO plaintext embedding values in the outgoing payload", not leaked)

    description = describe_person(best_detection)
    print(f"      person description for caregiver: \"An unrecognized visitor arrived: {description}\"")
    check("person description is non-empty", bool(description))


def _standing(t):
    kp = [Keypoint(50, 50, 0.9) for _ in range(17)]
    kp[KEYPOINT_NAMES.index("left_hip")] = Keypoint(45, 100, 0.9)
    kp[KEYPOINT_NAMES.index("right_hip")] = Keypoint(55, 100, 0.9)
    kp[KEYPOINT_NAMES.index("left_shoulder")] = Keypoint(45, 40, 0.9)
    kp[KEYPOINT_NAMES.index("right_shoulder")] = Keypoint(55, 40, 0.9)
    kp[KEYPOINT_NAMES.index("left_ankle")] = Keypoint(40, 150, 0.9)
    kp[KEYPOINT_NAMES.index("right_ankle")] = Keypoint(60, 150, 0.9)
    return [PersonDetection(keypoints=kp, bbox=(30, 30, 70, 160), confidence=0.9, timestamp=t)]


def _fallen(t):
    kp = [Keypoint(50, 150, 0.9) for _ in range(17)]
    kp[KEYPOINT_NAMES.index("left_shoulder")] = Keypoint(10, 145, 0.9)
    kp[KEYPOINT_NAMES.index("right_shoulder")] = Keypoint(30, 145, 0.9)
    kp[KEYPOINT_NAMES.index("left_hip")] = Keypoint(70, 165, 0.9)
    kp[KEYPOINT_NAMES.index("right_hip")] = Keypoint(90, 165, 0.9)
    kp[KEYPOINT_NAMES.index("left_ankle")] = Keypoint(60, 168, 0.9)
    kp[KEYPOINT_NAMES.index("right_ankle")] = Keypoint(100, 168, 0.9)
    return [PersonDetection(keypoints=kp, bbox=(10, 90, 90, 165), confidence=0.9, timestamp=t)]


class _ScriptedEstimator:
    input_height, input_width = 256, 320

    def __init__(self, seq):
        self._seq = iter(seq)

    def estimate(self, frame, ts):
        return next(self._seq)


def chain2_fall_to_alert(send, to_number):
    print("\n=== CHAIN 2: fall detected -> event -> alert copy -> SMS ===")
    registry = CameraRegistry(db_path=":memory:")
    registry.register(CameraRecord(
        camera_id="cam-1", facility_id="fac-1", building_id="bld-1", floor_id="flr-1",
        room_id="room-12", resident_id="res-maggie", source="0", privacy_state="active",
    ))
    daemon = HubDaemon(
        pose_estimator=_ScriptedEstimator([_standing(0.0), _fallen(0.5), _fallen(2.6)]),
        event_engine=EventEngine(), queue_store=QueueStore(db_path=":memory:"),
        camera_registry=registry,
    )
    frame = np.zeros((10, 10, 3), dtype=np.uint8)
    events = []
    for t in [0.0, 0.5, 2.6]:
        events += daemon.process_frame("cam-1", frame, t)

    check("a fall_confirmed event was produced", any(e.event_type == "fall_confirmed" for e in events))
    event = events[0]
    check("event maps to the correct room/resident", event.room_id == "room-12" and event.resident_id == "res-maggie")
    check("event matches PRD schema (schema_version 1.0)", event.schema_version == "1.0")

    message = format_alert_message(event, resident_display_name="Maggie")
    print(f"      caregiver alert copy: \"{message}\"")
    check("alert copy is resident-first (no event ID jargon)", "evt" not in message and "Maggie" in message)

    if send and to_number:
        from meridian_hub.alerting.sms_dispatcher import SmsAlertDispatcher
        dispatcher = SmsAlertDispatcher.from_env()
        # Trial accounts require a predefined template name as the body.
        sms_results = dispatcher.send_alert([to_number], "sms_appointment_reminders")
        for r in sms_results:
            print(f"      SMS to {r.to}: success={r.success} sid={r.message_sid} error={r.error}")
        check("SMS actually sent via Twilio", all(r.success for r in sms_results))
    else:
        print("      (SMS dry-run -- pass --send --to +1XXXXXXXXXX to actually send)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--face-video", default="tests/fixtures/videos/head-pose-face-detection-female.mp4")
    parser.add_argument("--send", action="store_true")
    parser.add_argument("--to", default=None)
    args = parser.parse_args()

    _load_env()
    chain1_visitor(args.face_video)
    chain2_fall_to_alert(args.send, args.to)

    passed = sum(1 for _, c in results if c)
    print(f"\n=== {passed}/{len(results)} end-to-end checks passed ===")
    if passed != len(results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
