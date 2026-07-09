from fastapi import APIRouter

from app.services.payment_service import get_customer_payments

router = APIRouter(
    prefix="/customers",
    tags=["Payments"]
)


@router.get("/{customer_id}/payments")
def customer_payments(customer_id: str):
    return get_customer_payments(customer_id)