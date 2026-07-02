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


def test_supabase_settings_load_from_env(monkeypatch):
    monkeypatch.setenv("SUPABASE_PROJECT_REF", "project-ref")
    monkeypatch.setenv("SUPABASE_URL", "https://project-ref.supabase.co")
    monkeypatch.setenv("SUPABASE_DB_HOST", "db.project-ref.supabase.co")
    monkeypatch.setenv("SUPABASE_DB_PASSWORD", "database-secret")
    monkeypatch.setenv("SUPABASE_DB_URL", "postgresql://postgres:database-secret@db.project-ref.supabase.co:5432/postgres")
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "sb_publishable_test")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "sb_secret_test")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "server-only")
    monkeypatch.setenv("MERIDIAN_SUPABASE_SERVICE_ROLE_KEY", "server-only-meridian")

    settings = Settings(_env_file=None)

    assert settings.supabase_project_ref == "project-ref"
    assert settings.supabase_url == "https://project-ref.supabase.co"
    assert settings.supabase_db_host == "db.project-ref.supabase.co"
    assert settings.supabase_db_password == "database-secret"
    assert settings.supabase_db_url == "postgresql://postgres:database-secret@db.project-ref.supabase.co:5432/postgres"
    assert settings.supabase_publishable_key == "sb_publishable_test"
    assert settings.supabase_secret_key == "sb_secret_test"
    assert settings.supabase_service_role_key == "server-only"
    assert settings.meridian_supabase_service_role_key == "server-only-meridian"
