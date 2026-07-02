from meridian_hub.config import Settings


def test_defaults(monkeypatch):
    for key in ["CAMERA_SOURCES", "TARGET_FPS", "INFERENCE_PROVIDER", "FACILITY_ID"]:
        monkeypatch.delenv(key, raising=False)
    settings = Settings(_env_file=None)
    assert settings.camera_sources == ["0"]
    assert settings.target_fps == 30
    assert settings.inference_provider == "directml"
    assert settings.facility_id == "fac-poc-001"


def test_camera_sources_parses_comma_list(monkeypatch):
    monkeypatch.setenv("CAMERA_SOURCES", "0,videos/room2.mp4,videos/room3.mp4")
    settings = Settings(_env_file=None)
    assert settings.camera_sources == ["0", "videos/room2.mp4", "videos/room3.mp4"]
