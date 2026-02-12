"""
统一配置管理系统
整合所有配置源，提供统一的配置访问接口
"""

import json
import os
import logging
from pathlib import Path
from typing import Dict, Any, Optional, Union
from pydantic import BaseModel, Field, validator
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)


class DatabaseConfig(BaseModel):
    """Конфигурация базы данных"""
    url: str = Field(default="sqlite:///./data/autoclip.db", description="URL подключения к БД")
    echo: bool = Field(default=False, description="Выводить SQL-запросы")
    pool_size: int = Field(default=5, description="Размер пула соединений")
    max_overflow: int = Field(default=10, description="Максимальное количество дополнительных соединений")


class RedisConfig(BaseModel):
    """Конфигурация Redis"""
    url: str = Field(default="redis://localhost:6379/0", description="URL подключения к Redis")
    max_connections: int = Field(default=10, description="Максимальное количество соединений")
    socket_timeout: int = Field(default=5, description="Таймаут сокета")


class APIConfig(BaseModel):
    """Конфигурация API"""
    dashscope_api_key: str = Field(default="", description="API-ключ DashScope")
    model_name: str = Field(default="qwen-plus", description="Название модели")
    max_tokens: int = Field(default=4096, description="Максимальное количество токенов")
    timeout: int = Field(default=30, description="Таймаут API")
    max_retries: int = Field(default=3, description="Максимальное количество повторных попыток")

    @validator('max_tokens')
    def validate_max_tokens(cls, v):
        if v <= 0:
            raise ValueError('max_tokens должно быть больше 0')
        return v

    @validator('timeout')
    def validate_timeout(cls, v):
        if v <= 0:
            raise ValueError('timeout должно быть больше 0')
        return v


class ProcessingConfig(BaseModel):
    """Конфигурация обработки"""
    chunk_size: int = Field(default=5000, description="Размер чанка текста")
    min_score_threshold: float = Field(default=0.7, description="Минимальный порог оценки")
    max_clips_per_collection: int = Field(default=5, description="Максимальное количество клипов в подборке")
    max_retries: int = Field(default=3, description="Максимальное количество повторных попыток")
    timeout_seconds: int = Field(default=30, description="Таймаут обработки")

    # Параметры управления извлечением тем
    min_topic_duration_minutes: int = Field(default=2, description="Минимальная длительность темы (минуты)")
    max_topic_duration_minutes: int = Field(default=12, description="Максимальная длительность темы (минуты)")
    target_topic_duration_minutes: int = Field(default=5, description="Целевая длительность темы (минуты)")
    min_topics_per_chunk: int = Field(default=3, description="Минимальное количество тем в чанке")
    max_topics_per_chunk: int = Field(default=8, description="Максимальное количество тем в чанке")

    @validator('min_score_threshold')
    def validate_score_threshold(cls, v):
        if not 0 <= v <= 1:
            raise ValueError('Порог оценки должен быть от 0 до 1')
        return v

    @validator('chunk_size')
    def validate_chunk_size(cls, v):
        if v <= 0:
            raise ValueError('Размер чанка должен быть больше 0')
        return v


class SpeechRecognitionConfig(BaseModel):
    """Конфигурация распознавания речи"""
    method: str = Field(default="whisper_local", description="Метод распознавания")
    language: str = Field(default="auto", description="Язык распознавания")
    model: str = Field(default="base", description="Размер модели")
    timeout: int = Field(default=1000, description="Таймаут распознавания")


class BilibiliConfig(BaseModel):
    """Конфигурация Bilibili"""
    auto_upload: bool = Field(default=False, description="Автоматическая загрузка")
    default_tid: int = Field(default=21, description="ID раздела по умолчанию")
    max_concurrent_uploads: int = Field(default=3, description="Максимальное количество одновременных загрузок")
    upload_timeout_minutes: int = Field(default=30, description="Таймаут загрузки (минуты)")
    auto_generate_tags: bool = Field(default=True, description="Автоматически генерировать теги")
    tag_limit: int = Field(default=12, description="Лимит количества тегов")


class LoggingConfig(BaseModel):
    """Конфигурация логирования"""
    level: str = Field(default="INFO", description="Уровень логирования")
    format: str = Field(default="%(asctime)s - %(name)s - %(levelname)s - %(message)s", description="Формат лога")
    file: str = Field(default="backend.log", description="Файл лога")
    max_size: int = Field(default=10 * 1024 * 1024, description="Максимальный размер файла лога (байты)")
    backup_count: int = Field(default=5, description="Количество резервных копий")


class PathConfig(BaseModel):
    """Конфигурация путей"""
    project_root: Path = Field(default_factory=lambda: Path(__file__).parent.parent.parent)
    data_dir: Path = Field(default_factory=lambda: Path(__file__).parent.parent.parent / "data")
    uploads_dir: Path = Field(default_factory=lambda: Path(__file__).parent.parent.parent / "data" / "uploads")
    output_dir: Path = Field(default_factory=lambda: Path(__file__).parent.parent.parent / "data" / "output")
    temp_dir: Path = Field(default_factory=lambda: Path(__file__).parent.parent.parent / "data" / "temp")
    prompt_dir: Path = Field(default_factory=lambda: Path(__file__).parent.parent.parent / "prompt")

    def __init__(self, **data):
        super().__init__(**data)
        # Создаем все директории при инициализации
        for field_name, field_value in self.__dict__.items():
            if isinstance(field_value, Path):
                field_value.mkdir(parents=True, exist_ok=True)


class UnifiedConfig(BaseSettings):
    """Единый класс конфигурации"""

    model_config = SettingsConfigDict(
        env_file='.env',
        env_file_encoding='utf-8',
        extra='ignore',
        env_nested_delimiter='__'
    )

    # Конфигурация окружения
    environment: str = Field(default="development", description="Среда выполнения")
    debug: bool = Field(default=True, description="Режим отладки")
    encryption_key: str = Field(default="", description="Ключ шифрования")

    # Подконфигурации
    database: DatabaseConfig = Field(default_factory=DatabaseConfig)
    redis: RedisConfig = Field(default_factory=RedisConfig)
    api: APIConfig = Field(default_factory=APIConfig)
    processing: ProcessingConfig = Field(default_factory=ProcessingConfig)
    speech_recognition: SpeechRecognitionConfig = Field(default_factory=SpeechRecognitionConfig)
    bilibili: BilibiliConfig = Field(default_factory=BilibiliConfig)
    logging: LoggingConfig = Field(default_factory=LoggingConfig)
    paths: PathConfig = Field(default_factory=PathConfig)

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._load_from_files()
        self._setup_environment()

    def _load_from_files(self):
        """Загрузка настроек из файлов конфигурации"""
        # Загрузка из data/settings.json
        settings_file = self.paths.data_dir / "settings.json"
        if settings_file.exists():
            try:
                with open(settings_file, 'r', encoding='utf-8') as f:
                    file_settings = json.load(f)
                    self._merge_settings(file_settings)
            except Exception as e:
                logger.warning(f"Не удалось загрузить файл конфигурации: {e}")

        # Загрузка из переменных окружения
        self._load_from_env()

    def _merge_settings(self, settings: Dict[str, Any]):
        """Объединение настроек с объектом конфигурации"""
        for key, value in settings.items():
            if hasattr(self, key):
                if isinstance(getattr(self, key), BaseModel):
                    # Рекурсивное объединение для подконфигураций
                    sub_config = getattr(self, key)
                    if isinstance(value, dict):
                        for sub_key, sub_value in value.items():
                            if hasattr(sub_config, sub_key):
                                setattr(sub_config, sub_key, sub_value)
                else:
                    setattr(self, key, value)

    def _load_from_env(self):
        """Загрузка конфигурации из переменных окружения"""
        # Конфигурация БД
        if os.getenv("DATABASE_URL"):
            self.database.url = os.getenv("DATABASE_URL")

        # Конфигурация Redis
        if os.getenv("REDIS_URL"):
            self.redis.url = os.getenv("REDIS_URL")

        # Конфигурация API
        if os.getenv("DASHSCOPE_API_KEY"):
            self.api.dashscope_api_key = os.getenv("DASHSCOPE_API_KEY")
        if os.getenv("API_MODEL_NAME"):
            self.api.model_name = os.getenv("API_MODEL_NAME")

        # Конфигурация обработки
        if os.getenv("PROCESSING_CHUNK_SIZE"):
            self.processing.chunk_size = int(os.getenv("PROCESSING_CHUNK_SIZE"))
        if os.getenv("PROCESSING_MIN_SCORE_THRESHOLD"):
            self.processing.min_score_threshold = float(os.getenv("PROCESSING_MIN_SCORE_THRESHOLD"))

        # Конфигурация логирования
        if os.getenv("LOG_LEVEL"):
            self.logging.level = os.getenv("LOG_LEVEL")
        if os.getenv("LOG_FILE"):
            self.logging.file = os.getenv("LOG_FILE")

    def _setup_environment(self):
        """Настройка переменных окружения"""
        # Установка API-ключа в переменные окружения
        if self.api.dashscope_api_key:
            os.environ["DASHSCOPE_API_KEY"] = self.api.dashscope_api_key

        # Установка URL БД
        os.environ["DATABASE_URL"] = self.database.url

        # Установка URL Redis
        os.environ["REDIS_URL"] = self.redis.url

    def save_to_file(self, file_path: Optional[Path] = None):
        """Сохранение конфигурации в файл"""
        if file_path is None:
            file_path = self.paths.data_dir / "settings.json"

        try:
            # Создание словаря конфигурации без чувствительных данных
            config_dict = self._to_safe_dict()

            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(config_dict, f, ensure_ascii=False, indent=2)

            logger.info(f"Конфигурация сохранена в: {file_path}")

        except Exception as e:
            logger.error(f"Не удалось сохранить файл конфигурации: {e}")
            raise

    def _to_safe_dict(self) -> Dict[str, Any]:
        """Преобразование в безопасный словарь (скрытие чувствительных данных)"""
        config_dict = {}

        for key, value in self.__dict__.items():
            if key.startswith('_'):
                continue

            if isinstance(value, BaseModel):
                config_dict[key] = value.dict()
            else:
                config_dict[key] = value

        # Скрытие чувствительных данных
        if 'api' in config_dict and 'dashscope_api_key' in config_dict['api']:
            api_key = config_dict['api']['dashscope_api_key']
            if api_key:
                config_dict['api']['dashscope_api_key'] = api_key[:8] + "..." if len(api_key) > 8 else "***"

        return config_dict

    def update_config(self, **kwargs):
        """Обновление конфигурации"""
        for key, value in kwargs.items():
            if hasattr(self, key):
                if isinstance(getattr(self, key), BaseModel):
                    # Рекурсивное обновление для подконфигураций
                    sub_config = getattr(self, key)
                    if isinstance(value, dict):
                        for sub_key, sub_value in value.items():
                            if hasattr(sub_config, sub_key):
                                setattr(sub_config, sub_key, sub_value)
                else:
                    setattr(self, key, value)

        # Повторная настройка переменных окружения
        self._setup_environment()

        # Сохранение в файл
        self.save_to_file()

    def get_config_summary(self) -> Dict[str, Any]:
        """Получение сводки конфигурации"""
        return {
            "environment": self.environment,
            "debug": self.debug,
            "database": {
                "url": self.database.url,
                "echo": self.database.echo
            },
            "redis": {
                "url": self.redis.url
            },
            "api": {
                "model_name": self.api.model_name,
                "max_tokens": self.api.max_tokens,
                "timeout": self.api.timeout,
                "has_api_key": bool(self.api.dashscope_api_key)
            },
            "processing": {
                "chunk_size": self.processing.chunk_size,
                "min_score_threshold": self.processing.min_score_threshold,
                "max_clips_per_collection": self.processing.max_clips_per_collection
            },
            "speech_recognition": {
                "method": self.speech_recognition.method,
                "language": self.speech_recognition.language,
                "model": self.speech_recognition.model
            },
            "bilibili": {
                "auto_upload": self.bilibili.auto_upload,
                "default_tid": self.bilibili.default_tid,
                "max_concurrent_uploads": self.bilibili.max_concurrent_uploads
            },
            "logging": {
                "level": self.logging.level,
                "file": self.logging.file
            },
            "paths": {
                "data_dir": str(self.paths.data_dir),
                "uploads_dir": str(self.paths.uploads_dir),
                "output_dir": str(self.paths.output_dir),
                "temp_dir": str(self.paths.temp_dir)
            }
        }

    def validate_config(self) -> Dict[str, Any]:
        """Валидация конфигурации"""
        issues = []

        # Валидация API конфигурации
        if not self.api.dashscope_api_key:
            issues.append("API-ключ DashScope не настроен")

        # Валидация путей
        for path_name, path_value in self.paths.__dict__.items():
            if isinstance(path_value, Path) and not path_value.exists():
                issues.append(f"Путь не существует: {path_name} = {path_value}")

        # Валидация подключения к БД
        if not self.database.url:
            issues.append("URL базы данных не настроен")

        # Валидация подключения к Redis
        if not self.redis.url:
            issues.append("URL Redis не настроен")

        return {
            "valid": len(issues) == 0,
            "issues": issues
        }


# Глобальный экземпляр конфигурации
config = UnifiedConfig()


# Удобные функции
def get_config() -> UnifiedConfig:
    """Получение глобального экземпляра конфигурации"""
    return config


def get_database_url() -> str:
    """Получение URL базы данных"""
    return config.database.url


def get_redis_url() -> str:
    """Получение URL Redis"""
    return config.redis.url


def get_api_key() -> str:
    """Получение API-ключа"""
    return config.api.dashscope_api_key


def get_data_directory() -> Path:
    """Получение директории данных"""
    return config.paths.data_dir


def get_uploads_directory() -> Path:
    """Получение директории загрузок"""
    return config.paths.uploads_dir


def get_output_directory() -> Path:
    """Получение выходной директории"""
    return config.paths.output_dir


def get_temp_directory() -> Path:
    """Получение временной директории"""
    return config.paths.temp_dir


def get_prompt_directory() -> Path:
    """Получение директории с промптами"""
    return config.paths.prompt_dir


def update_api_key(api_key: str):
    """Обновление API-ключа"""
    config.api.dashscope_api_key = api_key
    config._setup_environment()
    config.save_to_file()


def update_processing_config(**kwargs):
    """Обновление конфигурации обработки"""
    config.update_config(processing=kwargs)


def update_bilibili_config(**kwargs):
    """Обновление конфигурации Bilibili"""
    config.update_config(bilibili=kwargs)
