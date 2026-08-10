"""Move every demo account onto the simplified name + password sign-in.

The unified Meridian app asks for a facility, then a name (`First_Last`), then
a password. Supabase Auth is still email/password underneath, so the app
derives the email as `first_last@<facility_id>.meridian.invalid` and the user
never sees or types it.

This rewrites the EXISTING auth users rather than creating new ones. Every
link that matters -- facility_members, family_member_links,
resident_hub_devices -- is keyed on the user's uuid, not the email, so
changing the address preserves all of them. Creating fresh users would orphan
every one of those rows.

    python tools/migrate_demo_logins.py
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
FACILITY_ID = "meridian-demo"
EMAIL_DOMAIN = f"{FACILITY_ID}.meridian.invalid"

# Simple, typeable, and grouped by interface so a demo card has three lines
# rather than sixteen. This is a demo convenience, not a security model --
# real deployments would issue per-person credentials.
PASSWORDS = {"care": "sunrise", "hub": "bluebird", "family": "garden7"}

# old email -> (First_Last, role class)
ACCOUNTS = {
    "lin.care": ("Lin_Nakamura", "care"),
    "james.care": ("James_Whitfield", "care"),
    "nadia.care": ("Nadia_Osei", "care"),
    "room101.hub": ("Maggie_Alvarez", "hub"),
    "room104.hub": ("Harold_Chen", "hub"),
    "room112.hub": ("Ruth_Okafor", "hub"),
    "room118.hub": ("Frank_Delgado", "hub"),
    "dana.family": ("Dana_Alvarez", "family"),
    "marcus.family": ("Marcus_Alvarez", "family"),
    "priya.family": ("Priya_Chen", "family"),
    "sam.family": ("Sam_Chen", "family"),
    "wei.family": ("Wei_Chen", "family"),
    "ade.family": ("Ade_Okafor", "family"),
    "tolu.family": ("Tolu_Okafor", "family"),
    "elena.family": ("Elena_Delgado", "family"),
    "rosa.family": ("Rosa_Delgado", "family"),
}


def read_env(key: str) -> str:
    for line in (REPO_ROOT / ".env").read_text().splitlines():
        line = line.strip()
        if line.startswith(f"{key}="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"{key} not found in .env")


SUPABASE_URL = read_env("SUPABASE_URL")
SERVICE_KEY = read_env("SUPABASE_SERVICE_ROLE_KEY")


def call(method: str, path: str, body=None, attempts: int = 3):
    url = f"{SUPABASE_URL}{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    }
    last: Exception | None = None
    for attempt in range(attempts):
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                raw = response.read().decode()
                return response.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as error:
            return error.code, error.read().decode()
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last = error
            if attempt < attempts - 1:
                time.sleep(1.5 * (attempt + 1))
    return 0, f"network error: {last}"


def derived_email(name: str) -> str:
    return f"{name.lower()}@{EMAIL_DOMAIN}"


def main() -> None:
    print("Listing existing auth users...")
    status, payload = call("GET", "/auth/v1/admin/users?per_page=200")
    if status != 200:
        raise SystemExit(f"could not list users: {status} {payload}")

    users = payload.get("users", payload) if isinstance(payload, dict) else payload
    by_email = {u["email"]: u["id"] for u in users if u.get("email")}

    updated = 0
    for old_prefix, (display_name, role) in ACCOUNTS.items():
        old_email = f"{old_prefix}@meridian-demo.invalid"
        new_email = derived_email(display_name)
        password = PASSWORDS[role]

        user_id = by_email.get(old_email) or by_email.get(new_email)
        if not user_id:
            print(f"  SKIP  {display_name}: no existing user for {old_email}")
            continue

        # Also stash the human name in metadata. The Family app already looks
        # there first for a sender name, so this removes its one-time
        # "what's your name?" prompt entirely.
        status, payload = call(
            "PUT",
            f"/auth/v1/admin/users/{user_id}",
            {
                "email": new_email,
                "password": password,
                "email_confirm": True,
                "user_metadata": {"full_name": display_name.replace("_", " ")},
            },
        )
        if status == 200:
            print(f"  OK    {display_name:<18} -> {new_email}  ({password})")
            updated += 1
        else:
            print(f"  FAIL  {display_name}: {status} {payload}")

    print(f"\n{updated}/{len(ACCOUNTS)} accounts migrated.")
    print("\nDemo logins — facility: Chronos Village Senior Sanctuary")
    print(f"  MeridianCare    Lin_Nakamura     {PASSWORDS['care']}")
    print(f"  MeridianHub     Maggie_Alvarez   {PASSWORDS['hub']}")
    print(f"  MeridianFamily  Dana_Alvarez     {PASSWORDS['family']}")


if __name__ == "__main__":
    main()
