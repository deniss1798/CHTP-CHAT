from fastapi import APIRouter

from app.api.routers.chats import (
    avatar_routes,
    management_routes,
    member_routes,
    query_routes,
    read_routes,
)

router = APIRouter(prefix="/chats", tags=["Chats"])
router.include_router(query_routes.router)
router.include_router(member_routes.router)
router.include_router(read_routes.router)
router.include_router(avatar_routes.router)
router.include_router(management_routes.router)
