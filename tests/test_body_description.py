import base64

import pytest

from meridian_hub.face.body_description import HackClubVisionDescriber


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
