# ScriptureDepth

An in-depth original-language Scripture study mobile application built with **Flutter**, a **FastAPI** backend, and **Supabase (PostgreSQL)** database storage.

---

## System Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Mobile App                   │
│  - Supabase Auth (OAuth / Email Magic Links)           │
│  - Scripture Study UI (Reader, Interlinear, Lexicon)   │
│  - 5 Core Tabs: Home, Read, Search, Maps, Profile      │
└───────────────────────────┬────────────────────────────┘
                            │
               Bearer Token │ (Supabase JWT)
                            ▼
┌────────────────────────────────────────────────────────┐
│                    FastAPI Backend                     │
│  - Supabase JWT Verification Middleware                │
│  - Aggregated Study Endpoints (Reader + Words + Lex)   │
│  - Full-Text Search & Thematic Cross-References        │
│  - User Data API (Notes, Bookmarks, Reading Plans)     │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ asyncpg / SQLAlchemy
                            ▼
┌────────────────────────────────────────────────────────┐
│               Supabase Managed Postgres                │
│  - auth.users (Managed by Supabase Auth)               │
│  - public schema (Verses, Lexicon, Morphology, Refs)   │
│  - User data schema (Notes, Bookmarks, Memorization)   │
└───────────────────────────┘
```

---

## Project Structure

```text
bible/
├── backend/
│   ├── app/
│   │   ├── api/v1/          # Endpoints (Reader, Lexicon, CrossRefs, Search, User)
│   │   ├── core/            # Database engine, Supabase settings, JWT security
│   │   ├── models/          # SQLAlchemy async models (verses, words, lexicon, user notes)
│   │   ├── schemas/         # Pydantic request/response schemas
│   │   └── main.py          # FastAPI application entrypoint
│   ├── tests/               # Pytest async suite
│   ├── requirements.txt
│   └── .env.example
├── ingestion/
│   └── seed_sample_data.py  # Database bootstrap & sample verse/Greek token seeder
└── mobile/
    ├── lib/
    │   ├── core/
    │   │   ├── theme/       # Warm Paper, Teal, Gold palette & Dark mode
    │   │   ├── network/     # API client with Bearer auth token header
    │   │   └── models/      # Scripture, Lexicon, and Search Dart models
    │   ├── features/
    │   │   ├── home/        # Reading plan progress, memory review, word of the day
    │   │   ├── reader/      # Scripture reader, interlinear switch, word study sheet
    │   │   ├── search/      # Keyword search with mark highlighting & theme pills
    │   │   ├── maps/        # Paul's 2nd journey visual route & interactive stops
    │   │   ├── profile/     # Growth streaks, memory count, dark mode toggle
    │   │   └── navigation/  # Bottom navigation scaffold
    │   └── main.dart        # Flutter entrypoint
    ├── test/                # Flutter widget tests
    └── pubspec.yaml
```

---

## Getting Started

### 1. Backend Setup (FastAPI)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

To configure with your live Supabase project:
1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Set `DATABASE_URL` to your Supabase connection string (transaction pooler port 6543):
   ```env
   DATABASE_URL=postgresql+asyncpg://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres
   SUPABASE_URL=https://[project-ref].supabase.co
   SUPABASE_JWT_SECRET=your-supabase-jwt-secret
   ```

*Note: For local offline development, SQLite (`sqlite+aiosqlite:///./scripturedepth.db`) is used automatically if no Supabase URL is specified.*

### 2. Seed Initial Scripture & Lexicon Data

```bash
python ingestion/seed_sample_data.py
```

### 3. Run Backend Server & Tests

Start the FastAPI development server:
```bash
uvicorn app.main:app --reload --port 8000
```
Interactive API docs available at: [http://localhost:8000/docs](http://localhost:8000/docs).

Run tests:
```bash
PYTHONPATH=.:backend pytest backend/tests/test_api.py -v
```

---

### 4. Mobile App (Flutter)

```bash
cd mobile
flutter pub get
flutter test
```

To run the mobile app on an emulator, device, or web:
```bash
flutter run
```
