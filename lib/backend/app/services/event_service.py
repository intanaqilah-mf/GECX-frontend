import uuid
from datetime import datetime, timezone

from app.services.firestore import db


def create_event(
    event_type: str,
    customer_id: str,
    payload: dict,
    source: str = "customer-platform-api",
):
    event_id = f"EVT_{uuid.uuid4().hex[:10]}"
    now = datetime.now(timezone.utc)

    document = {
        "event_id": event_id,
        "type": event_type,
        "customer_id": customer_id,
        "source": source,
        "status": "created",
        "payload": payload,
        "created_at": now,
    }

    db.collection("events").document(event_id).set(document)

    return document