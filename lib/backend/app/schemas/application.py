from typing import Optional

from pydantic import BaseModel, EmailStr


class SubmitApplicationRequest(BaseModel):
    customer_id: str
    customer_email: Optional[EmailStr] = None

    selected_product_id: str
    selected_product_name: str

    product_category: str = "Credit Card"

    channel: str = "gecx"

    source_agent: Optional[str] = None

    conversation_id: Optional[str] = None