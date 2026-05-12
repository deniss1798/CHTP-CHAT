from fastapi import APIRouter

from app.api.routers.messages import (
    media_routes,
    pin_routes,
    poll_routes,
    query_routes,
    reaction_routes,
    text_routes,
)

router = APIRouter(prefix="/messages", tags=["Messages"])
router.include_router(text_routes.router)
router.include_router(reaction_routes.router)
router.include_router(media_routes.router)
router.include_router(query_routes.router)
router.include_router(pin_routes.router)
router.include_router(poll_routes.router)
