import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, MetaData
from sqlalchemy.orm import declarative_base
from sqlalchemy.dialects.postgresql import UUID

metadata = MetaData()

# 创建基础类
Base = declarative_base(metadata=metadata)

def get_utc_now():
    return datetime.now(timezone.utc)

class TimestampMixin:

    created_at = Column(
        DateTime(timezone=True), 
        default=get_utc_now, 
        nullable=False,
        comment="创建时间"
    )
    updated_at = Column(
        DateTime(timezone=True), 
        default=get_utc_now, 
        onupdate=get_utc_now, 
        nullable=False,
        comment="更新时间"
    )

def generate_uuid():
    return str(uuid.uuid4())

class BaseModel(Base, TimestampMixin):

    __abstract__ = True
    
    id = Column(
        String(36), 
        primary_key=True, 
        default=generate_uuid,
        index=True,
        comment="主键ID"
    )
    
    def __repr__(self):
        return f"<{self.__class__.__name__}(id={self.id})>"
    
    def to_dict(self):
        return {
            column.name: getattr(self, column.name)
            for column in self.__table__.columns
        }
    
    def update_from_dict(self, data: dict):
        for key, value in data.items():
            if hasattr(self, key) and key != 'id':
                setattr(self, key, value)
        return self 