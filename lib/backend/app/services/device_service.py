from datetime import datetime, timezone

from app.services.firestore import db


def register_device(customer_id: str, payload):

    now = datetime.now(timezone.utc)

    document = {
        "device_id": payload.device_id,
        "customer_id": customer_id,
        "fcm_token": payload.fcm_token,
        "platform": payload.platform,
        "app_version": payload.app_version,
        "os_version": payload.os_version,
        "active": True,
        "created_at": now,
        "updated_at": now,
    }

    db.collection("customers") \
      .document(customer_id) \
      .collection("devices") \
      .document(payload.device_id) \
      .set(document)

    return {
        "success": True,
        "message": "Device registered successfully.",
        "device": document,
    }