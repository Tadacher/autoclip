"""
健康检查API路由
"""

from fastapi import APIRouter
from datetime import datetime
from typing import Dict, Any

router = APIRouter()


@router.get("/")
async def health_check() -> Dict[str, Any]:
    """Конечная точка проверки состояния."""
    return {
        "status": "хз",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }


@router.get("/video-categories")
async def get_video_categories() -> Dict[str, Any]:
    """Получить конфигурацию категорий видео."""
    return {
            "categories": [
            {
                "value": "knowledge",
                "name": "Научно-популярные знания",
                "description": "Контент о науке, технологиях, истории, культуре и других знаниях",
                "icon": "book",
                "color": "#1890ff"
            },
            {
                "value": "entertainment",
                "name": "Развлечения и отдых",
                "description": "Игры, музыка, кино, шоу и другой развлекательный контент",
                "icon": "play-circle",
                "color": "#52c41a"
            },
            {
                "value": "experience",
                "name": "Жизненный опыт",
                "description": "Практический контент: лайфхаки, кулинария, путешествия, рукоделие",
                "icon": "heart",
                "color": "#fa8c16"
            },
            {
                "value": "opinion",
                "name": "Мнения и комментарии",
                "description": "Комментарии к текущим событиям, обмен мнениями, социальные темы",
                "icon": "message",
                "color": "#722ed1"
            },
            {
                "value": "business",
                "name": "Бизнес и финансы",
                "description": "Бизнес-аналитика, финансовые новости, инвестиции и управление капиталом",
                "icon": "dollar",
                "color": "#13c2c2"
            },
            {
                "value": "speech",
                "name": "Выступления и интервью",
                "description": "Речи, интервью, диалоги и другой устный контент",
                "icon": "sound",
                "color": "#eb2f96"
            }
        ],
        "default_category": "knowledge"
    } 