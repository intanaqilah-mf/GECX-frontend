from fastapi import APIRouter

from app.schemas.device import RegisterDeviceRequest
from app.services.device_service import register_device

router = APIRouter(
    prefix="/customers",
    tags=["Devices"]
)


@router.post("/{customer_id}/devices")
def register(
    customer_id: str,
    payload: RegisterDeviceRequest,
):

    return register_device(customer_id, payload)