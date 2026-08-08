import base64

import pytest

from meridian_hub.face.body_description import (
    FallbackVisionDescriber,
    GeminiVisionDescriber,
    HackClubVisionDescriber,
    build_vision_describer,
)


class _FakeResponse:
    def __init__(self, status_code=200, payload=None):
        self.status_code = status_code
        self._payload = payload or {
            "choices": [{"message": {"content": "  Wearing a red jacket and blue jeans.  "}}]
        }

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError("http error")

    def json(self):
        return self._payload


class _FakeSession:
    def __init__(self, response=None):
        self.response = response or _FakeResponse()
        self.calls = []

    def post(self, url, **kwargs):
        self.calls.append((url, kwargs))
        return self.response


def test_describer_sends_image_input_and_returns_clean_description():
    session = _FakeSession()
    describer = HackClubVisionDescriber(
        api_key="sk-test",
        model="google/gemini-2.5-flash",
        session=session,
    )

    result = describer.describe_person_photo(b"fake-jpeg")

    assert result.description == "Wearing a red jacket and blue jeans."
    assert result.model == "google/gemini-2.5-flash"
    url, kwargs = session.calls[0]
    assert url == "https://ai.hackclub.com/proxy/v1/chat/completions"
    assert kwargs["headers"]["Authorization"] == "Bearer sk-test"
    image_url = kwargs["json"]["messages"][0]["content"][1]["image_url"]["url"]
    assert image_url == f"data:image/jpeg;base64,{base64.b64encode(b'fake-jpeg').decode('ascii')}"


def test_describer_rejects_empty_image():
    describer = HackClubVisionDescriber(api_key="sk-test", session=_FakeSession())
    with pytest.raises(ValueError, match="image_bytes"):
        describer.describe_person_photo(b"")


def test_describer_http_error_hides_api_key():
    describer = HackClubVisionDescriber(
        api_key="sk-secret-value",
        session=_FakeSession(_FakeResponse(status_code=429)),
    )

    with pytest.raises(RuntimeError) as exc_info:
        describer.describe_person_photo(b"fake-jpeg")

    assert "429" in str(exc_info.value)
    assert "sk-secret-value" not in str(exc_info.value)


def test_try_describe_returns_none_on_failure_instead_of_raising():
    # A 402/exhausted-quota (or any failure) must degrade gracefully so the
    # visitor notification path stays up when the vision API is unavailable.
    describer = HackClubVisionDescriber(
        api_key="sk-test",
        session=_FakeSession(_FakeResponse(status_code=402)),
    )
    assert describer.try_describe_person_photo(b"fake-jpeg") is None


def test_try_describe_returns_result_on_success():
    describer = HackClubVisionDescriber(api_key="sk-test", session=_FakeSession())
    result = describer.try_describe_person_photo(b"fake-jpeg")
    assert result is not None
    assert "red jacket" in result.description


def _gemini_payload(text="  Wearing a red jacket and blue jeans.  "):
    return {"candidates": [{"content": {"parts": [{"text": text}]}}]}


def test_gemini_describer_uses_generate_content_endpoint_and_api_key_header():
    session = _FakeSession(_FakeResponse(payload=_gemini_payload()))
    describer = GeminiVisionDescriber(
        api_key="gemini-test",
        model="gemini-flash-latest",
        session=session,
    )

    result = describer.describe_person_photo(b"fake-jpeg")

    assert result.description == "Wearing a red jacket and blue jeans."
    assert result.model == "gemini-flash-latest"
    url, kwargs = session.calls[0]
    assert url == (
        "https://generativelanguage.googleapis.com/v1beta"
        "/models/gemini-flash-latest:generateContent"
    )
    assert kwargs["headers"]["x-goog-api-key"] == "gemini-test"
    assert "Authorization" not in kwargs["headers"]
    parts = kwargs["json"]["contents"][0]["parts"]
    assert parts[0]["text"].startswith("Describe the visible full body")
    assert parts[1]["inline_data"]["mime_type"] == "image/jpeg"
    assert parts[1]["inline_data"]["data"] == base64.b64encode(b"fake-jpeg").decode("ascii")


def test_gemini_output_budget_covers_thinking_tokens():
    # The flash aliases spend ~600 internal thinking tokens on this prompt and
    # reject thinkingBudget/thinkingLevel, so a small budget truncates the
    # sentence mid-word. Guard the headroom.
    session = _FakeSession(_FakeResponse(payload=_gemini_payload()))
    GeminiVisionDescriber(api_key="gemini-test", session=session).describe_person_photo(b"j")
    assert session.calls[0][1]["json"]["generationConfig"]["maxOutputTokens"] >= 1024


def test_gemini_skips_non_text_parts_like_thought_signatures():
    payload = {
        "candidates": [
            {"content": {"parts": [{"thoughtSignature": "abc"}, {"text": "A red jacket."}]}}
        ]
    }
    describer = GeminiVisionDescriber(
        api_key="gemini-test", session=_FakeSession(_FakeResponse(payload=payload))
    )
    assert describer.describe_person_photo(b"fake-jpeg").description == "A red jacket."


def test_gemini_http_error_hides_api_key():
    describer = GeminiVisionDescriber(
        api_key="gemini-secret-value",
        session=_FakeSession(_FakeResponse(status_code=403)),
    )

    with pytest.raises(RuntimeError) as exc_info:
        describer.describe_person_photo(b"fake-jpeg")

    assert "403" in str(exc_info.value)
    assert "gemini-secret-value" not in str(exc_info.value)


def test_gemini_empty_candidates_raise_rather_than_indexerror():
    describer = GeminiVisionDescriber(
        api_key="gemini-test", session=_FakeSession(_FakeResponse(payload={"candidates": []}))
    )
    with pytest.raises(RuntimeError, match="no text"):
        describer.describe_person_photo(b"fake-jpeg")


def test_gemini_try_describe_degrades_to_none():
    describer = GeminiVisionDescriber(
        api_key="gemini-test", session=_FakeSession(_FakeResponse(status_code=429))
    )
    assert describer.try_describe_person_photo(b"fake-jpeg") is None


def test_fallback_uses_second_provider_when_first_fails():
    gemini = GeminiVisionDescriber(
        api_key="gemini-test", session=_FakeSession(_FakeResponse(status_code=500))
    )
    hackclub = HackClubVisionDescriber(api_key="sk-test", session=_FakeSession())

    result = FallbackVisionDescriber([gemini, hackclub]).describe_person_photo(b"fake-jpeg")

    assert "red jacket" in result.description
    assert result.model == "google/gemini-2.5-flash"


def test_fallback_prefers_gemini_and_skips_hackclub_on_success():
    hackclub_session = _FakeSession()
    gemini = GeminiVisionDescriber(
        api_key="gemini-test",
        model="gemini-flash-latest",
        session=_FakeSession(_FakeResponse(payload=_gemini_payload("A navy coat."))),
    )
    hackclub = HackClubVisionDescriber(api_key="sk-test", session=hackclub_session)

    result = FallbackVisionDescriber([gemini, hackclub]).describe_person_photo(b"fake-jpeg")

    assert result.description == "A navy coat."
    assert result.model == "gemini-flash-latest"
    assert hackclub_session.calls == []


def test_fallback_returns_none_when_every_provider_is_down():
    gemini = GeminiVisionDescriber(
        api_key="gemini-test", session=_FakeSession(_FakeResponse(status_code=500))
    )
    hackclub = HackClubVisionDescriber(
        api_key="sk-test", session=_FakeSession(_FakeResponse(status_code=402))
    )
    assert FallbackVisionDescriber([gemini, hackclub]).try_describe_person_photo(b"j") is None


def test_fallback_does_not_retry_chain_on_bad_input():
    hackclub_session = _FakeSession()
    chain = FallbackVisionDescriber(
        [
            GeminiVisionDescriber(api_key="gemini-test", session=_FakeSession()),
            HackClubVisionDescriber(api_key="sk-test", session=hackclub_session),
        ]
    )
    with pytest.raises(ValueError, match="image_bytes"):
        chain.describe_person_photo(b"")
    assert hackclub_session.calls == []


def test_build_vision_describer_selects_providers_from_settings(monkeypatch):
    from meridian_hub.config import Settings

    monkeypatch.delenv("HACKCLUB_AI_API_KEY", raising=False)
    monkeypatch.setenv("GEMINI_API_KEY", "gemini-test")
    assert isinstance(build_vision_describer(Settings(_env_file=None)), GeminiVisionDescriber)

    monkeypatch.setenv("HACKCLUB_AI_API_KEY", "sk-test")
    chain = build_vision_describer(Settings(_env_file=None))
    assert isinstance(chain, FallbackVisionDescriber)
    assert chain.model == "gemini-flash-latest"

    monkeypatch.delenv("GEMINI_API_KEY")
    assert isinstance(build_vision_describer(Settings(_env_file=None)), HackClubVisionDescriber)

    monkeypatch.delenv("HACKCLUB_AI_API_KEY")
    assert build_vision_describer(Settings(_env_file=None)) is None
