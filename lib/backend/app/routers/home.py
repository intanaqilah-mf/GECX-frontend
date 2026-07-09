from fastapi import APIRouter

from app.services.home_service import get_customer_home

router = APIRouter(
    prefix="/customers",
    tags=["Home"]
)


@router.get("/{customer_id}/home")
def customer_home(customer_id: str):
    return get_customer_home(customer_id)