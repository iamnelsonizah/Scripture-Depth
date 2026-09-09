# ScriptureDepth API

FastAPI backend service powering the ScriptureDepth Bible reading, scholarly study, lexicon concordance, and synchronized audio narration platform.

## Features
- **Scripture Reader**: Multi-translation reader with interlinear original Greek and Hebrew morphological tokens.
- **Lexicon & Concordance**: Strong's lexicon lookup, etymology, root derivations, and full cross-references.
- **Synchronized Audio Narration**: CDN-streamed human studio narration with millisecond-level verse boundary tracking and local disk caching.
- **Daily Study Hub**: Word of the Day, Verse of the Day, Reading Plans, and Spaced Repetition Memorization.
- **User State Sync**: Supabase JWT authentication, notes, highlights, bookmarks, and cross-device synchronization.

## Quickstart (Local Development)

```bash
# Navigate to backend
cd backend

# Create & activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run development server
fastapi dev
# Or with uvicorn:
# uvicorn app.main:app --port 8000 --reload
```

Interactive API documentation will be available at:
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- Health check: `http://127.0.0.1:8000/health`

## Deploying to FastAPI Cloud (fastapicloud.com)

1. Authenticate with FastAPI Cloud:
   ```bash
   cd backend
   fastapi login
   ```
2. Deploy the application:
   ```bash
   fastapi deploy
   ```
3. Set your production environment variables in the FastAPI Cloud console:
   - `ENVIRONMENT=production`
   - `DATABASE_URL=postgresql+asyncpg://postgres.[ref]:[password]@[host]:6543/postgres`
   - `SUPABASE_URL=https://your-project.supabase.co`
   - `SUPABASE_ANON_KEY=your-anon-key`
   - `SUPABASE_JWT_SECRET=your-supabase-jwt-secret`
   - `BACKEND_CORS_ORIGINS=*`
