class InferenceScheduler:
    """Allocate shared inference capacity across camera streams.

    Normal operation is fair round-robin. When a camera has an active
    incident, it is interleaved into every other scheduling tick so it gets
    more attention without starving the rest of the facility.
    """

    def __init__(self, camera_ids: list[str]):
        self._camera_ids = list(camera_ids)
        self._priority: set[str] = set()
        self._rotation_index = 0
        self._priority_index = 0
        self._tick = 0

    def set_priority(self, camera_id: str, active: bool) -> None:
        if camera_id not in self._camera_ids:
            return
        if active:
            self._priority.add(camera_id)
        else:
            self._priority.discard(camera_id)

    def next_camera(self) -> str | None:
        if not self._camera_ids:
            return None

        priority_list = [camera_id for camera_id in self._camera_ids if camera_id in self._priority]
        use_priority = bool(priority_list) and self._tick % 2 == 0
        self._tick += 1

        if use_priority:
            camera_id = priority_list[self._priority_index % len(priority_list)]
            self._priority_index += 1
            return camera_id

        camera_id = self._camera_ids[self._rotation_index % len(self._camera_ids)]
        self._rotation_index += 1
        return camera_id
