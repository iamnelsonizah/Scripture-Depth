import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.main import app
from app.core.database import get_db
from app.models.base import Base
from ingestion.seed_sample_data import seed_database


@pytest_asyncio.fixture(scope="module")
async def test_client():
    # Setup tables and seed sample data
    await seed_database()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.mark.asyncio
async def test_health_check(test_client):
    response = await test_client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


@pytest.mark.asyncio
async def test_list_translations(test_client):
    response = await test_client.get("/api/v1/translations")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert any(t["id"] == "web" for t in data)


@pytest.mark.asyncio
async def test_get_chapter_reader(test_client):
    response = await test_client.get("/api/v1/reader/web/JHN/3")
    assert response.status_code == 200
    data = response.json()
    assert data["book"] == "John"
    assert data["chapter"] == 3
    assert len(data["verses"]) >= 4

    # Check verse 16 has original words attached
    v16 = next((v for v in data["verses"] if v["verse"] == 16), None)
    assert v16 is not None
    assert "loved" in v16["text"]
    assert len(v16["original_words"]) > 0

    # Verify Greek word data
    god_word = next((w for w in v16["original_words"] if w["strongs_number"] == "G2316"), None)
    assert god_word is not None
    assert god_word["transliteration"] == "theós"


@pytest.mark.asyncio
async def test_root(test_client):
    response = await test_client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert data["docs_url"] == "/docs"


@pytest.mark.asyncio
async def test_lexicon_lookup(test_client):
    response = await test_client.get("/api/v1/lexicon/G25")
    assert response.status_code == 200
    data = response.json()
    assert data["entry"]["strongs_number"] == "G25"
    assert data["entry"]["lemma"] in ["ἀγαπάω", "ἀγαπάω"]
    assert "love" in data["entry"]["short_definition"].lower()


@pytest.mark.asyncio
async def test_search_verses(test_client):
    response = await test_client.get("/api/v1/search?q=grace")
    assert response.status_code == 200
    data = response.json()
    assert data["total_results"] >= 1
    assert any("grace" in r["text"].lower() for r in data["results"])
    assert any("<mark>" in r["highlighted_text"] for r in data["results"])


@pytest.mark.asyncio
async def test_notes_auth_protection(test_client):
    # Unauthenticated request should return 401
    unauth_resp = await test_client.get("/api/v1/notes")
    assert unauth_resp.status_code == 401

    from jose import jwt
    from app.core.config import settings

    # Sign a valid JWT using the configured Supabase JWT secret
    token = jwt.encode(
        {"sub": "test-user-uuid-1234", "email": "test@example.com", "role": "authenticated"},
        settings.SUPABASE_JWT_SECRET,
        algorithm=settings.SUPABASE_JWT_ALGORITHM,
    )

    auth_resp = await test_client.get(
        "/api/v1/notes",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert auth_resp.status_code == 200
    assert isinstance(auth_resp.json(), list)


@pytest.mark.asyncio
async def test_audio_chapter_metadata(test_client):
    response = await test_client.get("/api/v1/audio/chapter/kjv/JHN/3")
    assert response.status_code == 200
    data = response.json()
    assert data["book_name"] == "John"
    assert data["book_code"] == "JHN"
    assert data["chapter"] == 3
    assert "stream_url" in data
    assert "verses" in data
