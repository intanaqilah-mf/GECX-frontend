import uuid
from datetime import datetime, timezone

from app.services.firestore import db


def create_card_approval_notification(payload):
    notification_id = f"NOTIF_{uuid.uuid4().hex[:10]}"
    deep_link = payload.deep_link or f"acnbank://cards/{payload.card_id}/activate"

    document = {
        "notification_id": notification_id,
        "type": "card_approval",
        "status": "pending_mobile_app",
        "customer_id": payload.customer_id,
        "application_id": payload.application_id,
        "card_id": payload.card_id,
        "selected_product_name": payload.selected_product_name,
        "deep_link": deep_link,
        "channel": payload.channel,
        "source_agent": payload.source_agent,
        "session_id": payload.session_id,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }

    db.collection("notifications").document(notification_id).set(document)

    return {
        **document,
        "delivery_channel": "pending_mobile_app",
        "user_message": "Your card is ready. I prepared your activation link for the ACN Bank app."
    }