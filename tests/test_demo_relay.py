from meridian_hub.demo_relay import DemoPoseRelay, _serialize
from meridian_hub.vision.pose_types import Keypoint, PersonDetection, KEYPOINT_NAMES


def _detection():
    kpts = [Keypoint(x=float(i), y=float(i) * 2, confidence=0.9) for i in range(17)]
    return PersonDetection(keypoints=kpts, bbox=(1.0, 2.0, 3.0, 4.0), confidence=0.87, timestamp=1.0)


def test_serialize_shape():
    payload = _serialize("cam-demo", 123.456, [_detection()])

    assert payload["camera_id"] == "cam-demo"
    assert payload["timestamp"] == 123.456
    assert len(payload["people"]) == 1

    person = payload["people"][0]
    assert person["confidence"] == 0.87
    assert person["bbox"] == [1.0, 2.0, 3.0, 4.0]
    assert len(person["keypoints"]) == 17
    assert person["keypoints"][0]["name"] == KEYPOINT_NAMES[0]
    assert person["keypoints"][0]["x"] == 0.0


def test_serialize_no_people():
    payload = _serialize("cam-demo", 1.0, [])
    assert payload["people"] == []


def test_broadcast_is_noop_without_clients():
    # Relay never started -- broadcast() must not raise, just do nothing.
    relay = DemoPoseRelay()
    relay.broadcast("cam-demo", [_detection()], 1.0)
