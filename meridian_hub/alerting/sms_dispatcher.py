import logging
import os
from collections.abc import Callable
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class SmsSendResult:
    to: str
    success: bool
    message_sid: str | None
    error: str | None


class SmsAlertDispatcher:
    """Sends SMS alerts via Twilio. client_factory is injectable so tests
    never need real Twilio credentials or network access. Every
    recipient is sent to and reported on independently -- one bad phone
    number must never block delivery to the rest of the contact list,
    since silently dropping the rest is exactly the kind of failure that
    would defeat an emergency alert system."""

    def __init__(
        self, account_sid: str, auth_token: str, from_number: str,
        client_factory: Callable[[str, str], object] | None = None,
    ):
        self._from_number = from_number
        factory = client_factory or self._default_client_factory
        self._client = factory(account_sid, auth_token)

    @staticmethod
    def _default_client_factory(account_sid: str, auth_token: str):
        from twilio.rest import Client
        return Client(account_sid, auth_token)

    @classmethod
    def from_env(
        cls, sid_env: str = "TWILIO_ACCOUNT_SID", token_env: str = "TWILIO_AUTH_TOKEN",
        from_number_env: str = "TWILIO_FROM_NUMBER",
    ) -> "SmsAlertDispatcher":
        sid = os.environ.get(sid_env)
        token = os.environ.get(token_env)
        from_number = os.environ.get(from_number_env)
        missing = [name for name, val in [(sid_env, sid), (token_env, token), (from_number_env, from_number)] if not val]
        if missing:
            raise RuntimeError(f"Missing Twilio config: {', '.join(missing)} -- cannot send SMS alerts without them")
        return cls(account_sid=sid, auth_token=token, from_number=from_number)

    def send_alert(self, to_numbers: list[str], message: str) -> list[SmsSendResult]:
        results = []
        for number in to_numbers:
            try:
                sent = self._client.messages.create(to=number, from_=self._from_number, body=message)
                results.append(SmsSendResult(to=number, success=True, message_sid=sent.sid, error=None))
            except Exception as e:
                logger.error("Failed to send SMS alert to %s: %s", number, e)
                results.append(SmsSendResult(to=number, success=False, message_sid=None, error=str(e)))
        return results
