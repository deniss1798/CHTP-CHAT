from fastapi import APIRouter

from app.api.routers.messages import media_routes, query_routes, text_routes

router = APIRouter(prefix="/messages", tags=["Messages"])
router.include_router(text_routes.router)
router.include_router(media_routes.router)
router.include_router(query_routes.router)
