import logging
from collections.abc import Callable

import numpy as np

from meridian_hub.face.face_types import FaceDetection

logger = logging.getLogger(__name__)


class FaceRecognizer:
    """Wraps InsightFace's FaceAnalysis (SCRFD/RetinaFace detector +
    ArcFace recognizer, bundled in the buffalo_s model pack) and converts
    its Face objects to our own FaceDetection immediately, so nothing
    downstream depends on the InsightFace library directly.
    app_factory is injectable so tests never need real model weights."""

    def __init__(
        self, model_pack: str = "buffalo_s", det_size: tuple[int, int] = (320, 320),
        preferred_provider: str = "cpu",
        app_factory: Callable[[str, list[str]], object] | None = None,
    ):
        # Default is "cpu", not "directml" -- unlike our own exported pose
        # model (which DirectML runs fine, see benchmarks/), InsightFace's
        # bundled SCRFD detector throws a RUNTIME_EXCEPTION on a Reshape
        # node under DmlExecutionProvider on this GPU/driver, confirmed by
        # actually running it against real video (tools/smoke_test_face_video.py),
        # not assumed. The failure happens at inference time, not session
        # construction, so the try/except below alone can't catch it --
        # detect_and_embed() has its own runtime fallback for defense in
        # depth, but the safe default avoids hitting that path at all.
        self._model_pack = model_pack
        self._det_size = det_size
        provider_map = {"directml": "DmlExecutionProvider", "cpu": "CPUExecutionProvider"}
        preferred = provider_map.get(preferred_provider, "CPUExecutionProvider")

        self._app_factory = app_factory or self._default_app_factory
        try:
            self._app = self._app_factory(model_pack, [preferred, "CPUExecutionProvider"])
            self.active_provider = preferred_provider
        except Exception:
            logger.warning(
                "Failed to initialize FaceAnalysis with %s, falling back to CPUExecutionProvider.",
                preferred,
            )
            self._app = self._app_factory(model_pack, ["CPUExecutionProvider"])
            self.active_provider = "cpu"

        self._app.prepare(ctx_id=0, det_size=det_size)

    @staticmethod
    def _default_app_factory(model_pack: str, providers: list[str]):
        from insightface.app import FaceAnalysis
        return FaceAnalysis(name=model_pack, providers=providers)

    def detect_and_embed(self, frame: np.ndarray) -> list[FaceDetection]:
        try:
            faces = self._app.get(frame)
        except Exception:
            if self.active_provider == "cpu":
                raise  # already on CPU, nothing left to fall back to
            logger.warning(
                "FaceAnalysis inference failed on %s (construction succeeded but a real "
                "forward pass didn't -- this is the exact failure mode session-construction "
                "checks can't catch). Rebuilding on CPUExecutionProvider and retrying this frame.",
                self.active_provider,
            )
            self._app = self._app_factory(self._model_pack, ["CPUExecutionProvider"])
            self.active_provider = "cpu"
            self._app.prepare(ctx_id=0, det_size=self._det_size)
            faces = self._app.get(frame)

        results = []
        for face in faces:
            x1, y1, x2, y2 = face.bbox
            landmarks = [(float(p[0]), float(p[1])) for p in face.kps]
            embedding = face.normed_embedding.tolist()
            # buffalo_s bundles a genderage model (see the "find model"
            # log line at startup) -- InsightFace's convention is
            # gender=0 female, gender=1 male. These are population-level
            # estimates for a human-readable description, never treated
            # as identity or a medical/demographic claim.
            age = getattr(face, "age", None)
            gender_raw = getattr(face, "gender", None)
            gender = {0: "female", 1: "male"}.get(gender_raw)
            results.append(FaceDetection(
                bbox=(float(x1), float(y1), float(x2), float(y2)),
                landmarks=landmarks, embedding=embedding, det_score=float(face.det_score),
                estimated_age=int(age) if age is not None else None,
                estimated_gender=gender,
            ))
        return results
