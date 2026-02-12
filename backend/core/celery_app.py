
import os
from celery import Celery
from celery.schedules import crontab
from pathlib import Path

# os.environ.setdefault('CELERY_CONFIG_MODULE', 'backend.core.celery_app')

celery_app = Celery('autoclip')

class CeleryConfig:

    task_serializer = 'json'
    accept_content = ['json']
    result_serializer = 'json'
    timezone = 'Asia/Shanghai'
    enable_utc = True
    
    broker_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    result_backend = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    
    task_always_eager = os.getenv('CELERY_ALWAYS_EAGER', 'False').lower() == 'true'
    task_eager_propagates = True
    
    worker_prefetch_multiplier = 1
    worker_max_tasks_per_child = 1000
    worker_disable_rate_limits = True
    
    task_routes = {
        'backend.tasks.processing.*': {'queue': 'processing'},
        'backend.tasks.video.*': {'queue': 'video'},
        'backend.tasks.notification.*': {'queue': 'notification'},
        'backend.tasks.upload.*': {'queue': 'upload'},
        'backend.tasks.import_processing.*': {'queue': 'processing'},
    }
    
    beat_schedule = {
        'cleanup-expired-tasks': {
            'task': 'backend.tasks.maintenance.cleanup_expired_tasks',
            'schedule': crontab(hour=2, minute=0),  # 每天凌晨2点
        },
        'health-check': {
            'task': 'backend.tasks.maintenance.health_check',
            'schedule': crontab(minute='*/5'),  # 每5分钟
        },
    }
    
    result_expires = 3600
    task_ignore_result = False
    
    worker_log_format = '[%(asctime)s: %(levelname)s/%(processName)s] %(message)s'
    worker_task_log_format = '[%(asctime)s: %(levelname)s/%(processName)s] [%(task_name)s(%(task_id)s)] %(message)s'

celery_app.config_from_object(CeleryConfig)

celery_app.autodiscover_tasks([
    'backend.tasks.processing',
    'backend.tasks.video', 
    'backend.tasks.notification',
    'backend.tasks.maintenance',
    'backend.tasks.import_processing'
])

if __name__ == '__main__':
    celery_app.start()