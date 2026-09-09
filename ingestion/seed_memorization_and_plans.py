import asyncio
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

from datetime import datetime, timedelta
from sqlalchemy import select, delete
from app.core.database import AsyncSessionLocal
from app.models.user_data import ReadingPlan, ReadingPlanProgress, MemorizationItem

FOUNDATIONAL_MEMORIZATION_VERSES = [
    {
        "book_code": "JHN",
        "chapter": 3,
        "verse": 16,
        "verse_text": "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
        "interval_days": 1,
        "repetitions": 2,
    },
    {
        "book_code": "EPH",
        "chapter": 2,
        "verse": 8,
        "verse_text": "For by grace are ye saved through faith; and that not of yourselves: it is the gift of God: Not of works, lest any man should boast.",
        "interval_days": 2,
        "repetitions": 1,
    },
    {
        "book_code": "ROM",
        "chapter": 5,
        "verse": 8,
        "verse_text": "But God commendeth his love toward us, in that, while we were yet sinners, Christ died for us.",
        "interval_days": 3,
        "repetitions": 3,
    },
    {
        "book_code": "PHP",
        "chapter": 4,
        "verse": 6,
        "verse_text": "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.",
        "interval_days": 1,
        "repetitions": 0,
    },
    {
        "book_code": "PHP",
        "chapter": 4,
        "verse": 7,
        "verse_text": "And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.",
        "interval_days": 2,
        "repetitions": 1,
    },
    {
        "book_code": "PSA",
        "chapter": 23,
        "verse": 1,
        "verse_text": "The LORD is my shepherd; I shall not want.",
        "interval_days": 5,
        "repetitions": 4,
    },
    {
        "book_code": "PRO",
        "chapter": 3,
        "verse": 5,
        "verse_text": "Trust in the LORD with all thine heart; and lean not unto thine own understanding.",
        "interval_days": 4,
        "repetitions": 3,
    },
    {
        "book_code": "PRO",
        "chapter": 3,
        "verse": 6,
        "verse_text": "In all thy ways acknowledge him, and he shall direct thy paths.",
        "interval_days": 4,
        "repetitions": 3,
    },
    {
        "book_code": "ISA",
        "chapter": 40,
        "verse": 31,
        "verse_text": "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
        "interval_days": 2,
        "repetitions": 1,
    },
    {
        "book_code": "ROM",
        "chapter": 8,
        "verse": 28,
        "verse_text": "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.",
        "interval_days": 3,
        "repetitions": 2,
    },
    {
        "book_code": "GAL",
        "chapter": 2,
        "verse": 20,
        "verse_text": "I am crucified with Christ: nevertheless I live; yet not I, but Christ liveth in me: and the life which I now live in the flesh I live by the faith of the Son of God, who loved me, and gave himself for me.",
        "interval_days": 1,
        "repetitions": 0,
    },
    {
        "book_code": "JOS",
        "chapter": 1,
        "verse": 9,
        "verse_text": "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.",
        "interval_days": 3,
        "repetitions": 2,
    },
    {
        "book_code": "2TI",
        "chapter": 3,
        "verse": 16,
        "verse_text": "All scripture is given by inspiration of God, and is profitable for doctrine, for reproof, for correction, for instruction in righteousness.",
        "interval_days": 2,
        "repetitions": 1,
    },
    {
        "book_code": "HEB",
        "chapter": 11,
        "verse": 1,
        "verse_text": "Now faith is the substance of things hoped for, the evidence of things not seen.",
        "interval_days": 4,
        "repetitions": 3,
    },
    {
        "book_code": "MAT",
        "chapter": 28,
        "verse": 19,
        "verse_text": "Go ye therefore, and teach all nations, baptizing them in the name of the Father, and of the Son, and of the Holy Ghost.",
        "interval_days": 1,
        "repetitions": 0,
    },
    {
        "book_code": "MAT",
        "chapter": 28,
        "verse": 20,
        "verse_text": "Teaching them to observe all things whatsoever I have commanded you: and, lo, I am with you alway, even unto the end of the world. Amen.",
        "interval_days": 2,
        "repetitions": 1,
    },
]

READING_PLANS = [
    {
        "id": "gospel_of_john_30d",
        "title": "The Gospel of John",
        "description": "A 30-day journey exploring the signs, 'I Am' statements, and original Greek depth of John's gospel.",
        "duration_days": 30,
        "structure_json": '{"current_day": 12, "next_reading": "John 15:1-8", "verse_preview": "I am the vine; you are the branches. Whoever abides in me and I in him, he it is that bears much fruit.", "next_book_code": "JHN", "next_chapter": 15, "progress_percent": 0.40}',
    },
    {
        "id": "romans_grace_28d",
        "title": "Romans: Foundations of Grace",
        "description": "28 days through Paul's masterwork on justification, righteousness, the Holy Spirit, and Christian living.",
        "duration_days": 28,
        "structure_json": '{"current_day": 8, "next_reading": "Romans 8:1-17", "verse_preview": "There is therefore now no condemnation for those who are in Christ Jesus.", "next_book_code": "ROM", "next_chapter": 8, "progress_percent": 0.28}',
    },
    {
        "id": "wisdom_proverbs_31d",
        "title": "Wisdom for Life: Proverbs",
        "description": "31 chapters of practical wisdom, divine guidance, and discernment for daily leadership and speech.",
        "duration_days": 31,
        "structure_json": '{"current_day": 3, "next_reading": "Proverbs 3:1-20", "verse_preview": "Trust in the LORD with all your heart, and do not lean on your own understanding.", "next_book_code": "PRO", "next_chapter": 3, "progress_percent": 0.10}',
    },
]

async def seed():
    print("Connecting to database...")
    async with AsyncSessionLocal() as session:
        # 1. Seed Reading Plans
        for plan_dict in READING_PLANS:
            plan = await session.get(ReadingPlan, plan_dict["id"])
            if not plan:
                plan = ReadingPlan(
                    id=plan_dict["id"],
                    title=plan_dict["title"],
                    description=plan_dict["description"],
                    duration_days=plan_dict["duration_days"],
                    structure_json=plan_dict["structure_json"],
                )
                session.add(plan)
            else:
                plan.title = plan_dict["title"]
                plan.description = plan_dict["description"]
                plan.duration_days = plan_dict["duration_days"]
                plan.structure_json = plan_dict["structure_json"]
        await session.commit()
        print("Reading plans seeded successfully.")

        # 2. Seed System & Dev Memorization Items
        await session.execute(delete(MemorizationItem).where(MemorizationItem.user_id.in_(["system", "default", "dev-user-1"])))
        await session.commit()

        now = datetime.utcnow()
        for v in FOUNDATIONAL_MEMORIZATION_VERSES:
            for uid in ["system", "dev-user-1"]:
                item = MemorizationItem(
                    user_id=uid,
                    book_code=v["book_code"],
                    chapter=v["chapter"],
                    verse=v["verse"],
                    verse_text=v["verse_text"],
                    interval_days=v["interval_days"],
                    repetitions=v["repetitions"],
                    ease_factor=2.5,
                    next_review_at=now - timedelta(hours=1),
                )
                session.add(item)
        await session.commit()
        print(f"Seeded {len(FOUNDATIONAL_MEMORIZATION_VERSES)} memorization verses for system and dev-user-1.")

if __name__ == "__main__":
    asyncio.run(seed())
