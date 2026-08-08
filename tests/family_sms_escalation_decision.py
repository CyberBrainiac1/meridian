"""Executable decision contract for the SQL SMS escalation queue.

The deployed authority is `queue_family_sms_escalations` and
`claim_family_sms_escalations` in the additive migration.  PostgreSQL is not
available on this machine, so this small pure model makes the critical decision
matrix executable in pytest without pretending to exercise the database.
"""
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class SmsEscalationContext:
    now: datetime
    detected_at: datetime
    severity: str = "critical"
    acknowledged_at: datetime | None = None
    resolved_at: datetime | None = None
    incident_status: str = "open"
    consent_status: str | None = "opted_in"
    resident_visibility_consent_active: bool = True
    existing_escalation: bool = False
    rate_window_started_at: datetime | None = None
    reserved_count: int = 0
    max_messages_per_recipient_24h: int = 3
    escalation_delay_seconds: int = 300
    quiet_hours: bool = False


def sms_escalation_decision(context: SmsEscalationContext) -> str:
    """Return the sole allowed next decision for an incident/recipient pair.

    Emergency SMS is explicitly exempt from quiet hours.  It is still bounded
    by consent, acknowledgement, one-row idempotency, and the rate window.
    """
    if context.consent_status != "opted_in":
        return "suppress_consent"
    if not context.resident_visibility_consent_active:
        return "suppress_resident_visibility"
    if context.existing_escalation:
        return "skip_idempotent"
    if context.severity != "critical":
        return "skip_noncritical"
    if context.acknowledged_at is not None or context.resolved_at is not None:
        return "skip_acknowledged"
    if context.incident_status not in {"open", "escalated"}:
        return "skip_inactive"
    if context.now < context.detected_at + timedelta(seconds=context.escalation_delay_seconds):
        return "wait_threshold"
    if (
        context.rate_window_started_at is not None
        and context.now < context.rate_window_started_at + timedelta(hours=24)
        and context.reserved_count >= context.max_messages_per_recipient_24h
    ):
        return "suppress_rate_limited"
    return "queue_sms"
