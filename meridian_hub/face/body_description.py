import base64
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Protocol

import requests

from meridian_hub.config import Settings

logger = logging.getLogger(__name__)

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


class VisionDescriber(Protocol):
    """Injected vision boundary; only the generated sentence crosses it."""

    @property
    def model(self) -> str: ...

    def describe_person_photo(
        self,
        image_bytes: bytes,
        *,
        content_type: str = ...,
        prompt: str = ...,
    ) -> BodyDescriptionResult: ...

    def try_describe_person_photo(
        self,
        image_bytes: bytes,
        *,
        content_type: str = ...,
        prompt: str = ...,
    ) -> BodyDescriptionResult | None: ...


class _BestEffortDescriberMixin:
    """Shared graceful-degradation wrapper for every vision provider."""

    def try_describe_person_photo(
        self,
        image_bytes: bytes,
        *,
        content_type: str = "image/jpeg",
        prompt: str = DEFAULT_PROMPT,
    ) -> BodyDescriptionResult | None:
        """Best-effort wrapper for the live pipeline: the AI clothing/body
        description is an enrichment on top of the visitor notification,
        never a dependency of it. If the vision API is down, exhausted
        (HTTP 402), rate-limited, or slow, this returns None and logs a
        warning instead of raising -- so a visitor arrival is still logged
        and still notifies caregivers (with the encrypted embedding,
        encrypted photo, and age/gender description) even when the vision
        service is unavailable. Demos and production both stay up."""
        try:
            return self.describe_person_photo(image_bytes, content_type=content_type, prompt=prompt)
        except Exception as exc:
            logger.warning("Visitor body description unavailable, continuing without it: %s", exc)
            return None


class GeminiVisionDescriber(_BestEffortDescriberMixin):
    """Google Gemini (Generative Language API) vision client for visitor
    descriptions.

    This is the primary provider. The image is sent before Hub-side
    encryption because vision models need pixels. The raw image still never
    goes to Supabase; only the generated description and the encrypted
    person photo metadata/ciphertext do.
    """

    def __init__(
        self,
        *,
        api_key: str,
        base_url: str = "https://generativelanguage.googleapis.com/v1beta",
        model: str = "gemini-flash-latest",
        timeout_seconds: float = 45.0,
        session: Any | None = None,
    ):
        if not api_key:
            raise ValueError("Gemini API key is required")
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._model = model
        self._timeout_seconds = timeout_seconds
        self._session = session or requests
        _install_windows_truststore()

    @classmethod
    def from_settings(cls, settings: Settings | None = None) -> "GeminiVisionDescriber":
        settings = settings or Settings()
        if not settings.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY is not set")
        return cls(
            api_key=settings.gemini_api_key,
            base_url=settings.gemini_base_url,
            model=settings.gemini_vision_model,
            timeout_seconds=settings.gemini_timeout_seconds,
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
            f"{self._base_url}/models/{self._model}:generateContent",
            headers={
                "x-goog-api-key": self._api_key,
                "Content-Type": "application/json",
            },
            json={
                "contents": [
                    {
                        "parts": [
                            {"text": prompt},
                            {
                                "inline_data": {
                                    "mime_type": content_type,
                                    "data": image_b64,
                                }
                            },
                        ]
                    }
                ],
                # maxOutputTokens has to cover the model's internal thinking
                # tokens too (measured ~600 for this prompt), so a tight
                # budget silently truncates the sentence mid-word. The
                # visible answer is still capped at 700 chars by
                # _clean_description. thinkingBudget/thinkingLevel are not
                # accepted on the flash aliases, so headroom is the fix.
                "generationConfig": {
                    "temperature": 0.2,
                    "maxOutputTokens": 2048,
                },
            },
            timeout=self._timeout_seconds,
        )
        try:
            response.raise_for_status()
        except Exception as exc:
            raise RuntimeError(f"Gemini vision request failed: {response.status_code}") from exc

        content = _extract_gemini_text(response.json())
        if not content:
            raise RuntimeError("Gemini vision response contained no text")
        return BodyDescriptionResult(
            description=_clean_description(content),
            model=self._model,
            generated_at=datetime.now(timezone.utc),
        )


class HackClubVisionDescriber(_BestEffortDescriberMixin):
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

class FallbackVisionDescriber(_BestEffortDescriberMixin):
    """Tries each provider in order and returns the first success.

    Ordered Gemini first, Hack Club second: the real Gemini API is the
    supported path, and the Hack Club proxy stays as a fallback for
    hackathon/demo keys. Only the last error propagates, so
    `try_describe_person_photo` still degrades to None if every provider
    is down.
    """

    def __init__(self, providers: list[VisionDescriber]):
        if not providers:
            raise ValueError("at least one vision provider is required")
        self._providers = list(providers)

    @property
    def model(self) -> str:
        return self._providers[0].model

    def describe_person_photo(
        self,
        image_bytes: bytes,
        *,
        content_type: str = "image/jpeg",
        prompt: str = DEFAULT_PROMPT,
    ) -> BodyDescriptionResult:
        last_error: Exception | None = None
        for provider in self._providers:
            try:
                return provider.describe_person_photo(
                    image_bytes, content_type=content_type, prompt=prompt
                )
            except ValueError:
                # Bad input (empty image / non-image MIME) fails the same way
                # on every provider, so retrying the chain is pointless.
                raise
            except Exception as exc:
                logger.warning("Vision provider %s failed, trying next: %s", provider.model, exc)
                last_error = exc
        raise RuntimeError(f"all vision providers failed: {last_error}")


def build_vision_describer(settings: Settings | None = None) -> VisionDescriber | None:
    """Assemble the configured provider chain, or None if nothing is set up."""
    settings = settings or Settings()
    providers: list[VisionDescriber] = []
    if settings.gemini_api_key:
        providers.append(GeminiVisionDescriber.from_settings(settings))
    if settings.hackclub_ai_api_key:
        providers.append(HackClubVisionDescriber.from_settings(settings))
    if not providers:
        return None
    if len(providers) == 1:
        return providers[0]
    return FallbackVisionDescriber(providers)


def _extract_gemini_text(data: dict[str, Any]) -> str:
    """Join the text parts of the first candidate.

    Gemini can interleave non-text parts (thought signatures, inline data),
    so parts without a "text" key are skipped rather than indexed blindly.
    """
    candidates = data.get("candidates") or []
    if not candidates:
        return ""
    parts = (candidates[0].get("content") or {}).get("parts") or []
    return " ".join(part["text"] for part in parts if isinstance(part.get("text"), str))


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
