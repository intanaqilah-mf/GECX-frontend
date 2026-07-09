from fastapi import APIRouter

from app.services.push_service import prepare_test_push

router = APIRouter(
    prefix="/customers",
    tags=["Push Notifications"]
)


@router.post("/{customer_id}/notifications/test-push")
def test_push(customer_id: str):
    return prepare_test_push(customer_id)