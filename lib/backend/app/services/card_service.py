from datetime import datetime, timezone

from app.services.firestore import db
from app.services.event_service import create_event


def get_card(card_id: str):
    card_ref = db.collection("customer_cards").document(card_id)
    card = card_ref.get()

    if not card.exists:
        return {
            "success": False,
            "message": "Card not found.",
            "card": None,
        }

    card_data = card.to_dict()

    application_id = card_data.get("application_id")
    customer_id = card_data.get("customer_id")

    application = None
    if application_id:
        application_doc = db.collection("applications").document(application_id).get()
        if application_doc.exists:
            application = application_doc.to_dict()

    latest_notification = None
    if customer_id:
        notification_docs = (
            db.collection("notifications")
            .where("customer_id", "==", customer_id)
            .where("card_id", "==", card_id)
            .stream()
        )

        notifications = [doc.to_dict() for doc in notification_docs]
        notifications.sort(
            key=lambda item: item.get("created_at"),
            reverse=True,
        )

        latest_notification = notifications[0] if notifications else None

    return {
        "success": True,
        "card": card_data,
        "application": application,
        "latest_notification": latest_notification,
        "screen_hint": {
            "screen": (
                "card_ready"
                if card_data.get("status") == "ready_for_activation"
                else "card_active"
            ),
            "primary_action": (
                "activate_card"
                if card_data.get("status") == "ready_for_activation"
                else "view_card"
            ),
        },
    }


def activate_card(card_id: str):
    card_ref = db.collection("customer_cards").document(card_id)
    card = card_ref.get()

    if not card.exists:
        return {
            "success": False,
            "message": "Card not found.",
        }

    card_data = card.to_dict()
    now = datetime.now(timezone.utc)

    previous_status = card_data.get("status")

    card_ref.update(
        {
            "status": "active",
            "activated_at": now,
            "updated_at": now,
        }
    )

    activation_event = create_event(
        event_type="credit_card.card_activated",
        customer_id=card_data.get("customer_id"),
        payload={
            "card_id": card_id,
            "application_id": card_data.get("application_id"),
            "previous_status": previous_status,
            "new_status": "active",
        },
    )

    return {
        "success": True,
        "card_id": card_id,
        "status": "active",
        "event": activation_event,
        "user_message": "Your card has been activated successfully.",
    }