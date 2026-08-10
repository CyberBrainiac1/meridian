"""Restore the demo to a known-good starting state, between judge groups.

This is NOT `seed_demo_data.py --wipe`. That deletes the facility and cascades
away every resident, medication, activity, contact and shift -- the whole
clinical layer -- and does not recreate it. Running it before a demo would be
unrecoverable in the room.

This does the opposite: it leaves all standing configuration alone and only
resets the *transient* state a demo run consumes --

  * clears assistance requests, messages, and today's self-reports
  * clears the acknowledged/resolved state a rehearsal leaves behind
  * guarantees exactly one OPEN critical fall alert in room 101, because
    "judges watch a live fall alert arrive" is the headline demo moment and a
    rehearsal acknowledges it

Safe to run repeatedly, and safe to run 30 seconds before walking on stage.

    python tools/reset_demo_state.py
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
FACILITY_ID = "meridian-demo"


def read_env(key: str) -> str:
    for line in (REPO_ROOT / ".env").read_text().splitlines():
        line = line.strip()
        if line.startswith(f"{key}="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"{key} not found in .env")


SUPABASE_URL = read_env("SUPABASE_URL")
SERVICE_KEY = read_env("SUPABASE_SERVICE_ROLE_KEY")


def call(method: str, path: str, body=None, prefer: str | None = None, attempts: int = 3):
    """One request, retried on transient network failure.

    This runs on conference wifi minutes before walking on stage, where a
    single dropped TLS handshake is normal. An un-retried blip here would
    look identical to a broken demo, so transient failures are retried and
    only a real HTTP error is returned as one.
    """
    url = f"{SUPABASE_URL}{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer

    last_error: Exception | None = None
    for attempt in range(attempts):
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                raw = response.read().decode()
                return response.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as error:
            # A real server response, not a transport failure -- don't retry.
            return error.code, error.read().decode()
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
            if attempt < attempts - 1:
                time.sleep(1.5 * (attempt + 1))
    return 0, f"network error after {attempts} attempts: {last_error}"


def main() -> None:
    now = datetime.now(timezone.utc)

    print("Clearing transient demo state...")
    for label, path in [
        ("assistance requests", f"/rest/v1/assistance_requests?facility_id=eq.{FACILITY_ID}"),
        ("messages", f"/rest/v1/messages?facility_id=eq.{FACILITY_ID}"),
        ("medication administrations", f"/rest/v1/medication_administrations?facility_id=eq.{FACILITY_ID}"),
        ("activity completions", f"/rest/v1/activity_completions?facility_id=eq.{FACILITY_ID}"),
        ("visitor prompts", f"/rest/v1/visitor_verification_prompts?facility_id=eq.{FACILITY_ID}"),
        ("pending notifications", f"/rest/v1/notifications?facility_id=eq.{FACILITY_ID}&status=eq.pending"),
    ]:
        status, _ = call("DELETE", path)
        print(f"  {label}: {status}")

    # Un-acknowledge handoff notes so the "Acknowledge" affordance is live
    # again for the next group.
    status, _ = call(
        "PATCH",
        f"/rest/v1/handoff_notes?facility_id=eq.{FACILITY_ID}",
        {"acknowledged_by": None, "acknowledged_at": None},
    )
    print(f"  handoff notes un-acknowledged: {status}")

    # The demo's headline moment. A rehearsal acknowledges this, and an
    # acknowledged alert produces no urgent overlay and no notification for
    # the next audience -- so it is recreated rather than merely reset.
    print("\nRestoring the open critical fall alert in room 101...")
    call("DELETE", f"/rest/v1/incident_events?source_event_id=like.demo-live-fall-*")

    detected = now - timedelta(minutes=2)
    status, payload = call(
        "POST",
        "/rest/v1/incident_events",
        {
            "source_event_id": f"demo-live-fall-{uuid.uuid4().hex[:8]}",
            "facility_id": FACILITY_ID,
            "resident_id": "res-maggie",
            "room_id": "101",
            "event_type": "fall_confirmed",
            "severity": "critical",
            "status": "open",
            "confidence": 0.94,
            "detected_at": detected.isoformat(),
            "generated_at": detected.isoformat(),
            "summary": "Maggie Alvarez may have fallen in Room 101.",
        },
        prefer="return=representation",
    )
    ok = status in (200, 201)
    print(f"  created: {status} {'OK' if ok else payload}")

    # A fall_confirmed insert fires dispatch_confirmed_fall_assistance, which
    # auto-creates an emergency assistance_request. That is correct product
    # behaviour, but it would leave the Hub collapsed into its "help is on the
    # way" state before anyone taps anything -- so clear it and let the demo
    # start from the neutral screen.
    status, _ = call(
        "DELETE",
        f"/rest/v1/assistance_requests?facility_id=eq.{FACILITY_ID}&source=eq.auto_fall_dispatch",
    )
    print(f"  cleared auto-dispatched request so the Hub starts neutral: {status}")

    # ---- Re-anchor everything time-relative to "now" ----------------------
    # Seeded data was written against the date it was seeded on. Once the
    # clock rolls past that, screens that filter on "today" or "currently on
    # shift" quietly go empty and the apps look broken rather than idle:
    #   * caregiver_shifts ended  -> Handoff shows "No caregiver shifts"
    #   * newest incident is yesterday -> Family's Today headline never fires
    #   * rollups end yesterday   -> Family's activity summary is blank
    # None of these are code bugs, and all of them are visible at the table.
    print("\nRe-anchoring time-sensitive data to today...")

    call("DELETE", f"/rest/v1/caregiver_shifts?facility_id=eq.{FACILITY_ID}")
    shift_rows = [
        ("Lin Nakamura", "+15555550110", "Night shift caregiver", -3, 5),
        ("James Whitfield", "+15555550111", "Day shift caregiver", 5, 13),
        ("Nadia Osei", "+15555550112", "Charge nurse (on call)", -3, 13),
    ]
    payload = [
        {
            "facility_id": FACILITY_ID,
            "display_name": name,
            "phone_e164": phone,
            "role_label": role,
            "starts_at": (now + timedelta(hours=start)).isoformat(),
            "ends_at": (now + timedelta(hours=end)).isoformat(),
        }
        for name, phone, role, start, end in shift_rows
    ]
    status, _ = call("POST", "/rest/v1/caregiver_shifts", payload)
    print(f"  caregiver shifts re-anchored (one on now, one on next): {status}")

    # A little resolved history from earlier today, so the caregiver's
    # 8-hour handoff summary and the response-time metric aren't empty.
    call("DELETE", "/rest/v1/incident_events?source_event_id=like.demo-today-*")
    history = []
    for offset_minutes, resident, room, event, severity in [
        (330, "res-harold", "104", "night_activity", "info"),
        (250, "res-frank", "118", "unusual_inactivity", "warning"),
        (140, "res-ruth", "112", "night_activity", "info"),
    ]:
        detected = now - timedelta(minutes=offset_minutes)
        history.append({
            "source_event_id": f"demo-today-{resident}-{offset_minutes}",
            "facility_id": FACILITY_ID,
            "resident_id": resident,
            "room_id": room,
            "event_type": event,
            "severity": severity,
            "status": "resolved",
            "confidence": 0.88,
            "detected_at": detected.isoformat(),
            "generated_at": detected.isoformat(),
            "acknowledged_at": (detected + timedelta(seconds=52)).isoformat(),
            "resolved_at": (detected + timedelta(minutes=6)).isoformat(),
            "summary": "Checked on and settled.",
        })
    status, _ = call("POST", "/rest/v1/incident_events", history)
    print(f"  today's resolved incident history: {status}")

    # Activity rollups through today, so Family's summary has a headline.
    for resident in ("res-maggie", "res-harold", "res-ruth", "res-frank"):
        call(
            "DELETE",
            f"/rest/v1/resident_activity_rollups?resident_id=eq.{resident}"
            f"&rollup_date=eq.{now.date().isoformat()}",
        )
    rollups = [
        {
            "facility_id": FACILITY_ID,
            "resident_id": resident,
            "rollup_date": now.date().isoformat(),
            "daytime_pattern": daytime,
            "nighttime_pattern": nighttime,
            "baseline_status": "ready",
            "observation_status": "sufficient",
        }
        for resident, daytime, nighttime in [
            ("res-maggie", "usual", "higher_than_usual"),
            ("res-harold", "usual", "usual"),
            ("res-ruth", "higher_than_usual", "usual"),
            ("res-frank", "lower_than_usual", "usual"),
        ]
    ]
    status, _ = call("POST", "/rest/v1/resident_activity_rollups", rollups)
    print(f"  today's activity rollups for all 4 residents: {status}")

    # ---- Visitor history --------------------------------------------------
    # Without this, `visitor_face_observations` is empty project-wide and the
    # Family app's Visitors tab shows its empty state to every account, while
    # the Care visitor banner has nothing to announce.
    #
    # The embedding fields below are SYNTHETIC placeholders satisfying the
    # table's shape constraints -- they are not real biometric data and are
    # not derived from any person. Only the body_description is meaningful,
    # and it is the kind of text the Gemini describer actually produces.
    print("\nSeeding visitor history...")
    call("DELETE", f"/rest/v1/visitor_face_observations?facility_id=eq.{FACILITY_ID}")

    status, cameras = call(
        "GET", f"/rest/v1/cameras?facility_id=eq.{FACILITY_ID}&select=id,location_label"
    )
    entrance = None
    if isinstance(cameras, list) and cameras:
        entrance = next(
            (c["id"] for c in cameras if "entrance" in (c.get("location_label") or "").lower()),
            cameras[0]["id"],
        )

    def embedding_stub(seed: str) -> dict:
        digest = (seed * 64)[:64]
        return {
            "face_embedding_ciphertext": f"demo-synthetic-ciphertext-{seed}" + "0" * 32,
            "face_embedding_digest": "".join(c if c in "0123456789abcdef" else "a" for c in digest),
            "face_embedding_key_id": "demo-key-2026",
            "face_embedding_nonce": f"demo-nonce-{seed}",
            "face_embedding_algorithm": "AES-256-GCM",
        }

    visitors = [
        (300, "repeat_visitor", "b1",
         "An adult in a navy jacket and light trousers, carrying a small paper bag."),
        (180, "known_visitor", "c2",
         "An adult in a grey cardigan with a shoulder bag, holding flowers."),
        (95, "new_visitor", "d3",
         "An adult in a red raincoat and dark jeans, carrying a black backpack."),
    ]
    rows = []
    for minutes_ago, match_status, seed, description in visitors:
        row = {
            "facility_id": FACILITY_ID,
            "camera_id": entrance,
            "detected_at": (now - timedelta(minutes=minutes_ago)).isoformat(),
            "match_status": match_status,
            "body_description": description,
            "body_description_model": "gemini-flash-latest",
            "body_description_generated_at": (now - timedelta(minutes=minutes_ago)).isoformat(),
        }
        row.update(embedding_stub(seed))
        rows.append(row)

    status, _ = call("POST", "/rest/v1/visitor_face_observations", rows)
    print(f"  visitor observations (with Gemini-style descriptions): {status}")

    # A `new_visitor` insert fires create_resident_visitor_verification_prompts,
    # which opens a 2-minute prompt on every Hub bound to that camera. Left
    # alone it would expire unanswered long before judges arrive and escalate
    # to the care team, so the Hub starts from a neutral screen instead. The
    # notifications the same insert produced are kept -- those are what give
    # the Care visitor banner something real to announce.
    status, _ = call("DELETE", f"/rest/v1/visitor_verification_prompts?facility_id=eq.{FACILITY_ID}")
    print(f"  cleared auto-opened visitor prompts so the Hub starts neutral: {status}")

    print("\nVerifying...")
    for label, path, expected in [
        ("open incidents", f"/rest/v1/incident_events?facility_id=eq.{FACILITY_ID}&status=eq.open&select=id", 1),
        ("assistance requests", f"/rest/v1/assistance_requests?facility_id=eq.{FACILITY_ID}&select=id", 0),
        ("messages", f"/rest/v1/messages?facility_id=eq.{FACILITY_ID}&select=id", 0),
    ]:
        status, rows = call("GET", path)
        count = len(rows) if isinstance(rows, list) else -1
        mark = "OK " if count == expected else "!! "
        print(f"  {mark}{label}: {count} (expected {expected})")

    print("\nDemo state reset. Room 101 has one open critical fall alert waiting.")


if __name__ == "__main__":
    main()
