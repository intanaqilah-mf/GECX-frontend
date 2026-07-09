import uuid
from datetime import datetime, timezone

from google.cloud import firestore

from app.services.firestore import db
from app.services.event_service import create_event


def create_application(payload):
    application_id = f"APP_{uuid.uuid4().hex[:10]}"
    card_id = f"CARD_{uuid.uuid4().hex[:10]}"
    notification_id = f"NOTIF_{uuid.uuid4().hex[:10]}"
    now = datetime.now(timezone.utc)

    deep_link = f"acnbank://cards/{card_id}/activate"

    notification_title = "Your card is ready!"
    notification_body = (
        f"Congratulations! Your new {payload.selected_product_name} has been approved. "
        "Tap to activate and start using it."
    )

    application_document = {
        "application_id": application_id,
        "customer_id": payload.customer_id,
        "customer_email": payload.customer_email,
        "selected_product_id": payload.selected_product_id,
        "selected_product_name": payload.selected_product_name,
        "product_category": payload.product_category,
        "status": "approved",
        "decision": "approved",
        "card_id": card_id,
        "notification_id": notification_id,
        "channel": payload.channel,
        "source_agent": payload.source_agent,
        "session_id": payload.session_id,
        "created_at": now,
        "updated_at": now,
    }

    card_document = {
        "card_id": card_id,
        "customer_id": payload.customer_id,
        "application_id": application_id,
        "product_id": payload.selected_product_id,
        "product_name": payload.selected_product_name,
        "card_type": payload.selected_product_name,
        "card_number": f"4532 88{uuid.uuid4().hex[:2]} {uuid.uuid4().hex[:4]} 8842".upper(),
        "card_holder_name": payload.customer_id.replace("_", " ").upper(),
        "expiry_date": "12/28",
        "cvv": "412",
        "spending_limit": 10000.0,
        "spent_amount": 0.0,
        "credit_limit": "10000",
        "status": "ready_for_activation",
        "deep_link": deep_link,
        "is_latest": True,
        "channel": payload.channel,
        "source_agent": payload.source_agent,
        "session_id": payload.session_id,
        "created_at": now,
        "updated_at": now,
    }

    notification_document = {
        "notification_id": notification_id,
        "type": "card_approved",
        "status": "pending_mobile_app",
        "customer_id": payload.customer_id,
        "application_id": application_id,
        "card_id": card_id,
        "selected_product_name": payload.selected_product_name,
        "title": notification_title,
        "body": notification_body,
        "action": "activate_card",
        "deep_link": deep_link,
        "is_latest": True,
        "channel": payload.channel,
        "source_agent": payload.source_agent,
        "session_id": payload.session_id,
        "created_at": now,
        "updated_at": now,
    }

    db.collection("applications").document(application_id).set(application_document)
    db.collection("customer_cards").document(card_id).set(card_document)
    db.collection("notifications").document(notification_id).set(notification_document)

    # Update customer record with both has_card flag and the map of card info
    db.collection("customers").document(payload.customer_id).set({
        "has_card": True,
        "card_info": card_document
    }, merge=True)

    application_event = create_event(
        event_type="credit_card.application_approved",
        customer_id=payload.customer_id,
        payload={
            "application_id": application_id,
            "card_id": card_id,
            "notification_id": notification_id,
            "product_id": payload.selected_product_id,
            "product_name": payload.selected_product_name,
            "channel": payload.channel,
            "source_agent": payload.source_agent,
            "session_id": payload.session_id,
        },
    )

    return {
        **application_document,
        "card": card_document,
        "notification": notification_document,
        "event": application_event,
        "mobile_action": {
            "type": "activate_card",
            "deep_link": deep_link,
            "card_id": card_id,
        },
        "push_preview": {
            "title": notification_title,
            "body": notification_body,
        },
        "user_message": (
            f"Your {payload.selected_product_name} has been approved. "
            "Open the ACN Bank app to activate your card."
        ),
    }


def _query_customer_collection(collection_name: str, customer_id: str):
    # Fetching without order_by first to avoid mandatory composite index requirements
    # which can cause 500 errors if the user hasn't created them in the console.
    docs = (
        db.collection(collection_name)
        .where("customer_id", "==", customer_id)
        .stream()
    )

    results = [doc.to_dict() for doc in docs]

    # Sort in memory by created_at descending
    results.sort(
        key=lambda x: x.get("created_at") or datetime.min.replace(tzinfo=timezone.utc),
        reverse=True
    )

    return results


def get_customer_applications(customer_id: str):
    applications = _query_customer_collection("applications", customer_id)

    return {
        "latest_application": applications[0] if applications else None,
        "applications": applications,
        "count": len(applications),
    }


def get_customer_cards(customer_id: str):
    cards = _query_customer_collection("customer_cards", customer_id)

    return {
        "latest_card": cards[0] if cards else None,
        "cards": cards,
        "count": len(cards),
    }


def get_customer_notifications(customer_id: str):
    notifications = _query_customer_collection("notifications", customer_id)

    return {
        "latest_notification": notifications[0] if notifications else None,
        "notifications": notifications,
        "count": len(notifications),
    }