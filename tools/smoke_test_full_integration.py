"""Full end-to-end integration smoke test: real components, real data,
the entire chain wired together the way the live Hub would run it.

Chain 1 (visitor): real video frame -> InsightFace detect+embed+age/gender
  -> quality gate -> optional Hack Club AI body/clothing description
  -> encrypt embedding, face crop, and person photo -> build the exact
  Supabase visitor-observation payload -> prove it round-trips and leaks
  no plaintext -> generate the caregiver-facing person description.

Chain 2 (fall -> alert): synthetic fall sequence -> HubDaemon full
  pipeline (pose->track->features->state machine->validator->event) ->
  canonical PRD event -> resident-first alert copy -> app-notification
  delivery to the backend ingest endpoint (which fans out app push).

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
from meridian_hub.face.body_description import build_vision_describer
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
    ok, person_jpeg = cv2.imencode(".jpg", best_frame)
    if not check("full-frame person photo encoded as jpeg", ok):
        return
    person_photo_bytes = person_jpeg.tobytes()
    enc_person_photo = encryptor.encrypt_image(person_photo_bytes)

    body_description = None
    body_description_model = None
    body_description_generated_at = None
    describer = build_vision_describer()
    if describer is not None:
        # Best-effort: a vision outage/402 must not fail the visitor path.
        body_result = describer.try_describe_person_photo(person_photo_bytes)
        if body_result is not None:
            body_description = body_result.description
            body_description_model = body_result.model
            body_description_generated_at = body_result.generated_at
            print(f"      Vision body description ({body_description_model}): \"{body_description}\"")
            check("vision provider generated a body/clothing description", bool(body_description))
        else:
            print("      (vision unavailable -- degraded gracefully, visitor path still works)")
    else:
        print("      (vision skipped -- neither GEMINI_API_KEY nor HACKCLUB_AI_API_KEY is set)")

    check("embedding round-trips through decrypt", encryptor.decrypt(enc_embedding) == best_detection.embedding)
    check("face image round-trips through decrypt", encryptor.decrypt_image(enc_image) == jpeg.tobytes())
    check(
        "person photo round-trips through decrypt",
        encryptor.decrypt_image(enc_person_photo) == person_photo_bytes,
    )

    obs = build_visitor_observation(
        facility_id="fac-poc-001", camera_id="cam-entry-1", source_event_id="evt-visitor-001",
        detected_at=datetime.now(timezone.utc), match_status="unknown",
        quality_score=score_detection(best_frame, best_detection).sharpness,
        match_confidence=match.similarity, encrypted=enc_embedding, encrypted_image=enc_image,
        body_description=body_description,
        body_description_model=body_description_model,
        body_description_generated_at=body_description_generated_at,
        encrypted_person_photo=enc_person_photo,
    )
    payload = obs.model_dump(mode="json")
    serialized = str(payload)
    check("payload has encrypted embedding ciphertext", bool(payload["face_embedding_ciphertext"]))
    check("payload has encrypted face image ciphertext", bool(payload["face_image_ciphertext"]))
    check("payload has encrypted person photo ciphertext", bool(payload["person_photo_ciphertext"]))
    if body_description is not None:
        check("payload includes Hack Club body description", payload["body_description"] == body_description)
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


def chain2_fall_to_alert():
    print("\n=== CHAIN 2: fall detected -> event -> alert copy -> app notification delivery ===")
    registry = CameraRegistry(db_path=":memory:")
    registry.register(CameraRecord(
        camera_id="cam-1", facility_id="fac-1", building_id="bld-1", floor_id="flr-1",
        room_id="room-12", resident_id="res-maggie", source="0", privacy_state="active",
    ))
    queue = QueueStore(db_path=":memory:")
    daemon = HubDaemon(
        pose_estimator=_ScriptedEstimator([_standing(0.0), _fallen(0.5), _fallen(2.6)]),
        event_engine=EventEngine(), queue_store=queue,
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

    # App-notification delivery: the Hub hands the event to the backend
    # ingest endpoint (which fans out app push via notify-family). Prove
    # the queued event is delivered end-to-end against a fake backend that
    # captures exactly what the real ingest-event endpoint would receive.
    from meridian_hub.alerting.notification_dispatcher import HttpResponse, NotificationDispatcher
    captured = []

    def fake_backend(url, body, headers):
        captured.append(body)
        return HttpResponse(status_code=200, text="accepted")

    dispatcher = NotificationDispatcher(queue, "https://backend/ingest-event", post_fn=fake_backend)
    delivery = dispatcher.dispatch_pending(now=0.0)
    check("the alert event was delivered to the backend for app push", any(d.delivered for d in delivery))
    check("delivered payload carries the fall_confirmed event", any(c.get("event_type") == "fall_confirmed" for c in captured))
    check("queue is drained after successful delivery (offline-first ack)", queue.pending(now=0.0) == [])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--face-video", default="tests/fixtures/videos/head-pose-face-detection-female.mp4")
    args = parser.parse_args()

    _load_env()
    chain1_visitor(args.face_video)
    chain2_fall_to_alert()

    passed = sum(1 for _, c in results if c)
    print(f"\n=== {passed}/{len(results)} end-to-end checks passed ===")
    if passed != len(results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
