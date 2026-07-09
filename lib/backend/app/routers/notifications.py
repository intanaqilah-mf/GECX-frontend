from fastapi import APIRouter

from app.schemas.notification import CardApprovalNotificationRequest
from app.services.notification_service import create_card_approval_notification

router = APIRouter(
    prefix="/notifications",
    tags=["Notifications"]
)


@router.post("/card-approval")
def card_approval_notification(payload: CardApprovalNotificationRequest):
    return create_card_approval_notification(payload)