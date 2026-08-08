from datetime import datetime, timedelta, timezone

from family_sms_escalation_decision import SmsEscalationContext, sms_escalation_decision


NOW = datetime(2026, 8, 7, 2, 5, tzinfo=timezone.utc)


def context(**changes):
    values = {
        "now": NOW,
        "detected_at": NOW - timedelta(minutes=5),
        "rate_window_started_at": NOW - timedelta(hours=1),
    }
    values.update(changes)
    return SmsEscalationContext(**values)


def test_escalates_only_a_critical_unacknowledged_incident_after_the_threshold():
    assert sms_escalation_decision(context()) == "queue_sms"
    assert sms_escalation_decision(context(detected_at=NOW - timedelta(seconds=299))) == "wait_threshold"
    assert sms_escalation_decision(context(severity="warning")) == "skip_noncritical"


def test_absent_or_revoked_consent_never_sends_sms():
    assert sms_escalation_decision(context(consent_status=None)) == "suppress_consent"
    assert sms_escalation_decision(context(consent_status="revoked")) == "suppress_consent"
    assert sms_escalation_decision(
        context(resident_visibility_consent_active=False),
    ) == "suppress_resident_visibility"


def test_acknowledged_or_resolved_incidents_never_escalate():
    assert sms_escalation_decision(context(acknowledged_at=NOW)) == "skip_acknowledged"
    assert sms_escalation_decision(context(resolved_at=NOW)) == "skip_acknowledged"


def test_existing_escalation_makes_every_worker_retry_idempotent():
    assert sms_escalation_decision(context(existing_escalation=True)) == "skip_idempotent"


def test_retry_after_a_provider_failure_does_not_create_a_second_sms():
    # A failed/unknown first attempt still has its durable escalation row.  It
    # must be reconciled from the provider audit trail, never automatically
    # resent after an ambiguous transport result.
    assert sms_escalation_decision(context(existing_escalation=True)) == "skip_idempotent"


def test_recipient_rate_limit_suppresses_flapping_sensor_bursts():
    assert sms_escalation_decision(context(reserved_count=3)) == "suppress_rate_limited"
    assert sms_escalation_decision(
        context(reserved_count=3, rate_window_started_at=NOW - timedelta(hours=24)),
    ) == "queue_sms"


def test_quiet_hours_do_not_silence_a_critical_emergency():
    assert sms_escalation_decision(context(quiet_hours=True)) == "queue_sms"
    assert sms_escalation_decision(context(quiet_hours=True, severity="warning")) == "skip_noncritical"


def test_python_decision_model_has_not_drifted_from_the_authoritative_sql():
    """The tests above exercise a *model* of the SQL, not the SQL itself.

    `queue_family_sms_escalations` is the deployed authority, and PostgreSQL
    cannot run on this machine. That makes silent drift the real risk: someone
    relaxes a gate in SQL, the Python model still enforces it, and seven green
    tests say the emergency-SMS guardrails hold when they no longer do.

    This pins each guard in the model to a predicate in the function body, so
    dropping one from the SQL fails here instead of surfacing as an unwanted
    text to a family member at 2 AM.
    """
    from pathlib import Path
    import re

    sql = Path("supabase/migrations/20260807000100_family_sms_escalation.sql").read_text(encoding="utf-8")
    body = re.search(
        r"(?is)create\s+or\s+replace\s+function\s+public\.queue_family_sms_escalations.*?\n\$\$",
        sql,
    )
    assert body, "queue_family_sms_escalations not found -- this guard is checking nothing"
    body = body.group(0).lower()

    required = {
        "consent gate": "consent_status = 'opted_in'",
        "resident visibility gate": "consent_status = 'active'",
        "critical-only gate": "severity = 'critical'",
        "not-acknowledged gate": "acknowledged_at is null",
        "not-resolved gate": "resolved_at is null",
        "active-status gate": "status in ('open', 'escalated')",
        "delay threshold": "escalation_delay_seconds",
        "rate limit": "max_messages_per_recipient_24h",
    }
    missing = [name for name, predicate in required.items() if predicate not in body]
    assert not missing, (
        "the SQL no longer enforces gates the Python decision model still asserts: "
        + ", ".join(missing)
    )
