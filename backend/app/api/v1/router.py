from fastapi import APIRouter
from app.api.v1.reader import router as reader_router
from app.api.v1.lexicon import router as lexicon_router
from app.api.v1.cross_refs import router as cross_refs_router
from app.api.v1.search import router as search_router
from app.api.v1.user import router as user_router
from app.api.v1.daily_study import router as daily_study_router
from app.api.v1.audio import router as audio_router

api_router = APIRouter()
api_router.include_router(reader_router)
api_router.include_router(lexicon_router)
api_router.include_router(cross_refs_router)
api_router.include_router(search_router)
api_router.include_router(user_router)
api_router.include_router(daily_study_router)
api_router.include_router(audio_router)
