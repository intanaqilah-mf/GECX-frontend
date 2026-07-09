from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers.applications import router as applications_router
from app.routers.notifications import router as notifications_router
from app.routers.cards import router as cards_router
from app.routers.home import router as home_router
from app.routers.devices import router as devices_router
from app.routers.payments import router as payments_router
from app.routers.push import router as push_router

app = FastAPI(
    title="ACN Bank Customer Platform",
    version="1.0.0",
    description="Shared backend for ACN Bank omnichannel experiences."
)

# Enable CORS for Flutter Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

app.include_router(applications_router)
app.include_router(notifications_router)
app.include_router(cards_router)
app.include_router(home_router)
app.include_router(devices_router)
app.include_router(payments_router)
app.include_router(push_router)

@app.get("/")
def root():
    return {
        "service": "ACN Bank Customer Platform",
        "status": "running"
    }
