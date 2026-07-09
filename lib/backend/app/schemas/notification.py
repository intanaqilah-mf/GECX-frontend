from typing import Optional

from pydantic import BaseModel


class CardApprovalNotificationRequest(BaseModel):
    customer_id: str
    application_id: str
    card_id: str
    selected_product_name: str

    deep_link: Optional[str] = None

    channel: str = "gecx"
    source_agent: Optional[str] = None
    conversation_id: Optional[str] = None