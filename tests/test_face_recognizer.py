import numpy as np

from meridian_hub.face.recognizer import FaceRecognizer


class _FakeFace:
    def __init__(self, bbox, kps, embedding, det_score):
        self.bbox = np.array(bbox)
        self.kps = np.array(kps)
        self.normed_embedding = np.array(embedding)
        self.det_score = det_score


class _FakeApp:
    def __init__(self, faces_to_return=None, fail_on_get=False):
        self._faces = faces_to_return or []
        self.prepared = False
        self._fail_on_get = fail_on_get

    def prepare(self, ctx_id, det_size):
        self.prepared = True

    def get(self, frame):
        if self._fail_on_get:
            raise RuntimeError("RUNTIME_EXCEPTION: Reshape node failed (simulated DirectML failure)")
        return self._faces


def _fake_factory(faces):
    def factory(model_pack, providers):
        return _FakeApp(faces)
    return factory


def test_converts_insightface_faces_to_face_detections():
    faces = [_FakeFace(
        bbox=[10.0, 20.0, 110.0, 120.0],
        kps=[[40, 50], [80, 50], [60, 70], [45, 90], [75, 90]],
        embedding=[0.1] * 512,
        det_score=0.95,
    )]
    recognizer = FaceRecognizer(app_factory=_fake_factory(faces))
    detections = recognizer.detect_and_embed(np.zeros((200, 200, 3), dtype=np.uint8))
    assert len(detections) == 1
    d = detections[0]
    assert d.bbox == (10.0, 20.0, 110.0, 120.0)
    assert len(d.landmarks) == 5
    assert len(d.embedding) == 512
    assert d.det_score == 0.95


def test_no_faces_returns_empty_list():
    recognizer = FaceRecognizer(app_factory=_fake_factory([]))
    detections = recognizer.detect_and_embed(np.zeros((200, 200, 3), dtype=np.uint8))
    assert detections == []


def test_falls_back_to_cpu_when_preferred_provider_fails(caplog):
    call_count = {"n": 0}

    def factory(model_pack, providers):
        call_count["n"] += 1
        if providers[0] != "CPUExecutionProvider":
            raise RuntimeError("no DirectML device")
        return _FakeApp([])

    with caplog.at_level("WARNING"):
        recognizer = FaceRecognizer(preferred_provider="directml", app_factory=factory)
    assert recognizer.active_provider == "cpu"
    assert "falling back to CPUExecutionProvider" in caplog.text


def test_defaults_to_cpu_provider():
    recognizer = FaceRecognizer(app_factory=_fake_factory([]))
    assert recognizer.active_provider == "cpu"


def test_recovers_when_inference_fails_after_successful_construction(caplog):
    """The exact real bug found by tools/smoke_test_face_video.py: session
    construction succeeds under DirectML, but the first real forward pass
    throws. Construction-time try/except can't catch this -- detect_and_embed
    itself must recover."""
    apps_created = []

    def factory(model_pack, providers):
        # First call (directml) returns an app that fails on .get(); the
        # rebuild call (cpu-only, triggered by the runtime failure) returns
        # a working one.
        fail = providers[0] != "CPUExecutionProvider"
        app = _FakeApp(faces_to_return=[], fail_on_get=fail)
        apps_created.append(app)
        return app

    with caplog.at_level("WARNING"):
        recognizer = FaceRecognizer(preferred_provider="directml", app_factory=factory)
        assert recognizer.active_provider == "directml"  # construction succeeded
        detections = recognizer.detect_and_embed(np.zeros((10, 10, 3), dtype=np.uint8))

    assert detections == []  # recovered, didn't raise
    assert recognizer.active_provider == "cpu"
    assert "Rebuilding on CPUExecutionProvider" in caplog.text
    assert len(apps_created) == 2  # original directml app + the CPU rebuild
