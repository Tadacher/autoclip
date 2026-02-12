
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool
from typing import Generator
from backend.models.base import Base

DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "sqlite:///autoclip.db"
)

if DATABASE_URL == "sqlite:///autoclip.db":
    try:
        from .config import get_database_url
        DATABASE_URL = get_database_url()
    except ImportError:
        pass

if "sqlite" in DATABASE_URL:
    engine = create_engine(
        DATABASE_URL,
        connect_args={
            "check_same_thread": False,
            "timeout": 30
        },
        poolclass=StaticPool,
        pool_pre_ping=True,
        echo=False
    )
else:
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        pool_recycle=300,
        echo=False
    )

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

def get_db() -> Generator[Session, None, None]:

    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_tables():
    Base.metadata.create_all(bind=engine)

def drop_tables():
    Base.metadata.drop_all(bind=engine)

def reset_database():
    drop_tables()
    create_tables()

from sqlalchemy import text

def test_connection() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1")).fetchone()
        return True
    except Exception as e:
        print(f"Ошибка: {e}")
        return False

def init_database():
    print("Инициализация датабазы...")
    
    if not test_connection():
        print("cnn test failed")
        return False

    try:
        create_tables()
        print("✅ Таблицы базы данных успешно созданы")
        return True
    except Exception as e:
        print(f"❌ Не удалось создать таблицы базы данных: {e}")
        return False

if __name__ == "__main__":
    init_database()