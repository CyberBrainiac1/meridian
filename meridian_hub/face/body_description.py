import base64
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import requests

from meridian_hub.config import Settings

DEFAULT_PROMPT = (
    "Describe the visible full body and clothing of the unknown visitor in one "
    "concise sentence for caregivers. Mention clothing colors, carried items, "
    "posture, and whether this is only a partial view if relevant. Do not identify "
    "the person, name them, or guess race, ethnicity, health, emotion, or intent."
)


@dataclass(frozen=True)
class BodyDescriptionResult:
    description: str
    model: str
    generated_at: datetime


class HackClubVisionDescriber:
    """Server-side Hack Club AI vision client for visitor descriptions.

    The image is sent before Hub-side encryption because vision models need
    pixels. The raw image still never goes to Supabase; only the generated
    description and the encrypted person photo metadata/ciphertext do.
    """

    def __init__(
        self,
        *,
        api_key: str,
        base_url: str = "https://ai.hackclub.com/proxy/v1",
        model: str = "google/gemini-2.5-flash",
        timeout_seconds: float = 45.0,
        session: Any | None = None,
    ):
        if not api_key:
            raise ValueError("Hack Club AI API key is required")
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._model = model
        self._timeout_seconds = timeout_seconds
        self._session = session or requests
        _install_windows_truststore()

    @classmethod
    def from_settings(cls, settings: Settings | None = None) -> "HackClubVisionDescriber":
        settings = settings or Settings()
        if not settings.hackclub_ai_api_key:
            raise RuntimeError("HACKCLUB_AI_API_KEY is not set")
        return cls(
            api_key=settings.hackclub_ai_api_key,
            base_url=settings.hackclub_ai_base_url,
            model=settings.hackclub_ai_vision_model,
            timeout_seconds=settings.hackclub_ai_timeout_seconds,
        )

    @property
    def model(self) -> str:
        return self._model

    def describe_person_photo(
        self,
        image_bytes: bytes,
        *,
        content_type: str = "image/jpeg",
        prompt: str = DEFAULT_PROMPT,
    ) -> BodyDescriptionResult:
        if not image_bytes:
            raise ValueError("image_bytes must not be empty")
        if not content_type.startswith("image/"):
            raise ValueError("content_type must be an image MIME type")

        image_b64 = base64.b64encode(image_bytes).decode("ascii")
        response = self._session.post(
            f"{self._base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": self._model,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:{content_type};base64,{image_b64}",
                                },
                            },
                        ],
                    }
                ],
                "temperature": 0.2,
                "max_tokens": 160,
            },
            timeout=self._timeout_seconds,
        )
        try:
            response.raise_for_status()
        except Exception as exc:
            raise RuntimeError(f"Hack Club vision request failed: {response.status_code}") from exc

        data = response.json()
        content = data["choices"][0]["message"]["content"]
        return BodyDescriptionResult(
            description=_clean_description(content),
            model=self._model,
            generated_at=datetime.now(timezone.utc),
        )


def _clean_description(value: str) -> str:
    cleaned = re.sub(r"\s+", " ", value).strip().strip('"')
    if len(cleaned) > 700:
        cleaned = cleaned[:697].rstrip() + "..."
    return cleaned


def _install_windows_truststore() -> None:
    try:
        import truststore

        truststore.inject_into_ssl()
    except Exception:
        # Best effort only. Non-Windows and test environments work with
        # certifi; Windows installs benefit from the OS root store.
        return
