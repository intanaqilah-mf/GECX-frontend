from datetime import datetime, timezone


def get_card_activity(card_id: str):
    now = datetime.now(timezone.utc)

    activity = [
        {
            "activity_id": "ACT_001",
            "card_id": card_id,
            "merchant": "Apple Store Soho",
            "category": "Technology",
            "amount": -1299.00,
            "currency": "USD",
            "status": "posted",
            "description": "Apple Store Soho",
            "transaction_type": "purchase",
            "created_at": now,
            "display_date": "Today, 2:45 PM",
        },
        {
            "activity_id": "ACT_002",
            "card_id": card_id,
            "merchant": "The Grill House",
            "category": "Dining",
            "amount": -84.50,
            "currency": "USD",
            "status": "posted",
            "description": "The Grill House",
            "transaction_type": "purchase",
            "created_at": now,
            "display_date": "Yesterday, 8:12 PM",
        },
        {
            "activity_id": "ACT_003",
            "card_id": card_id,
            "merchant": "Uber Trip",
            "category": "Transportation",
            "amount": -18.22,
            "currency": "USD",
            "status": "posted",
            "description": "Uber Trip",
            "transaction_type": "purchase",
            "created_at": now,
            "display_date": "Yesterday, 6:00 PM",
        },
    ]

    return {
        "card_id": card_id,
        "latest_activity": activity[0],
        "activity": activity,
        "count": len(activity),
    }