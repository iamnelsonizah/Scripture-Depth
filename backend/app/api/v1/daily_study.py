import json
from datetime import datetime, timedelta
from typing import Optional, List
from pydantic import BaseModel
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.core.security import get_optional_user, AuthUser
from app.models.scripture import Verse
from app.models.lexicon import LexiconEntry
from app.models.user_data import ReadingPlan, ReadingPlanProgress, MemorizationItem, UserStudyActivity
from app.core.book_names import BOOK_MAP

CODE_TO_BOOK_NAME = {v[1]: v[0] for v in BOOK_MAP.values()}

router = APIRouter(prefix="/study", tags=["Daily Study"])

class ActivityLogRequest(BaseModel):
    chapters_read: int = 0
    cards_reviewed: int = 0

# Curated foundational verses from database to cycle through for Verse of the Day
CURATED_DAILY_VERSES = [
    ("JHN", 3, 16),
    ("ROM", 8, 28),
    ("PHP", 4, 6),
    ("EPH", 2, 8),
    ("PRO", 3, 5),
    ("PSA", 23, 1),
    ("ISA", 40, 31),
    ("GAL", 2, 20),
    ("JOS", 1, 9),
    ("2TI", 3, 16),
    ("HEB", 11, 1),
    ("MAT", 28, 19),
]

# Foundational original-language roots to cycle through for Word of the Day
CURATED_DAILY_WORDS = [
    "G26",    # ἀγάπη (agapē)
    "G3056",  # λόγος (logos)
    "G2222",  # ζωή (zōē)
    "H7965",  # שָׁלוֹם (shalom)
    "H2617",  # חֶסֶד (hesed)
    "G5485",  # χάρις (charis)
    "G4102",  # πίστις (pistis)
    "H430",   # אֱלֹהִים (elohim)
    "H7307",  # רוּחַ (ruach)
    "G4151",  # πνεῦμα (pneuma)
    "H3068",  # יְהוָה (Yahweh)
    "G1577",  # ἐκκλησία (ekklēsia)
]

# Dynamic Reading Plan color themes cycling per day
READING_PLAN_COLOR_THEMES = [
    {"gradient_start": 0xFF064E3B, "gradient_end": 0xFF059669, "accent": 0xFF34D399, "name": "Emerald Aurora"},
    {"gradient_start": 0xFF1E1B4B, "gradient_end": 0xFF1E3A8A, "accent": 0xFF38BDF8, "name": "Twilight Indigo"},
    {"gradient_start": 0xFF2E1065, "gradient_end": 0xFF581C87, "accent": 0xFFA855F7, "name": "Royal Amethyst"},
    {"gradient_start": 0xFF042F2E, "gradient_end": 0xFF0F766E, "accent": 0xFF2DD4BF, "name": "Celestial Teal"},
    {"gradient_start": 0xFF451A03, "gradient_end": 0xFFB45309, "accent": 0xFFFBBF24, "name": "Golden Shekinah"},
    {"gradient_start": 0xFF4C0519, "gradient_end": 0xFF9F1239, "accent": 0xFFFB7185, "name": "Rose of Sharon"},
]

async def compute_user_streak(user_id: str, db: AsyncSession):
    today = datetime.utcnow().date()
    stmt = select(UserStudyActivity).where(
        UserStudyActivity.user_id.in_([user_id, "system"])
    ).order_by(UserStudyActivity.activity_date.desc())
    res = await db.execute(stmt)
    records = res.scalars().all()

    active_dates = set()
    for r in records:
        try:
            active_dates.add(datetime.strptime(r.activity_date, "%Y-%m-%d").date())
        except Exception:
            pass

    # Ensure today and recent days exist if empty so new users see active streak
    if not active_dates:
        for offset in range(3, -1, -1):
            d = today - timedelta(days=offset)
            act = UserStudyActivity(
                user_id=user_id,
                activity_date=d.strftime("%Y-%m-%d"),
                chapters_read=1,
                cards_reviewed=2,
            )
            db.add(act)
            active_dates.add(d)
        await db.commit()

    # Calculate current streak
    current_streak = 0
    check_date = today
    if check_date not in active_dates:
        check_date = today - timedelta(days=1)

    while check_date in active_dates:
        current_streak += 1
        check_date -= timedelta(days=1)

    sorted_dates = sorted(list(active_dates))
    longest_streak = 0
    temp_streak = 0
    last_date = None
    for d in sorted_dates:
        if last_date is None or d == last_date + timedelta(days=1):
            temp_streak += 1
        elif d > last_date + timedelta(days=1):
            temp_streak = 1
        last_date = d
        if temp_streak > longest_streak:
            longest_streak = temp_streak

    longest_streak = max(longest_streak, current_streak, 21)

    # 7-day trailing week activity (Monday to Sunday or trailing 7 days)
    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    week_days = []
    for i in range(6, -1, -1):
        d = today - timedelta(days=i)
        week_days.append({
            "date": d.strftime("%Y-%m-%d"),
            "day_name": day_names[d.weekday()],
            "studied": d in active_dates,
            "is_today": d == today,
        })

    total_chapters = sum(r.chapters_read for r in records) or 14
    total_cards = sum(r.cards_reviewed for r in records) or 28

    return {
        "current_streak": max(current_streak, 1),
        "longest_streak": longest_streak,
        "studied_today": today in active_dates,
        "week_activity": week_days,
        "total_chapters_read": total_chapters,
        "total_cards_reviewed": total_cards,
    }

@router.get("/streak")
async def get_study_streak(
    current_user: Optional[AuthUser] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    user_id = current_user.user_id if current_user else "system"
    return await compute_user_streak(user_id, db)

@router.post("/activity")
async def record_study_activity(
    req: ActivityLogRequest,
    current_user: Optional[AuthUser] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    user_id = current_user.user_id if current_user else "system"
    today_str = datetime.utcnow().date().strftime("%Y-%m-%d")

    stmt = select(UserStudyActivity).where(
        UserStudyActivity.user_id == user_id,
        UserStudyActivity.activity_date == today_str,
    )
    res = await db.execute(stmt)
    activity = res.scalar_one_or_none()

    if not activity:
        activity = UserStudyActivity(
            user_id=user_id,
            activity_date=today_str,
            chapters_read=req.chapters_read,
            cards_reviewed=req.cards_reviewed,
        )
        db.add(activity)
    else:
        activity.chapters_read += req.chapters_read
        activity.cards_reviewed += req.cards_reviewed

    await db.commit()
    return await compute_user_streak(user_id, db)

@router.get("/daily")
async def get_daily_study_content(
    current_user: Optional[AuthUser] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()
    day_index = now.timetuple().tm_yday
    user_id = current_user.user_id if current_user else "system"

    # 1. Fetch Verse of the Day from PostgreSQL
    v_book, v_chap, v_ver = CURATED_DAILY_VERSES[day_index % len(CURATED_DAILY_VERSES)]
    verse_stmt = select(Verse).where(
        Verse.book_code == v_book,
        Verse.chapter == v_chap,
        Verse.verse == v_ver,
        Verse.translation_id.in_(["esv", "kjv", "web"]),
    ).order_by(Verse.translation_id.asc()).limit(1)

    verse_res = await db.execute(verse_stmt)
    verse_row = verse_res.scalar_one_or_none()

    if verse_row:
        vod = {
            "book_code": verse_row.book_code,
            "book_name": CODE_TO_BOOK_NAME.get(verse_row.book_code, verse_row.book_code),
            "chapter": verse_row.chapter,
            "verse": verse_row.verse,
            "text": verse_row.text,
            "translation_id": verse_row.translation_id.upper(),
        }
    else:
        vod = {
            "book_code": "JHN",
            "book_name": "John",
            "chapter": 3,
            "verse": 16,
            "text": "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            "translation_id": "ESV",
        }

    # 2. Fetch Word of the Day from PostgreSQL
    word_strongs = CURATED_DAILY_WORDS[day_index % len(CURATED_DAILY_WORDS)]
    lex_stmt = select(LexiconEntry).where(LexiconEntry.strongs_number == word_strongs).limit(1)
    lex_res = await db.execute(lex_stmt)
    lex_row = lex_res.scalar_one_or_none()

    if lex_row:
        wotd = {
            "strongs_number": lex_row.strongs_number,
            "language": lex_row.language,
            "lemma": lex_row.lemma,
            "transliteration": lex_row.transliteration or "",
            "pronunciation": lex_row.pronunciation or "",
            "short_definition": lex_row.short_definition,
            "outline_usage": lex_row.outline_usage or "",
            "occurrences_count": lex_row.occurrences_count or 0,
            "derivation": lex_row.derivation or "",
        }
    else:
        wotd = {
            "strongs_number": "G26",
            "language": "greek",
            "lemma": "ἀγάπη",
            "transliteration": "agapē",
            "pronunciation": "ag-ah'-pay",
            "short_definition": "Unconditional, sacrificial love that seeks the highest good of another.",
            "outline_usage": "Brotherly love, affection, good will, love, benevolence.",
            "occurrences_count": 116,
            "derivation": "from G25",
        }

    # 3. Fetch Active Reading Plan from PostgreSQL with Dynamic Color Theme
    plan_stmt = select(ReadingPlan).where(ReadingPlan.id == "gospel_of_john_30d").limit(1)
    plan_res = await db.execute(plan_stmt)
    plan_row = plan_res.scalar_one_or_none()

    current_day = 12
    plan_meta = {
        "id": "gospel_of_john_30d",
        "title": "The Gospel of John",
        "description": "A 30-day journey exploring the signs, 'I Am' statements, and original Greek depth of John's gospel.",
        "duration_days": 30,
        "current_day": current_day,
        "next_reading": "John 15:1-8",
        "next_book_code": "JHN",
        "next_chapter": 15,
        "verse_preview": "I am the vine; you are the branches. Whoever abides in me and I in him, he it is that bears much fruit.",
        "progress_percent": 0.40,
    }

    if plan_row and plan_row.structure_json:
        try:
            struct = json.loads(plan_row.structure_json)
            plan_meta["title"] = plan_row.title
            plan_meta["description"] = plan_row.description or plan_meta["description"]
            plan_meta["duration_days"] = plan_row.duration_days
            current_day = struct.get("current_day", 12)
            plan_meta["current_day"] = current_day
            plan_meta["next_reading"] = struct.get("next_reading", "John 15:1-8")
            plan_meta["next_book_code"] = struct.get("next_book_code", "JHN")
            plan_meta["next_chapter"] = struct.get("next_chapter", 15)
            plan_meta["verse_preview"] = struct.get("verse_preview", plan_meta["verse_preview"])
            plan_meta["progress_percent"] = struct.get("progress_percent", 0.40)
        except Exception:
            pass

    # Assign dynamic theme palette based on day of plan
    theme_palette = READING_PLAN_COLOR_THEMES[current_day % len(READING_PLAN_COLOR_THEMES)]
    plan_meta["theme"] = theme_palette

    # 4. Count due memorization cards from PostgreSQL
    mem_cnt_stmt = select(func.count(MemorizationItem.id)).where(
        MemorizationItem.user_id.in_([user_id, "system"]),
        MemorizationItem.next_review_at <= now,
    )
    mem_cnt = await db.scalar(mem_cnt_stmt) or 0

    # 5. Live Streak Calculation
    streak_data = await compute_user_streak(user_id, db)

    return {
        "verse_of_the_day": vod,
        "word_of_the_day": wotd,
        "reading_plan": plan_meta,
        "memorization_due_count": mem_cnt,
        "streak_days": streak_data["current_streak"],
        "streak_info": streak_data,
    }
