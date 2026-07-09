from app.services.firestore import db
from app.services.application_service import (
    get_customer_applications,
    get_customer_cards,
    get_customer_notifications,
)


def get_customer_profile(customer_id: str):
    # Try getting by document ID first
    customer_ref = db.collection("customers").document(customer_id)
    customer_doc = customer_ref.get()

    if not customer_doc.exists:
        # Fallback: query by 'customer_id' field if document ID match fails
        docs = (
            db.collection("customers")
            .where("customer_id", "==", customer_id)
            .limit(1)
            .stream()
        )
        results = list(docs)
        if results:
            customer_doc = results[0]
        else:
            return {
                "customer_id": customer_id,
                "display_name": "Customer",
                "email": None,
                "account_number": None,
                "found": False,
            }

    data = customer_doc.to_dict()

    display_name = (
        data.get("display_name")
        or data.get("legal_name")
        or data.get("full_name")
        or data.get("name")
        or data.get("first_name")
        or "Customer"
    )

    return {
        "customer_id": data.get("customer_id", customer_id),
        "display_name": display_name,
        "email": data.get("email"),
        "account_number": data.get("account_number"),
        "has_card": data.get("has_card", False),
        "card_info": data.get("card_info"),
        "found": True,
    }


def get_customer_home(customer_id: str):
    customer = get_customer_profile(customer_id)

    if not customer.get("found"):
        return {
            "customer": customer,
            "latest_application": None,
            "latest_card": None,
            "latest_notification": None,
            "pending_actions": [],
            "summary": {
                "total_applications": 0,
                "total_cards": 0,
                "total_notifications": 0,
                "has_card_ready_for_activation": False,
            },
        }

    # Use the internal ID for queries
    internal_id = customer.get("customer_id") or customer_id

    # Optimization: Use the card_info map if available in the customer document
    cached_card = customer.get("card_info")

    applications_result = get_customer_applications(internal_id)
    cards_result = get_customer_cards(internal_id)
    notifications_result = get_customer_notifications(internal_id)

    latest_application = applications_result["latest_application"]
    # Preference: Specific card record > cached card info
    latest_card = cards_result["latest_card"] or cached_card
    latest_notification = notifications_result["latest_notification"]

    pending_actions = []

    if latest_card and latest_card.get("status") == "ready_for_activation":
        pending_actions.append(
            {
                "type": "activate_card",
                "label": "Activate Card",
                "card_id": latest_card.get("card_id"),
                "deep_link": latest_card.get("deep_link"),
            }
        )

    return {
        "customer": customer,
        "latest_application": latest_application,
        "latest_card": latest_card,
        "latest_notification": latest_notification,
        "pending_actions": pending_actions,
        "summary": {
            "total_applications": applications_result["count"],
            "total_cards": cards_result["count"],
            "total_notifications": notifications_result["count"],
            "has_card_ready_for_activation": bool(pending_actions),
        },
    }