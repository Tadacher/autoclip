#!/bin/bash

set -euo pipefail

BACKEND_PORT=8000
FRONTEND_PORT=3000

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
echo "Текущая директория: $(pwd)"
echo "Скрипт запущен из: $(dirname "$0")"
ls -la .env 2>&1 || echo ".env не найден в $(pwd)"

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

main() {
    # Проверка виртуального окружения
    if [[ ! -d "venv" ]]; then
        log_warning "Виртуальное окружение не найдено. Сначала выполните: python3 -m venv venv"
        exit 1
    fi

    # Активация виртуального окружения
    log_info "Активация виртуального окружения..."
    source venv/bin/activate

    # Установка пути Python
    : "${PYTHONPATH:=}"
    export PYTHONPATH="${PWD}:${PYTHONPATH}"
    log_success "2"
    # Загрузка переменных окружения
    if [[ -f ".env" ]]; then
        set -a
        source .env
        set +a
    fi
    log_success "3"

    # Запуск Redis (при необходимости)
    if ! redis-cli ping >/dev/null 2>&1; then
        log_info "Запуск Redis..."
        if command -v brew >/dev/null; then
            brew services start redis
            sleep 2
        fi
    fi
    log_success "4"

    # Создание директории для логов
    mkdir -p logs
    log_success "5"

    # Запуск бэкенда
    log_info "Запуск сервиса бэкенда..."
    nohup python -m uvicorn backend.main:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload > logs/backend.log 2>&1 &
    echo $! > backend.pid

    # Запуск Celery Worker
    log_info "Запуск Celery Worker..."
    nohup celery -A backend.core.celery_app worker --loglevel=info --concurrency=2 -Q processing,upload,notification,maintenance > logs/celery.log 2>&1 &
    echo $! > celery.pid

    # Запуск фронтенда
    log_info "Запуск сервиса фронтенда..."
    cd frontend
    nohup npm run dev -- --host 0.0.0.0 --port "$FRONTEND_PORT" > ../logs/frontend.log 2>&1 &
    echo $! > ../frontend.pid
    cd ..

    # Ожидание запуска сервисов
    log_info "Ожидание запуска сервисов..."
    sleep 5

    # Проверка состояния сервисов
    if curl -fsS "http://localhost:$BACKEND_PORT/api/v1/health/" >/dev/null 2>&1; then
        log_success "Сервис бэкенда запущен"
    else
        log_warning "Возможны проблемы с запуском сервиса бэкенда"
    fi

    if curl -fsS "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1; then
        log_success "Сервис фронтенда запущен"
    else
        log_warning "Возможны проблемы с запуском сервиса фронтенда"
    fi

    echo ""
    log_success "Быстрый запуск завершен!"
    echo ""
    echo "🌐 Адреса для доступа:"
    echo "  Фронтенд: http://localhost:$FRONTEND_PORT"
    echo "  Бэкенд: http://localhost:$BACKEND_PORT"
    echo "  Документация API: http://localhost:$BACKEND_PORT/docs"
    echo ""
    echo "📝 Просмотр логов:"
    echo "  tail -f logs/backend.log"
    echo "  tail -f logs/frontend.log"
    echo "  tail -f logs/celery.log"
    echo ""
    echo "🛑 Остановка сервисов: ./stop_autoclip.sh"

    read -p "Нажмите Enter для завершения работы скрипта (сервисы продолжат работу в фоне)..."
}

# 运行主函数
main "$@"
