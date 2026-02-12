
import os
from celery import Celery

celery_app = Celery('autoclip')

celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    
    broker_url='redis://localhost:6379/0',
    result_backend='redis://localhost:6379/0',
    
    timezone='Asia/Shanghai',
    enable_utc=True,
    
    task_always_eager=False,
    task_eager_propagates=True,
    
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
    worker_disable_rate_limits=True,
    
    result_expires=3600,
    task_ignore_result=False,
    
    task_routes={
        'backend.tasks.processing.*': {'queue': 'processing'},
        'backend.tasks.video.*': {'queue': 'upload'},
        'backend.tasks.notification.*': {'queue': 'notification'},
        'backend.tasks.maintenance.*': {'queue': 'maintenance'},
        'backend.tasks.upload.*': {'queue': 'upload'},
    },
    
    task_track_started=True,
    task_time_limit=30 * 60,
    task_soft_time_limit=25 * 60,
)

celery_app.autodiscover_tasks([
    'backend.tasks.processing',
    'backend.tasks.video', 
    'backend.tasks.notification',
    'backend.tasks.maintenance',
    'backend.tasks.upload'
])

@celery_app.task(bind=True, name='backend.tasks.processing.process_video_pipeline')
def process_video_pipeline(self, project_id: str, input_video_path: str, input_srt_path: str):
    print(f"开始处理项目: {project_id}")
    print(f"视频路径: {input_video_path}")
    print(f"字幕路径: {input_srt_path}")
    
    import time
    for i in range(6):
        print(f"步骤 {i+1}/6: 处理中...")
        time.sleep(2)
    
    print(f"项目 {project_id} 处理完成")
    return {
        "success": True,
        "project_id": project_id,
        "message": "视频处理完成"
    }

@celery_app.task(bind=True, name='backend.tasks.processing.process_single_step')
def process_single_step(self, project_id: str, step: str, config: dict):
    print(f"开始处理项目 {project_id} 的步骤: {step}")

    import time
    time.sleep(3)
    
    print(f"Шаг {step} выполнен")
    return {
        "success": True,
        "project_id": project_id,
        "step": step,
        "message": f"步骤 {step} 处理完成"
    }

@celery_app.task(bind=True, name='backend.tasks.upload.upload_to_bilibili')
def upload_to_bilibili(self, project_id: str, video_path: str, title: str, description: str):

    print(f"Начинаем загрузку проекта {project_id} на B站")
    print(f"Название: {title}")
    print(f"Описание: {description}")
    
    import time
    time.sleep(5)

    print(f"Проект {project_id} успешно загружен")
    return {
        "success": True,
        "project_id": project_id,
        "message": "Загрузка завершена"
    }

if __name__ == '__main__':
    celery_app.start()

