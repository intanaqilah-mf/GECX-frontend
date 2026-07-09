from datetime import datetime, timezone


def get_customer_payments(customer_id: str):
    now = datetime.now(timezone.utc)

    quick_send_contacts = [
        {
            "contact_id": "CONTACT_001",
            "name": "Sarah J.",
            "avatar_url": None,
            "last_sent_amount": 120.00,
            "currency": "USD",
        },
        {
            "contact_id": "CONTACT_002",
            "name": "Michael K.",
            "avatar_url": None,
            "last_sent_amount": 75.50,
            "currency": "USD",
        },
        {
            "contact_id": "CONTACT_003",
            "name": "Elena R.",
            "avatar_url": None,
            "last_sent_amount": 200.00,
            "currency": "USD",
        },
    ]

    move_money_actions = [
        {
            "type": "between_accounts",
            "title": "Between Accounts",
            "subtitle": "Transfer funds instantly within ACN Bank.",
            "enabled": True,
        },
        {
            "type": "send_to_someone",
            "title": "Send to Someone",
            "subtitle": "Move money to any bank or external contact.",
            "enabled": True,
        },
        {
            "type": "pay_a_bill",
            "title": "Pay a Bill",
            "subtitle": "Settle utility, credit card, or service bills.",
            "enabled": True,
        },
    ]

    scheduled_payments = [
        {
            "payment_id": "PAY_001",
            "name": "Metropolis Utilities",
            "amount": -142.50,
            "currency": "USD",
            "due_date": "2026-07-24",
            "status": "scheduled",
            "payment_type": "auto_pay",
        },
        {
            "payment_id": "PAY_002",
            "name": "Riverside Rent",
            "amount": -2100.00,
            "currency": "USD",
            "due_date": "2026-08-03",
            "status": "scheduled",
            "payment_type": "one_time",
        },
        {
            "payment_id": "PAY_003",
            "name": "Luna Auto Finance",
            "amount": -485.00,
            "currency": "USD",
            "due_date": "2026-08-15",
            "status": "scheduled",
            "payment_type": "auto_pay",
        },
    ]

    return {
        "customer_id": customer_id,
        "quick_send_contacts": quick_send_contacts,
        "move_money_actions": move_money_actions,
        "scheduled_payments": scheduled_payments,
        "summary": {
            "quick_send_count": len(quick_send_contacts),
            "scheduled_payment_count": len(scheduled_payments),
            "next_payment": scheduled_payments[0],
        },
        "generated_at": now,
    }