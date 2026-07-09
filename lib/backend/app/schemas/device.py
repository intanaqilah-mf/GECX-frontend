from typing import Optional

from pydantic import BaseModel


class RegisterDeviceRequest(BaseModel):

    device_id: str

    fcm_token: str

    platform: str

    app_version: Optional[str] = None

    os_version: Optional[str] = None