from meridian_hub.scheduler.inference_scheduler import InferenceScheduler


def test_plain_round_robin_with_no_priority():
    scheduler = InferenceScheduler(camera_ids=["cam-1", "cam-2", "cam-3"])

    picks = [scheduler.next_camera() for _ in range(6)]

    assert picks == ["cam-1", "cam-2", "cam-3", "cam-1", "cam-2", "cam-3"]


def test_priority_camera_served_more_often():
    scheduler = InferenceScheduler(camera_ids=["cam-1", "cam-2", "cam-3"])
    scheduler.set_priority("cam-2", active=True)

    picks = [scheduler.next_camera() for _ in range(8)]
    priority_count = picks.count("cam-2")
    other_count = len(picks) - priority_count

    assert priority_count >= other_count
    assert priority_count > 8 // 3


def test_removing_priority_returns_to_plain_rotation():
    scheduler = InferenceScheduler(camera_ids=["cam-1", "cam-2"])
    scheduler.set_priority("cam-1", active=True)
    scheduler.next_camera()
    scheduler.set_priority("cam-1", active=False)

    picks = [scheduler.next_camera() for _ in range(4)]

    assert picks.count("cam-1") == picks.count("cam-2")


def test_empty_scheduler_returns_none():
    scheduler = InferenceScheduler(camera_ids=[])

    assert scheduler.next_camera() is None


def test_unknown_priority_camera_is_ignored():
    scheduler = InferenceScheduler(camera_ids=["cam-1", "cam-2"])
    scheduler.set_priority("missing-camera", active=True)

    picks = [scheduler.next_camera() for _ in range(4)]

    assert picks == ["cam-1", "cam-2", "cam-1", "cam-2"]
