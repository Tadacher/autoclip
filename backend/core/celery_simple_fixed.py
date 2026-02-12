

import os
from celery import Celery

celery_app = Celery('autoclip')

# 基本配置
celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    
    broker_url='redis://localhost:6379/0',
    result_backend='redis://localhost:6379/0',
    
    broker_transport='redis',
    broker_transport_options={},
    
    task_default_queue='processing',
    task_default_exchange='processing',
    task_default_routing_key='processing',
    
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
    
    autodiscover_tasks=False,
)

@celery_app.task(bind=True, name='tasks.processing.process_video_pipeline')
def process_video_pipeline(self, project_id: str, input_video_path: str, input_srt_path: str, *args, **kwargs):
    return backend_process_video_pipeline(self, project_id, input_video_path, input_srt_path, *args, **kwargs)

@celery_app.task(bind=True, name='tasks.processing.process_single_step')
def process_single_step(self, project_id: str, step: str, config: dict, *args, **kwargs):
    print(f"🔧 Начинаем обработку шага {step} для проекта {project_id}")
    if args:
        print(f"⚠️  Дополнительные позиционные аргументы: {args}")
    if kwargs:
        print(f"⚠️  Дополнительные именованные аргументы: {kwargs}")
    
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
def backend_process_video_pipeline(self, project_id: str, input_video_path: str, input_srt_path: str, *args, **kwargs):
    print(f"🎬 Начинаем обработку проекта: {project_id}")
    print(f"📹 Путь к видео: {input_video_path}")
    print(f"📝 Путь к субтитрам: {input_srt_path}")
    if args:
        print(f"⚠️  Дополнительные позиционные аргументы: {args}")
    if kwargs:
        print(f"⚠️  Дополнительные именованные аргументы: {kwargs}")

    task_id = self.request.id
    print(f"🔑 ID задачи Celery: {task_id}")

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
        print(f"📊 шаг {i+1}/6: {step} - {progress}%")
        
        try:
            self.update_state(
                state='PROGRESS',
                meta={
                    'current': i + 1,
                    'total': 6,
                    'status': f'шаг: {step}',
                    'progress': progress
                }
            )
        except Exception as e:
            print(f"⚠️  更新任务状态失败: {e}")
        
        time.sleep(2)
    
    print(f"✅ 项目 {project_id} 处理完成")
    
    try:
        from ..core.database import SessionLocal
        from ..models.task import Task, TaskStatus
        from ..models.project import Project, ProjectStatus
        from datetime import datetime
        
        db = SessionLocal()
        try:
            task = db.query(Task).filter(Task.id == task_id).first()
            if task:
                task.status = TaskStatus.COMPLETED
                task.progress = 100.0
                task.current_step = 'Завершено'
                task.completed_at = datetime.utcnow()
                task.updated_at = datetime.utcnow()
                print(f"✅ Статус задачи обновлен в базе данных")
            else:
                print(f"⚠️  Задача не найдена: {task_id}")

            # Обновление статуса проекта
            project = db.query(Project).filter(Project.id == project_id).first()
            if project:
                project.status = ProjectStatus.COMPLETED
                project.completed_at = datetime.utcnow()
                project.updated_at = datetime.utcnow()
                print(f"✅ Статус проекта обновлен на завершен: {project_id}")
            else:
                print(f"⚠️  Проект не найден: {project_id}")

            db.commit()

        finally:
            db.close()

    except Exception as e:
        print(f"⚠️  Не удалось обновить статус в базе данных: {e}")

    return {
        "success": True,
        "project_id": project_id,
        "message": "Обработка видео завершена",
        "steps": steps
    }

@celery_app.task(bind=True, name='backend.tasks.processing.process_single_step')
def backend_process_single_step(self, project_id: str, step: str, config: dict, *args, **kwargs):
    return process_single_step(self, project_id, step, config, *args, **kwargs)

if __name__ == '__main__':
    celery_app.start()
