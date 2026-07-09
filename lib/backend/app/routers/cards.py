from fastapi import APIRouter

from app.services.activity_service import get_card_activity
from app.services.card_service import activate_card, get_card
from app.services.statement_service import get_card_statements

router = APIRouter(
    prefix="/cards",
    tags=["Cards"]
)


@router.get("/{card_id}")
def card_details(card_id: str):
    return get_card(card_id)


@router.get("/{card_id}/activity")
def card_activity(card_id: str):
    return get_card_activity(card_id)


@router.post("/{card_id}/activate")
def activate(card_id: str):
    return activate_card(card_id)


@router.get("/{card_id}/statements")
def card_statements(card_id: str):
    return get_card_statements(card_id)