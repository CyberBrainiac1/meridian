"""Local pose-keypoint relay for live pitch demos only (PRD section 12.4 /
frontend spec section 5: "show the judges the skeleton view"). Broadcasts
the same PersonDetection keypoints HubDaemon.process_frame() already
computes to any connected local WebSocket client, purely as an observer --
it has zero effect on capture, pose estimation, tracking, fall detection,
or event emission, and is entirely optional (HubDaemon only calls it if one
is explicitly attached at construction).

This does not change what Sense/Hub sends upstream to Supabase -- that
contract (skeleton-only, never raw video, per docs/meridian-sense-
integration-prd.md) is untouched. This relay is a same-machine, demo-only
side channel: a laptop running the Hub during a pitch, with a browser tab
on the same machine/LAN connected to ws://localhost:8765/ws/pose.

Message shape (one JSON object per processed frame with >=1 person):
    {
        "camera_id": "cam-demo",
        "timestamp": 1720999999.123,
        "people": [
            {
                "confidence": 0.92,
                "bbox": [x1, y1, x2, y2],
                "keypoints": [
                    {"name": "nose", "x": 120.4, "y": 80.1, "confidence": 0.95},
                    ...  # COCO-17 order, meridian_hub.vision.pose_types.KEYPOINT_NAMES
                ]
            }
        ]
    }
"""

from __future__ import annotations

import asyncio
import threading
import time

from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from meridian_hub.vision.pose_types import KEYPOINT_NAMES, PersonDetection


def _port_in_use(host: str, port: int) -> bool:
    import socket

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind((host, port))
            return False
        except OSError:
            return True


def _serialize(camera_id: str, timestamp: float, detections: list[PersonDetection]) -> dict:
    return {
        "camera_id": camera_id,
        "timestamp": timestamp,
        "people": [
            {
                "confidence": person.confidence,
                "bbox": list(person.bbox),
                "keypoints": [
                    {"name": name, "x": kp.x, "y": kp.y, "confidence": kp.confidence}
                    for name, kp in zip(KEYPOINT_NAMES, person.keypoints)
                ],
            }
            for person in detections
        ],
    }


class DemoPoseRelay:
    """Runs a small FastAPI/uvicorn WebSocket server on a background
    thread with its own asyncio event loop, so broadcast() can be called
    synchronously from HubDaemon's synchronous process_frame() without
    blocking the capture loop."""

    def __init__(self, host: str = "127.0.0.1", port: int = 8765):
        self._host = host
        self._port = port
        self._app = FastAPI()
        self._clients: set[WebSocket] = set()
        self._loop: asyncio.AbstractEventLoop | None = None
        self._thread: threading.Thread | None = None
        self._server = None  # uvicorn.Server, kept so stop() can shut it down cleanly

        @self._app.websocket("/ws/pose")
        async def pose_ws(websocket: WebSocket):
            await websocket.accept()
            self._clients.add(websocket)
            try:
                while True:
                    # Demo clients don't send anything; just hold the
                    # connection open until they disconnect.
                    await websocket.receive_text()
            except WebSocketDisconnect:
                pass
            finally:
                self._clients.discard(websocket)

    def start(self, wait_seconds: float = 5.0) -> bool:
        """Start the WebSocket server. Returns True once it's actually
        serving, False if it failed to come up within wait_seconds (almost
        always: the port is already in use from a prior run). Callers
        should check the return value and surface a clear message instead
        of assuming the skeleton view is live -- a silently-dead relay is
        worse than a loud failure on stage."""
        if self._thread is not None:
            return self.is_serving()

        # Pre-flight: if the port is already taken, fail cleanly and
        # immediately instead of letting uvicorn's background thread throw
        # a bind traceback across the demo terminal.
        if _port_in_use(self._host, self._port):
            return False

        ready = threading.Event()

        def _run():
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            self._loop = loop
            ready.set()
            loop.run_forever()

        self._thread = threading.Thread(target=_run, daemon=True, name="demo-pose-relay")
        self._thread.start()
        ready.wait()

        import uvicorn

        config = uvicorn.Config(self._app, host=self._host, port=self._port, log_level="error", loop="asyncio")
        self._server = uvicorn.Server(config)
        asyncio.run_coroutine_threadsafe(self._server.serve(), self._loop)

        # Poll until uvicorn reports it's actually serving, or a startup
        # error terminates it (e.g. the port is taken).
        deadline = time.monotonic() + wait_seconds
        while time.monotonic() < deadline:
            if getattr(self._server, "started", False):
                return True
            if getattr(self._server, "should_exit", False):
                break
            time.sleep(0.05)
        return self.is_serving()

    def is_serving(self) -> bool:
        return bool(self._server is not None and getattr(self._server, "started", False))

    def stop(self) -> None:
        """Cleanly release the port so the relay can be restarted (e.g.
        Ctrl+C then re-run the demo) without a 'port already in use' bind
        failure on the next start."""
        if self._server is not None:
            # Tell uvicorn to shut down; it closes the listening socket.
            self._server.should_exit = True
            deadline = time.monotonic() + 3.0
            while time.monotonic() < deadline and getattr(self._server, "started", False):
                time.sleep(0.05)
        if self._loop is not None:
            self._loop.call_soon_threadsafe(self._loop.stop)
        if self._thread is not None:
            self._thread.join(timeout=3.0)
        self._server = None
        self._thread = None
        self._loop = None

    def broadcast(self, camera_id: str, detections: list[PersonDetection], timestamp: float) -> None:
        """Sync entry point -- safe to call directly from
        HubDaemon.process_frame(). No-op if the relay isn't running yet or
        no demo client is connected."""
        if self._loop is None or not self._clients:
            return
        payload = _serialize(camera_id, timestamp, detections)
        asyncio.run_coroutine_threadsafe(self._broadcast_async(payload), self._loop)

    async def _broadcast_async(self, payload: dict) -> None:
        stale: set[WebSocket] = set()
        for client in list(self._clients):
            try:
                await client.send_json(payload)
            except Exception:
                stale.add(client)
        self._clients -= stale
