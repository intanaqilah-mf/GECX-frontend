from fastapi import APIRouter

from app.schemas.application import SubmitApplicationRequest
from app.services.application_service import (
    create_application,
    get_customer_applications,
    get_customer_cards,
    get_customer_notifications,
)

router = APIRouter(
    tags=["Credit Card Applications"]
)


@router.post("/applications")
def submit_application(payload: SubmitApplicationRequest):
    return create_application(payload)


@router.post("/credit-card/applications")
def submit_credit_card_application(payload: SubmitApplicationRequest):
    return create_application(payload)


@router.get("/customers/{customer_id}/applications")
def customer_applications(customer_id: str):
    return {
        "customer_id": customer_id,
        **get_customer_applications(customer_id),
    }


@router.get("/customers/{customer_id}/cards")
def customer_cards(customer_id: str):
    return {
        "customer_id": customer_id,
        **get_customer_cards(customer_id),
    }


@router.get("/customers/{customer_id}/notifications")
def customer_notifications(customer_id: str):
    return {
        "customer_id": customer_id,
        **get_customer_notifications(customer_id),
    }