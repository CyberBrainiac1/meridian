from typing import Annotated, Literal

from pydantic import field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # NoDecode: pydantic-settings otherwise tries to JSON-parse list-typed
    # env vars before validators run, which fails on a plain comma list.
    camera_sources: Annotated[list[str], NoDecode] = ["0"]
    target_fps: int = 15
    pose_model_path: str = "models/yolo11s-pose.onnx"
    inference_provider: Literal["directml", "cpu"] = "directml"
    facility_id: str = "fac-poc-001"
    building_id: str = "bld-poc-001"
    queue_db_path: str = "data/queue.sqlite3"
    registry_db_path: str = "data/camera_registry.sqlite3"
    mock_backend_url: str = "http://localhost:8000"

    @field_validator("camera_sources", mode="before")
    @classmethod
    def _split_csv(cls, v):
        if isinstance(v, str):
            return [item.strip() for item in v.split(",") if item.strip()]
        return v
