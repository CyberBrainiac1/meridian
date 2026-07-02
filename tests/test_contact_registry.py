import tempfile
from pathlib import Path

from meridian_hub.alerting.contact_registry import Contact, ContactRegistry


def _registry():
    db_path = Path(tempfile.mkdtemp()) / "contacts.sqlite3"
    return ContactRegistry(db_path=str(db_path))


def test_contacts_returned_in_priority_order():
    registry = _registry()
    registry.add_contact(Contact("c-2", "res-1", "+15550002", "family", priority=2))
    registry.add_contact(Contact("c-1", "res-1", "+15550001", "caregiver", priority=1))
    contacts = registry.contacts_for_resident("res-1")
    assert [c.contact_id for c in contacts] == ["c-1", "c-2"]


def test_only_returns_contacts_for_requested_resident():
    registry = _registry()
    registry.add_contact(Contact("c-1", "res-1", "+15550001", "caregiver", priority=1))
    registry.add_contact(Contact("c-2", "res-2", "+15550002", "caregiver", priority=1))
    contacts = registry.contacts_for_resident("res-1")
    assert len(contacts) == 1
    assert contacts[0].contact_id == "c-1"


def test_no_contacts_returns_empty_list():
    registry = _registry()
    assert registry.contacts_for_resident("res-nobody") == []


def test_add_contact_upserts():
    registry = _registry()
    registry.add_contact(Contact("c-1", "res-1", "+15550001", "caregiver", priority=1))
    registry.add_contact(Contact("c-1", "res-1", "+15559999", "caregiver", priority=1))
    contacts = registry.contacts_for_resident("res-1")
    assert len(contacts) == 1
    assert contacts[0].phone_number == "+15559999"
