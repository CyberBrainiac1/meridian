import pytest

from meridian_hub.alerting.sms_dispatcher import SmsAlertDispatcher


class _FakeMessage:
    def __init__(self, sid):
        self.sid = sid


class _FakeMessages:
    def __init__(self, fail_numbers=None):
        self._fail_numbers = fail_numbers or set()
        self.sent = []

    def create(self, to, from_, body):
        if to in self._fail_numbers:
            raise RuntimeError(f"Twilio rejected {to}: invalid number")
        self.sent.append((to, from_, body))
        return _FakeMessage(sid=f"SM{len(self.sent):04d}")


class _FakeClient:
    def __init__(self, fail_numbers=None):
        self.messages = _FakeMessages(fail_numbers)


def _dispatcher(fail_numbers=None):
    return SmsAlertDispatcher(
        account_sid="AC_test", auth_token="test_token", from_number="+15551234567",
        client_factory=lambda sid, token: _FakeClient(fail_numbers),
    )


def test_sends_to_all_recipients():
    dispatcher = _dispatcher()
    results = dispatcher.send_alert(["+15550001", "+15550002"], "Maggie may have fallen in Room 12.")
    assert len(results) == 2
    assert all(r.success for r in results)
    assert all(r.message_sid is not None for r in results)


def test_one_failed_recipient_does_not_block_others():
    dispatcher = _dispatcher(fail_numbers={"+15550001"})
    results = dispatcher.send_alert(["+15550001", "+15550002"], "Test alert")
    by_number = {r.to: r for r in results}
    assert by_number["+15550001"].success is False
    assert "invalid number" in by_number["+15550001"].error
    assert by_number["+15550002"].success is True


def test_empty_recipient_list_returns_empty_results():
    dispatcher = _dispatcher()
    assert dispatcher.send_alert([], "message") == []


def test_from_env_raises_clear_error_when_config_missing(monkeypatch):
    monkeypatch.delenv("TWILIO_ACCOUNT_SID", raising=False)
    monkeypatch.delenv("TWILIO_AUTH_TOKEN", raising=False)
    monkeypatch.delenv("TWILIO_FROM_NUMBER", raising=False)
    with pytest.raises(RuntimeError, match="TWILIO_ACCOUNT_SID"):
        SmsAlertDispatcher.from_env()
