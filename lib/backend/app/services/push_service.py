from app.services.firestore import db
from app.services.application_service import get_customer_notifications


def get_customer_devices(customer_id: str):
    docs = (
        db.collection("customers")
        .document(customer_id)
        .collection("devices")
        .where("active", "==", True)
        .stream()
    )

    return [doc.to_dict() for doc in docs]


def prepare_test_push(customer_id: str):
    notifications_result = get_customer_notifications(customer_id)
    latest_notification = notifications_result["latest_notification"]

    devices = get_customer_devices(customer_id)

    if not latest_notification:
        return {
            "success": False,
            "message": "No notification found for this customer.",
            "customer_id": customer_id,
        }

    push_payload = {
        "notification": {
            "title": latest_notification.get("title"),
            "body": latest_notification.get("body"),
        },
        "data": {
            "type": latest_notification.get("type"),
            "action": latest_notification.get("action"),
            "customer_id": latest_notification.get("customer_id"),
            "application_id": latest_notification.get("application_id"),
            "card_id": latest_notification.get("card_id"),
            "notification_id": latest_notification.get("notification_id"),
            "deep_link": latest_notification.get("deep_link"),
        },
    }

    return {
        "success": True,
        "mode": "simulation",
        "customer_id": customer_id,
        "device_count": len(devices),
        "devices": devices,
        "latest_notification": latest_notification,
        "push_payload": push_payload,
        "message": "Push payload prepared. No real notification was sent.",
    }