from typing import Annotated, Literal

from pydantic import field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # NoDecode: pydantic-settings otherwise tries to JSON-parse list-typed
    # env vars before validators run, which fails on a plain comma list.
    camera_sources: Annotated[list[str], NoDecode] = ["0"]
    # Camera-limited, not model-limited: GPU benchmark (see
    # benchmarks/laptop_gpu_pose_benchmark_2026-07-02.md) measured 218 FPS
    # at full 640x480 with DirectML, so 30 FPS is what a real camera can
    # deliver, not a compute ceiling like it was on the Pi.
    target_fps: int = 30
    pose_model_path: str = "models/yolo11s-pose-480x640.onnx"
    inference_provider: Literal["directml", "cpu"] = "directml"
    facility_id: str = "fac-poc-001"
    building_id: str = "bld-poc-001"
    queue_db_path: str = "data/queue.sqlite3"
    registry_db_path: str = "data/camera_registry.sqlite3"
    mock_backend_url: str = "http://localhost:8000"
    supabase_project_ref: str | None = None
    supabase_url: str | None = None
    supabase_access_token: str | None = None
    supabase_db_host: str | None = None
    supabase_db_port: int = 5432
    supabase_db_name: str = "postgres"
    supabase_db_user: str = "postgres"
    supabase_db_password: str | None = None
    supabase_db_url: str | None = None
    supabase_publishable_key: str | None = None
    supabase_anon_key: str | None = None
    supabase_secret_key: str | None = None
    supabase_service_role_key: str | None = None
    meridian_supabase_service_role_key: str | None = None
    hackclub_ai_api_key: str | None = None
    hackclub_ai_base_url: str = "https://ai.hackclub.com/proxy/v1"
    hackclub_ai_vision_model: str = "google/gemini-2.5-flash"
    hackclub_ai_timeout_seconds: float = 45.0

    @field_validator("camera_sources", mode="before")
    @classmethod
    def _split_csv(cls, v):
        if isinstance(v, str):
            return [item.strip() for item in v.split(",") if item.strip()]
        return v
