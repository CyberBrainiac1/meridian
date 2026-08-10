"""Pre-demo integration check: exercise every live path the three apps use.

Runs each check three times. A single pass proves a path works once; three
passes prove it is repeatable and idempotent, which is what actually matters
when judges tap the same button twice or a poll fires mid-action.

Every check uses the SAME anon key and the SAME auth flow the iOS apps use --
not the service-role key. A service-role test proves nothing about whether a
resident's device can actually reach its own data, and that gap is exactly
how a real bug reached the demo build once already.

    python tools/demo_readiness_check.py

Exits non-zero if anything fails, so it can gate a rehearsal.
"""

from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ITERATIONS = 3

# The unified app signs in with facility + `First_Last` + a simple password,
# and derives this address itself. Nobody types an email any more, but Supabase
# Auth is still email/password underneath, so the check uses the same derived
# form the app builds — testing what the app actually sends, not a convenient
# equivalent. Getting that distinction wrong is how a broken send path once
# passed a green test.
FACILITY_ID = "meridian-demo"
PASSWORDS = {"care": "sunrise", "hub": "bluebird", "family": "garden7"}
ACCOUNTS = {
    "hub_101": ("Maggie_Alvarez", "hub"),
    "hub_104": ("Harold_Chen", "hub"),
    "care_lin": ("Lin_Nakamura", "care"),
    "care_nadia": ("Nadia_Osei", "care"),
    "family_dana": ("Dana_Alvarez", "family"),
    "family_priya": ("Priya_Chen", "family"),
}

results: list[tuple[str, bool, str]] = []


def read_env(path: Path, key: str) -> str:
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith(f"{key}="):
            return line.split("=", 1)[1].strip()
        # xcconfig style: KEY = value, and its URL is split to dodge the
        # `//` comment token, so rejoin it.
        if line.startswith(f"{key} ="):
            return line.split("=", 1)[1].strip().replace("/$()/", "//")
    raise SystemExit(f"{key} not found in {path}")


SUPABASE_URL = read_env(REPO_ROOT / ".env", "SUPABASE_URL")
# Deliberately the iOS apps' own key, from the app config, not the web one.
ANON_KEY = read_env(
    REPO_ROOT / "meridian_hub_app" / "Config" / "Secrets.xcconfig",
    "MERIDIAN_SUPABASE_ANON_KEY",
)
SERVICE_KEY = read_env(REPO_ROOT / ".env", "SUPABASE_SERVICE_ROLE_KEY")


def request(method: str, path: str, token: str, body=None, prefer: str | None = None, attempts: int = 3):
    """One request, retried on transient transport failure.

    A dropped connection on venue wifi is not a failing check, and reporting
    it as one right before a demo is worse than useless -- it sends you
    hunting a bug that isn't there. Only a real HTTP response counts as a
    result.
    """
    url = f"{SUPABASE_URL}{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer

    last: Exception | None = None
    for attempt in range(attempts):
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                raw = response.read().decode()
                return response.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as error:
            raw = error.read().decode()
            try:
                return error.code, json.loads(raw)
            except json.JSONDecodeError:
                return error.code, raw
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last = error
            if attempt < attempts - 1:
                time.sleep(1.5 * (attempt + 1))
    return 0, f"network error after {attempts} attempts: {last}"


def sign_in(display_name: str, role: str) -> str:
    """Mirrors AuthViewModel.email(for:facilityId:) exactly."""
    email = f"{display_name.lower()}@{FACILITY_ID}.meridian.invalid"
    status, payload = request(
        "POST",
        "/auth/v1/token?grant_type=password",
        ANON_KEY,
        {"email": email, "password": PASSWORDS[role]},
    )
    if status != 200 or "access_token" not in payload:
        raise SystemExit(f"sign-in failed for {display_name} ({email}): {status} {payload}")
    return payload["access_token"]


def check(name: str, condition: bool, detail: str = "") -> None:
    results.append((name, condition, detail))
    print(f"  {'PASS' if condition else 'FAIL'}  {name}{f' -- {detail}' if detail and not condition else ''}")


def service_delete(path: str) -> None:
    req = urllib.request.Request(
        f"{SUPABASE_URL}{path}",
        headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}"},
        method="DELETE",
    )
    try:
        urllib.request.urlopen(req, timeout=15).read()
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError):
        pass


def service_patch(path: str, body: dict) -> None:
    """Restore a fixture this check consumed, using the service role."""
    req = urllib.request.Request(
        f"{SUPABASE_URL}{path}",
        data=json.dumps(body).encode(),
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
        },
        method="PATCH",
    )
    try:
        urllib.request.urlopen(req, timeout=15).read()
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError):
        pass


def run_iteration(index: int, tokens: dict[str, str]) -> None:
    print(f"\n--- iteration {index} of {ITERATIONS} ---")

    # ---- Auth / role gates -------------------------------------------------
    status, payload = request("GET", "/rest/v1/resident_hub_profile?select=*", tokens["hub_101"])
    check("hub sees exactly one bound profile", status == 200 and len(payload) == 1, str(payload))

    status, payload = request("GET", "/rest/v1/resident_hub_profile?select=*", tokens["care_lin"])
    check("caregiver is NOT a hub device (role gate)", status == 200 and payload == [], str(payload))

    status, payload = request("GET", "/rest/v1/family_linked_residents?select=*", tokens["family_dana"])
    check("family sees linked resident(s)", status == 200 and len(payload) >= 1, str(payload))

    # ---- Hub read paths (all four feeds HubFeedService loads together) -----
    for feed in (
        "resident_hub_assistance_feed",
        "resident_hub_visitor_prompt_feed",
        "resident_hub_medication_feed",
        "resident_hub_activity_feed",
    ):
        status, payload = request("GET", f"/rest/v1/{feed}?select=*", tokens["hub_101"])
        # These are async-let'd together in the app: one failure blanks the
        # whole resident screen, so each must independently succeed.
        check(f"hub feed {feed}", status == 200 and isinstance(payload, list), f"{status} {payload}")

    # ---- Care read paths ---------------------------------------------------
    for table in (
        "incident_events?select=id&limit=1",
        "assistance_requests?select=id&limit=1",
        "facility_medication_schedule?select=medication_id&limit=1",
        "facility_activity_schedule?select=activity_id&limit=1",
        "handoff_notes?select=id&limit=1",
        "caregiver_shifts?select=id&limit=1",
        "resident_emergency_contacts?select=id&limit=1",
        "resident_profiles?select=id&limit=1",
    ):
        status, payload = request("GET", f"/rest/v1/{table}", tokens["care_lin"])
        check(f"care read {table.split('?')[0]}", status == 200, f"{status} {payload}")

    # ---- Family read paths -------------------------------------------------
    for table in ("family_incident_feed", "family_visitor_feed", "family_activity_rollup_feed"):
        status, payload = request("GET", f"/rest/v1/{table}?select=*&limit=1", tokens["family_dana"])
        check(f"family read {table}", status == 200, f"{status} {payload}")

    # ---- Privacy boundary: family must NOT reach clinical tables ----------
    for table in ("resident_medications", "handoff_notes", "medication_administrations"):
        status, payload = request("GET", f"/rest/v1/{table}?select=*&limit=1", tokens["family_dana"])
        blocked = status in (401, 403) or payload == []
        check(f"family BLOCKED from {table}", blocked, f"{status} {payload}")

    # ---- Assistance request: the headline demo moment ---------------------
    status, payload = request(
        "POST", "/rest/v1/rpc/create_resident_assistance_request", tokens["hub_101"],
        {"p_request_kind": "emergency"},
    )
    created = status in (200, 201) and isinstance(payload, dict) and payload.get("status") == "open"
    check("hub creates emergency request", created, f"{status} {payload}")
    request_id = payload.get("id") if isinstance(payload, dict) else None

    if request_id:
        status, rows = request(
            "GET", f"/rest/v1/assistance_requests?id=eq.{request_id}&select=*", tokens["care_lin"]
        )
        check("care sees the request", status == 200 and len(rows) == 1, f"{status} {rows}")

        status, payload = request(
            "POST", "/rest/v1/rpc/respond_to_assistance_request", tokens["care_lin"],
            {"p_assistance_request_id": request_id, "p_new_status": "acknowledged"},
        )
        check("care acknowledges request", status == 200 and payload.get("status") == "acknowledged", f"{status} {payload}")
        service_delete(f"/rest/v1/assistance_requests?id=eq.{request_id}")

    # ---- Messaging both directions ----------------------------------------
    status, payload = request(
        "POST", "/rest/v1/rpc/send_message", tokens["hub_101"],
        {"p_resident_id": "res-maggie", "p_body": f"readiness check {index}"},
    )
    check("hub sends message", status == 200 and payload.get("sender_role") == "resident", f"{status} {payload}")

    status, payload = request(
        "POST", "/rest/v1/rpc/send_message", tokens["family_dana"],
        {"p_resident_id": "res-maggie", "p_body": f"family reply {index}", "p_sender_name": "Dana Alvarez"},
    )
    check("family sends message", status == 200 and payload.get("sender_role") == "family", f"{status} {payload}")

    status, rows = request("GET", "/rest/v1/messages?resident_id=eq.res-maggie&select=*", tokens["hub_101"])
    check("hub reads both messages", status == 200 and len(rows) >= 2, f"{status} {len(rows) if isinstance(rows, list) else rows}")

    # Cross-resident isolation: Priya is linked to Harold, not Maggie.
    status, payload = request(
        "POST", "/rest/v1/rpc/send_message", tokens["family_priya"],
        {"p_resident_id": "res-maggie", "p_body": "should not land"},
    )
    check("unrelated family BLOCKED from thread", status >= 400, f"{status} {payload}")

    status, rows = request("GET", "/rest/v1/messages?resident_id=eq.res-maggie&select=id", tokens["hub_104"])
    check("other hub BLOCKED from thread", status == 200 and rows == [], f"{status} {rows}")

    service_delete("/rest/v1/messages?resident_id=eq.res-maggie")

    # ---- Medication + activity self-report and staff override -------------
    status, doses = request(
        "GET", "/rest/v1/resident_hub_medication_feed?select=*&status=eq.outstanding&limit=1", tokens["hub_101"]
    )
    if status == 200 and doses:
        dose = doses[0]
        status, payload = request(
            "POST", "/rest/v1/rpc/resident_report_medication_taken", tokens["hub_101"],
            {"p_medication_id": dose["medication_id"], "p_scheduled_for": dose["scheduled_for"]},
        )
        check("resident self-reports medication", status == 200 and payload.get("self_reported") is True, f"{status} {payload}")

        # Staff must be able to correct a resident's self-report.
        status, payload = request(
            "POST", "/rest/v1/rpc/record_medication_administration", tokens["care_lin"],
            {"p_medication_id": dose["medication_id"], "p_scheduled_for": dose["scheduled_for"],
             "p_status": "refused", "p_note": "readiness check"},
        )
        check("staff overrides self-report", status == 200 and payload.get("status") == "refused", f"{status} {payload}")
    else:
        check("medication dose available to test", False, f"{status} {doses}")

    status, acts = request(
        "GET", "/rest/v1/resident_hub_activity_feed?select=*&status=eq.outstanding&limit=1", tokens["hub_101"]
    )
    if status == 200 and acts:
        act = acts[0]
        status, payload = request(
            "POST", "/rest/v1/rpc/resident_report_activity_done", tokens["hub_101"],
            {"p_activity_id": act["activity_id"], "p_scheduled_for": act["scheduled_for"]},
        )
        check("resident self-reports activity", status == 200 and payload.get("self_reported") is True, f"{status} {payload}")
    else:
        check("activity slot available to test", False, f"{status} {acts}")

    service_delete("/rest/v1/medication_administrations?resident_id=eq.res-maggie")
    service_delete("/rest/v1/activity_completions?resident_id=eq.res-maggie")

    # ---- Incident lifecycle (the fall-alert demo path) --------------------
    status, incidents = request(
        "GET", "/rest/v1/incident_events?select=id,status&status=eq.open&limit=1", tokens["care_lin"]
    )
    if status == 200 and incidents:
        incident_id = incidents[0]["id"]
        status, payload = request(
            "POST", "/rest/v1/rpc/respond_to_incident", tokens["care_lin"],
            {"p_incident_id": incident_id, "p_new_status": "acknowledged"},
        )
        acked = status == 200 and payload.get("status") == "acknowledged"
        check("care acknowledges open incident", acked, f"{status} {payload}")

        # Idempotency: re-asserting the same status must be a no-op, not an
        # error -- two caregivers tapping at once is a real race.
        status, payload = request(
            "POST", "/rest/v1/rpc/respond_to_incident", tokens["care_nadia"],
            {"p_incident_id": incident_id, "p_new_status": "acknowledged"},
        )
        check("duplicate acknowledge is idempotent", status == 200, f"{status} {payload}")

        # Put it back. Acknowledging is destructive to the fixture, and
        # without this the next iteration has nothing to test -- which is
        # exactly how a rehearsal silently eats the demo's headline fall
        # alert and nobody notices until they're on stage.
        service_patch(
            f"/rest/v1/incident_events?id=eq.{incident_id}",
            {"status": "open", "acknowledged_by": None, "acknowledged_at": None},
        )
    else:
        check("open incident available to test", False,
              "no open incident -- run tools/reset_demo_state.py")


def main() -> None:
    print("Signing in as every demo account (facility + name + password)...")
    tokens = {key: sign_in(display_name, role) for key, (display_name, role) in ACCOUNTS.items()}
    print(f"  {len(tokens)} accounts OK")

    # The facility picker is the first thing anyone touches and runs BEFORE
    # sign-in, so it has to work for the `anon` role specifically.
    status, payload = request("POST", "/rest/v1/rpc/list_facilities", ANON_KEY, {})
    live = [f for f in payload if f.get("has_accounts")] if isinstance(payload, list) else []
    check(
        "facility picker readable when signed out",
        status == 200 and len(live) >= 1,
        f"{status} {payload}",
    )

    for index in range(1, ITERATIONS + 1):
        run_iteration(index, tokens)

    failures = [(name, detail) for name, ok, detail in results if not ok]
    total = len(results)
    print(f"\n{'=' * 60}")
    print(f"{total - len(failures)}/{total} checks passed across {ITERATIONS} iterations")
    if failures:
        print("\nFAILURES:")
        seen = set()
        for name, detail in failures:
            if name in seen:
                continue
            seen.add(name)
            print(f"  - {name}: {detail}")
        sys.exit(1)
    print("All demo paths green.")


if __name__ == "__main__":
    main()
