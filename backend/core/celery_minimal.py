
import os
import sys
from pathlib import Path
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
    
    autodiscover_tasks=False,
)

@celery_app.task(bind=True, name='tasks.processing.process_video_pipeline')
def process_video_pipeline(self, project_id: str, input_video_path: str, input_srt_path: str):

    print(f"🎬 Начинаем обработку проекта: {project_id}")
    print(f"📹 Путь к видео: {input_video_path}")
    print(f"📝 Путь к субтитрам: {input_srt_path}")
    
    # 模拟处理过程
    import time
    steps = [
        "Извлечение структуры",
        "Определение времени",
        "Оценка контента",
        "Генерация заголовков",
        "Кластеризация тем",
        "Нарезка видео"
    ]
    
    for i, step in enumerate(steps):
        progress = (i + 1) * 16
        print(f"Шаг {i + 1}/6: {step} - {progress}%")

        self.update_state(
            state='PROGRESS',
            meta={
                'current': i + 1,
                'total': 6,
                'status': f'Шаг: {step}',
                'progress': progress
            }
        )
        
        time.sleep(2)

    print(f"✅ Проект {project_id} обработан")
    return {
        "success": True,
        "project_id": project_id,
        "message": "Видео обработано",
        "steps": steps
    }

@celery_app.task(bind=True, name='tasks.processing.process_single_step')
def process_single_step(self, project_id: str, step: str, config: dict):
    print(f"🔧 Начинаем обработку шага {step} для проекта {project_id}")

    import time
    time.sleep(3)

    print(f"✅ Шаг {step} обработан")
    return {
        "success": True,
        "project_id": project_id,
        "step": step,
        "message": f"Шаг {step} обработан"
    }

@celery_app.task(bind=True, name='backend.tasks.processing.process_video_pipeline')
def backend_process_video_pipeline(self, project_id: str, input_video_path: str, input_srt_path: str):
    return process_video_pipeline(self, project_id, input_video_path, input_srt_path)

@celery_app.task(bind=True, name='backend.tasks.processing.process_single_step')
def backend_process_single_step(self, project_id: str, step: str, config: dict):
    return process_single_step(self, project_id, step, config)

if __name__ == '__main__':
    celery_app.start()

