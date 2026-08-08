"""Seed a demo facility into a live Supabase project.

Creates the auth users, facility, cameras, residents, family links, consents,
Hub device bindings, and a realistic incident history that the three apps read.

Everything here goes through the service-role key, which is the only credential
allowed to write these tables directly (see the RLS grants in
20260702220000_initial_security_and_ingest.sql).  Running this from a client
context will fail, and that is intentional.

    python tools/seed_demo_data.py            # create/refresh demo data
    python tools/seed_demo_data.py --wipe     # remove it again

The script is idempotent: re-running it updates rather than duplicating, so it
is safe to run repeatedly while rehearsing the demo.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

FACILITY_ID = "meridian-demo"
FACILITY_SLUG = "meridian-demo"
FACILITY_NAME = "Willow Creek Senior Living"
FACILITY_TZ = "America/Los_Angeles"

DEMO_PASSWORD = "MeridianDemo!2026"
DEMO_DOMAIN = "meridian-demo.invalid"  # reserved TLD; never routes real mail

# Four residents, each with a room, a Hub tablet, and 2-3 linked family members.
RESIDENTS = [
    {
        "id": "res-maggie",
        "name": "Maggie Alvarez",
        "room": "101",
        "risk_flags": ["fall_history", "night_wandering"],
        "care_notes": "Uses a walker. Prefers the hallway light left on overnight.",
        "family": ["dana", "marcus"],
    },
    {
        "id": "res-harold",
        "name": "Harold Chen",
        "room": "104",
        "risk_flags": ["low_vision"],
        "care_notes": "Low vision. Announce yourself before entering.",
        "family": ["priya", "sam", "wei"],
    },
    {
        "id": "res-ruth",
        "name": "Ruth Okafor",
        "room": "112",
        "risk_flags": [],
        "care_notes": "Independent. Enjoys the morning activity group.",
        "family": ["ade", "tolu"],
    },
    {
        "id": "res-frank",
        "name": "Frank Delgado",
        "room": "118",
        "risk_flags": ["fall_history", "memory_support"],
        "care_notes": "Memory support. Familiar faces reduce agitation.",
        "family": ["elena", "rosa"],
    },
]

FAMILY = {
    "dana": "Dana Alvarez",
    "marcus": "Marcus Alvarez",
    "priya": "Priya Chen",
    "sam": "Sam Chen",
    "wei": "Wei Chen",
    "ade": "Ade Okafor",
    "tolu": "Tolu Okafor",
    "elena": "Elena Delgado",
    "rosa": "Rosa Delgado",
}

CAREGIVERS = [
    ("nadia", "Nadia Osei", "admin"),
    ("james", "James Whitfield", "caregiver"),
    ("lin", "Lin Nakamura", "caregiver"),
]

CAMERAS = [
    ("cam-101", "room-101", "Room 101", "Room 101"),
    ("cam-104", "room-104", "Room 104", "Room 104"),
    ("cam-112", "room-112", "Room 112", "Room 112"),
    ("cam-118", "room-118", "Room 118", "Room 118"),
    ("cam-entry", "main-entrance", "Main Entrance", "Main Entrance"),
]


# --------------------------------------------------------------------------
# Minimal Supabase REST client (stdlib only, so this runs anywhere)
# --------------------------------------------------------------------------


class Supabase:
    def __init__(self, url: str, service_key: str) -> None:
        self.url = url.rstrip("/")
        self.key = service_key

    def _request(self, method: str, path: str, body=None, headers=None):
        url = f"{self.url}{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("apikey", self.key)
        req.add_header("Authorization", f"Bearer {self.key}")
        req.add_header("Content-Type", "application/json")
        for name, value in (headers or {}).items():
            req.add_header(name, value)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                raw = response.read().decode()
                return response.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode()
            return exc.code, raw

    def upsert(self, table: str, rows: list[dict], on_conflict: str | None = None):
        if not rows:
            return None
        path = f"/rest/v1/{table}"
        if on_conflict:
            path += f"?on_conflict={on_conflict}"
        headers = {"Prefer": "resolution=merge-duplicates,return=minimal"}
        # PostgREST rejects a bulk insert whose objects have differing keys
        # ("All object keys must match"), and our rows legitimately differ --
        # an open incident has no acknowledged_at. Pad every row to the union
        # of keys so the absent ones arrive as explicit nulls.
        columns = {key for row in rows for key in row}
        rows = [{key: row.get(key) for key in columns} for row in rows]
        status, payload = self._request("POST", path, rows, headers)
        if status >= 300:
            raise RuntimeError(f"upsert {table} -> {status}: {payload}")
        return payload

    def delete(self, table: str, query: str):
        status, payload = self._request("DELETE", f"/rest/v1/{table}?{query}")
        if status >= 300 and status != 404:
            raise RuntimeError(f"delete {table} -> {status}: {payload}")

    def create_user(self, email: str, password: str, metadata: dict) -> str:
        """Create an auth user, returning its id.  Reuses one if it exists."""
        status, payload = self._request(
            "POST",
            "/auth/v1/admin/users",
            {
                "email": email,
                "password": password,
                "email_confirm": True,
                "user_metadata": metadata,
            },
        )
        if status < 300 and isinstance(payload, dict):
            return payload["id"]

        # Already registered -> look the existing user up instead.
        existing = self.find_user(email)
        if existing:
            return existing
        raise RuntimeError(f"create_user {email} -> {status}: {payload}")

    def find_user(self, email: str) -> str | None:
        status, payload = self._request(
            "GET", f"/auth/v1/admin/users?page=1&per_page=200"
        )
        if status >= 300 or not isinstance(payload, dict):
            return None
        for user in payload.get("users", []):
            if user.get("email", "").lower() == email.lower():
                return user["id"]
        return None

    def delete_user(self, email: str) -> None:
        user_id = self.find_user(email)
        if user_id:
            self._request("DELETE", f"/auth/v1/admin/users/{user_id}")


def load_env() -> tuple[str, str]:
    env_path = REPO_ROOT / ".env"
    values = dict(os.environ)
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            values.setdefault(key.strip(), value.strip())

    url = values.get("SUPABASE_URL")
    key = values.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit(
            "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env "
            "or the environment."
        )
    return url, key


def email_for(slug: str, role: str) -> str:
    return f"{slug}.{role}@{DEMO_DOMAIN}"


# --------------------------------------------------------------------------
# Incident history
# --------------------------------------------------------------------------


def build_incidents(now: datetime, caregiver_ids: list[str]) -> list[dict]:
    """A history with enough acknowledged incidents to make the Hub's ETA
    estimator return 'data_derived' rather than the 5-minute default, plus a
    couple of live open alerts for the judges to act on."""
    rng = random.Random(20260807)
    rows: list[dict] = []

    # Resolved history over the past 10 days -> feeds response metrics + ETA.
    for day in range(1, 11):
        for resident in RESIDENTS:
            if rng.random() > 0.55:
                continue
            detected = now - timedelta(days=day, hours=rng.randint(0, 20))
            ack_delay = rng.randint(38, 95)
            resolve_delay = ack_delay + rng.randint(60, 400)
            event_type = rng.choice(
                ["fall_suspected", "long_lie", "night_activity", "unusual_inactivity"]
            )
            severity = "critical" if event_type in ("fall_suspected", "long_lie") else "warning"
            rows.append(
                {
                    "source_event_id": f"seed-{resident['id']}-{day}-{event_type}",
                    "facility_id": FACILITY_ID,
                    "room_id": resident["room"],
                    "resident_id": resident["id"],
                    "camera_id": f"cam-{resident['room']}",
                    "event_type": event_type,
                    "severity": severity,
                    "status": "resolved",
                    "confidence": round(rng.uniform(0.72, 0.96), 4),
                    "detected_at": detected.isoformat(),
                    "generated_at": (detected + timedelta(seconds=1)).isoformat(),
                    "acknowledged_at": (detected + timedelta(seconds=ack_delay)).isoformat(),
                    "acknowledged_by": rng.choice(caregiver_ids),
                    "resolved_at": (detected + timedelta(seconds=resolve_delay)).isoformat(),
                    "resolved_by": rng.choice(caregiver_ids),
                    "resolution_note": "Assisted resident. No injury.",
                    "reason_codes": ["pose_confidence", "duration_threshold"],
                    "summary": f"{resident['name']} — {event_type.replace('_', ' ')} in room {resident['room']}.",
                }
            )

    # Today, within the shift handoff window: 2 resolved + 1 open.
    handoff = [
        ("res-harold", "night_activity", "warning", 5, "resolved"),
        ("res-ruth", "unusual_inactivity", "warning", 3, "resolved"),
        ("res-maggie", "fall_suspected", "critical", 0, "open"),
    ]
    for resident_id, event_type, severity, hours_ago, status in handoff:
        resident = next(r for r in RESIDENTS if r["id"] == resident_id)
        detected = now - timedelta(hours=hours_ago, minutes=rng.randint(4, 40))
        row = {
            "source_event_id": f"seed-today-{resident_id}-{event_type}",
            "facility_id": FACILITY_ID,
            "room_id": resident["room"],
            "resident_id": resident_id,
            "camera_id": f"cam-{resident['room']}",
            "event_type": event_type,
            "severity": severity,
            "status": status,
            "confidence": round(rng.uniform(0.78, 0.94), 4),
            "detected_at": detected.isoformat(),
            "generated_at": (detected + timedelta(seconds=1)).isoformat(),
            "reason_codes": ["pose_confidence", "duration_threshold"],
            "summary": f"{resident['name']} may need help in room {resident['room']}.",
        }
        if status == "resolved":
            row["acknowledged_at"] = (detected + timedelta(seconds=52)).isoformat()
            row["acknowledged_by"] = caregiver_ids[0]
            row["resolved_at"] = (detected + timedelta(seconds=300)).isoformat()
            row["resolved_by"] = caregiver_ids[0]
            row["resolution_note"] = "Checked on resident. Settled comfortably."
        rows.append(row)

    return rows


def build_rollups(now: datetime) -> list[dict]:
    rng = random.Random(7)
    rows = []
    for day in range(0, 7):
        date = (now - timedelta(days=day)).date().isoformat()
        for resident in RESIDENTS:
            rows.append(
                {
                    "facility_id": FACILITY_ID,
                    "resident_id": resident["id"],
                    "rollup_date": date,
                    "daytime_pattern": rng.choice(
                        ["usual", "usual", "usual", "higher_than_usual", "lower_than_usual"]
                    ),
                    "nighttime_pattern": rng.choice(["usual", "usual", "higher_than_usual"]),
                    "baseline_status": "ready" if day < 5 else "building",
                    "observation_status": "sufficient",
                }
            )
    return rows


# --------------------------------------------------------------------------
# Seed / wipe
# --------------------------------------------------------------------------


def seed(db: Supabase) -> None:
    now = datetime.now(timezone.utc)
    print("Creating auth users...")

    caregiver_ids: list[str] = []
    for slug, name, role in CAREGIVERS:
        uid = db.create_user(
            email_for(slug, "care"), DEMO_PASSWORD, {"display_name": name, "app": "care"}
        )
        caregiver_ids.append(uid)

    family_ids = {
        slug: db.create_user(
            email_for(slug, "family"), DEMO_PASSWORD, {"display_name": name, "app": "family"}
        )
        for slug, name in FAMILY.items()
    }

    hub_ids = {
        resident["id"]: db.create_user(
            email_for(f"room{resident['room']}", "hub"),
            DEMO_PASSWORD,
            {"display_name": f"Hub — Room {resident['room']}", "app": "hub"},
        )
        for resident in RESIDENTS
    }

    print("Seeding facility...")
    db.upsert(
        "facilities",
        [
            {
                "id": FACILITY_ID,
                "slug": FACILITY_SLUG,
                "display_name": FACILITY_NAME,
                "timezone": FACILITY_TZ,
            }
        ],
        on_conflict="id",
    )

    db.upsert(
        "facility_members",
        [
            {"facility_id": FACILITY_ID, "user_id": uid, "role": role}
            for uid, (_, _, role) in zip(caregiver_ids, CAREGIVERS)
        ]
        + [
            {"facility_id": FACILITY_ID, "user_id": uid, "role": "family"}
            for uid in family_ids.values()
        ],
        on_conflict="facility_id,user_id",
    )

    db.upsert(
        "cameras",
        [
            {
                "id": cam_id,
                "facility_id": FACILITY_ID,
                "external_id": external,
                "display_name": display,
                "location_label": location,
                "status": "online",
                "last_seen_at": now.isoformat(),
            }
            for cam_id, external, display, location in CAMERAS
        ],
        on_conflict="id",
    )

    print("Seeding residents...")
    db.upsert(
        "people",
        [
            {
                "id": r["id"],
                "facility_id": FACILITY_ID,
                "display_name": r["name"],
                "person_type": "resident",
                "external_ref": r["id"],
            }
            for r in RESIDENTS
        ],
        on_conflict="id",
    )

    db.upsert(
        "resident_profiles",
        [
            {
                "facility_id": FACILITY_ID,
                "person_id": r["id"],
                "room_id": r["room"],
                "display_name": r["name"],
                "risk_flags": r["risk_flags"],
                "care_notes": r["care_notes"],
            }
            for r in RESIDENTS
        ],
        on_conflict="person_id",
    )

    # Monitoring + family visibility consent.  Without family_visibility the
    # Family app sees nothing and SMS escalation is suppressed by design.
    # Cleared first: a re-run would otherwise stack duplicate active consents,
    # which the notification triggers used to multiply into duplicate pushes.
    db.delete("person_consents", f"facility_id=eq.{FACILITY_ID}")
    db.upsert(
        "person_consents",
        [
            {
                "facility_id": FACILITY_ID,
                "person_id": r["id"],
                "consent_scope": scope,
                "consent_status": "active",
                "consent_source": "demo_seed",
            }
            for r in RESIDENTS
            for scope in ("monitoring", "family_visibility")
        ],
    )

    print("Linking families...")
    db.upsert(
        "family_member_links",
        [
            {
                "facility_id": FACILITY_ID,
                "user_id": family_ids[slug],
                "resident_id": r["id"],
            }
            for r in RESIDENTS
            for slug in r["family"]
        ],
        on_conflict="user_id,resident_id",
    )

    print("Binding Hub devices...")
    # The active-device uniqueness is enforced by a *partial* unique index
    # (hub_user_id where active), which on_conflict cannot target. Clearing the
    # facility's bindings first is what makes a re-run idempotent.
    db.delete("resident_hub_devices", f"facility_id=eq.{FACILITY_ID}")
    db.upsert(
        "resident_hub_devices",
        [
            {
                "facility_id": FACILITY_ID,
                "resident_id": r["id"],
                "room_id": r["room"],
                "hub_user_id": hub_ids[r["id"]],
                "visitor_camera_id": "cam-entry",
                "active": True,
            }
            for r in RESIDENTS
        ],
    )

    print("Seeding incident history...")
    incidents = build_incidents(now, caregiver_ids)
    db.upsert("incident_events", incidents, on_conflict="source_event_id")

    print("Seeding activity rollups...")
    db.upsert(
        "resident_activity_rollups",
        build_rollups(now),
        on_conflict="facility_id,resident_id,rollup_date",
    )

    print("\nDone. Demo accounts (password: %s)\n" % DEMO_PASSWORD)
    print("  MeridianCare (staff):")
    for slug, name, role in CAREGIVERS:
        print(f"    {email_for(slug, 'care'):<48} {name} ({role})")
    print("\n  MeridianFamily:")
    for r in RESIDENTS:
        for slug in r["family"]:
            print(f"    {email_for(slug, 'family'):<48} {FAMILY[slug]} -> {r['name']}")
    print("\n  MeridianHub (one per room):")
    for r in RESIDENTS:
        print(f"    {email_for('room' + r['room'], 'hub'):<48} Room {r['room']} ({r['name']})")
    print(f"\n  {len(incidents)} incidents seeded, 1 currently open in room 101.")


def wipe(db: Supabase) -> None:
    print("Removing demo data...")
    for table, query in [
        ("resident_activity_rollups", f"facility_id=eq.{FACILITY_ID}"),
        ("assistance_requests", f"facility_id=eq.{FACILITY_ID}"),
        ("notifications", f"facility_id=eq.{FACILITY_ID}"),
        ("incident_events", f"facility_id=eq.{FACILITY_ID}"),
        ("resident_hub_devices", f"facility_id=eq.{FACILITY_ID}"),
        ("family_member_links", f"facility_id=eq.{FACILITY_ID}"),
        ("person_consents", f"facility_id=eq.{FACILITY_ID}"),
        ("resident_profiles", f"facility_id=eq.{FACILITY_ID}"),
        ("people", f"facility_id=eq.{FACILITY_ID}"),
        ("cameras", f"facility_id=eq.{FACILITY_ID}"),
        ("facility_members", f"facility_id=eq.{FACILITY_ID}"),
        ("facilities", f"id=eq.{FACILITY_ID}"),
    ]:
        db.delete(table, query)

    for slug, _, _ in CAREGIVERS:
        db.delete_user(email_for(slug, "care"))
    for slug in FAMILY:
        db.delete_user(email_for(slug, "family"))
    for r in RESIDENTS:
        db.delete_user(email_for(f"room{r['room']}", "hub"))
    print("Demo data removed.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wipe", action="store_true", help="remove the demo data")
    args = parser.parse_args()

    url, key = load_env()
    db = Supabase(url, key)
    if args.wipe:
        wipe(db)
    else:
        seed(db)


if __name__ == "__main__":
    main()
