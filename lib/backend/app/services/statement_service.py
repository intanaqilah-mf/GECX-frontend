from datetime import datetime, timezone


def get_card_statements(card_id: str):
    now = datetime.now(timezone.utc)

    statements = [
        {
            "statement_id": "STMT_202607",
            "card_id": card_id,
            "period": "July 2026",
            "statement_date": "2026-07-31",
            "due_date": "2026-08-21",
            "current_balance": 1452.80,
            "minimum_payment": 75.00,
            "currency": "USD",
            "status": "open",
            "pdf_url": None,
        },
        {
            "statement_id": "STMT_202606",
            "card_id": card_id,
            "period": "June 2026",
            "statement_date": "2026-06-30",
            "due_date": "2026-07-21",
            "current_balance": 982.44,
            "minimum_payment": 49.12,
            "currency": "USD",
            "status": "paid",
            "pdf_url": None,
        },
        {
            "statement_id": "STMT_202605",
            "card_id": card_id,
            "period": "May 2026",
            "statement_date": "2026-05-31",
            "due_date": "2026-06-21",
            "current_balance": 615.32,
            "minimum_payment": 30.76,
            "currency": "USD",
            "status": "paid",
            "pdf_url": None,
        },
    ]

    return {
        "card_id": card_id,
        "latest_statement": statements[0],
        "statements": statements,
        "count": len(statements),
        "generated_at": now,
    }