#!/usr/bin/env bash

# AutoClip - Скрипт быстрого запуска
# Версия: 2.0
# Функция: Запуск полной системы AutoClip (API бэкенда + Celery Worker + интерфейс фронтенда)

# =============================================================================
# Конфигурация
# =============================================================================

# Порты сервисов
BACKEND_PORT=8000
FRONTEND_PORT=3000
REDIS_PORT=6379

# Таймауты запуска сервисов
BACKEND_STARTUP_TIMEOUT=60
FRONTEND_STARTUP_TIMEOUT=90
HEALTH_CHECK_TIMEOUT=10

# Конфигурация логов
LOG_DIR="logs"
BACKEND_LOG="$LOG_DIR/backend.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"
CELERY_LOG="$LOG_DIR/celery.log"

# PID файлы
BACKEND_PID_FILE="backend.pid"
FRONTEND_PID_FILE="frontend.pid"
CELERY_PID_FILE="celery.pid"

# =============================================================================
# Определение цветов и стилей
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # Без цвета

# Определение иконок
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_ROCKET="🚀"
ICON_GEAR="⚙️"
ICON_DATABASE="🗄️"
ICON_WORKER="👷"
ICON_WEB="🌐"
ICON_HEALTH="💚"

# =============================================================================
# Вспомогательные функции
# =============================================================================

log_info() {
    echo -e "${BLUE}${ICON_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${ICON_WARNING} $1${NC}"
}

log_error() {
    echo -e "${RED}${ICON_ERROR} $1${NC}"
}

log_header() {
    echo -e "\n${PURPLE}${ICON_ROCKET} $1${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..50})${NC}"
}

log_step() {
    echo -e "\n${CYAN}${ICON_GEAR} $1${NC}"
}

# Проверка занятости порта
port_in_use() {
    lsof -i ":$1" >/dev/null 2>&1
}

# Ожидание запуска сервиса
wait_for_service() {
    local url="$1"
    local timeout="$2"
    local service_name="$3"

    log_info "Ожидание запуска $service_name..."

    for i in $(seq 1 "$timeout"); do
        if curl -fsS "$url" >/dev/null 2>&1; then
            log_success "$service_name запущен"
            return 0
        fi
        sleep 1
    done

    log_error "Таймаут запуска $service_name"
    return 1
}

# Проверка работы процесса
process_running() {
    local pid_file="$1"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$pid_file"
        fi
    fi
    return 1
}

# Остановка процесса
stop_process() {
    local pid_file="$1"
    local service_name="$2"

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Остановка $service_name (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                log_warning "Принудительная остановка $service_name..."
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$pid_file"
    fi
}

# =============================================================================
# Функции проверки окружения
# =============================================================================
command_exists() {
    command -v "$1" >/dev/null 2>&1
}
check_environment() {
    log_header "Проверка окружения"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_success "Обнаружена система macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "Обнаружена система Linux"
    else
        log_warning "Неизвестная операционная система: $OSTYPE"
    fi

    # init nvm
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh"
        nvm use default >/dev/null 2>&1
    fi

    local required_commands=("python3" "node" "npm" "redis-cli")

    for cmd in "${required_commands[@]}"; do
        if command_exists "$cmd"; then
            log_success "$cmd установлен"
        else
            log_error "$cmd не установлен, пожалуйста, установите"
            read -p "Нажмите Enter для выхода"
            exit 1
        fi
    done

    # Проверка версии Python
    local python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
    log_info "Версия Python: $python_version"

    # Проверка версии Node.js
    local node_version=$(node --version)
    log_info "Версия Node.js: $node_version"

    # Проверка виртуального окружения
    if [[ ! -d "venv" ]]; then
        log_error "Виртуальное окружение не существует, сначала создайте: python3 -m venv venv"
        exit 1
    fi
    log_success "Виртуальное окружение существует"

    # Проверка структуры проекта
    local required_dirs=("backend" "frontend" "data")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Директория $dir существует"
        else
            log_error "Директория $dir не существует"
            exit 1
        fi
    done
}

# =============================================================================
# Функции запуска сервисов
# =============================================================================

start_redis() {
    log_step "Запуск сервиса Redis"

    if redis-cli ping >/dev/null 2>&1; then
        log_success "Сервис Redis уже запущен"
        return 0
    fi

    log_info "Запуск сервиса Redis..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            brew services start redis
            sleep 3
        else
            log_error "Пожалуйста, запустите сервис Redis вручную"
            exit 1
        fi
    else
        systemctl start redis-server 2>/dev/null || service redis-server start 2>/dev/null || {
            log_error "Не удалось запустить сервис Redis, запустите вручную"
            exit 1
        }
    fi

    if redis-cli ping >/dev/null 2>&1; then
        log_success "Сервис Redis успешно запущен"
    else
        log_error "Не удалось запустить сервис Redis"
        exit 1
    fi
}

setup_environment() {
    log_step "Настройка окружения"

    # Создание директории для логов
    mkdir -p "$LOG_DIR"

    # Активация виртуального окружения
    log_info "Активация виртуального окружения..."
    source venv/bin/activate

    # Установка пути Python
    : "${PYTHONPATH:=}"
    export PYTHONPATH="${PWD}:${PYTHONPATH}"
    log_info "Установка пути Python: $PYTHONPATH"

    # Загрузка переменных окружения
    if [[ -f ".env" ]]; then
        log_info "Загрузка переменных окружения..."
        set -a
        source .env
        set +a
        log_success "Переменные окружения загружены"
    else
        log_warning "Файл .env не найден, используется конфигурация по умолчанию"
        # Создание файла .env по умолчанию
        if [[ ! -f ".env" ]]; then
            log_info "Создание файла .env по умолчанию..."
            cp env.example .env 2>/dev/null || {
                cat > .env << EOF
# AutoClip Конфигурация окружения
DATABASE_URL=sqlite:///./data/autoclip.db
REDIS_URL=redis://localhost:6379/0
API_DASHSCOPE_API_KEY=
API_MODEL_NAME=qwen-plus
LOG_LEVEL=INFO
ENVIRONMENT=development
DEBUG=true
EOF
                log_success "Создан файл .env по умолчанию"
            }
        fi
    fi

    # Проверка зависимостей Python
    log_info "Проверка зависимостей Python..."
    if ! python -c "import fastapi, celery, sqlalchemy" 2>/dev/null; then
        log_warning "Отсутствуют зависимости, установка..."
        pip install -r requirements.txt
    fi
    log_success "Проверка зависимостей Python завершена"
}

init_database() {
    log_step "Инициализация базы данных"

    # Создание директории данных
    mkdir -p data

    # Инициализация базы данных
    log_info "Создание таблиц базы данных..."
    if python -c "
import sys
sys.path.insert(0, '.')
from backend.core.database import engine, Base
from backend.models import project, task, clip, collection, bilibili
try:
    Base.metadata.create_all(bind=engine)
    print('Таблицы базы данных успешно созданы')
except Exception as e:
    print(f'Ошибка инициализации базы данных: {e}')
    sys.exit(1)
" 2>/dev/null; then
        log_success "Инициализация базы данных успешна"
    else
        log_error "Ошибка инициализации базы данных"
        exit 1
    fi
}

start_celery() {
    log_step "Запуск Celery Worker"

    # Остановка существующих процессов Celery
    pkill -f "celery.*worker" 2>/dev/null || true
    sleep 2

    log_info "Запуск Celery Worker..."
    nohup celery -A backend.core.celery_app worker \
        --loglevel=info \
        --concurrency=2 \
        -Q processing,upload,notification,maintenance \
        --hostname=worker@%h \
        > "$CELERY_LOG" 2>&1 &

    local celery_pid=$!
    echo "$celery_pid" > "$CELERY_PID_FILE"

    # Ожидание запуска Worker
    sleep 5

    if pgrep -f "celery.*worker" >/dev/null; then
        log_success "Celery Worker запущен (PID: $celery_pid)"
    else
        log_error "Не удалось запустить Celery Worker"
        log_info "Просмотр логов: tail -f $CELERY_LOG"
        exit 1
    fi
}

start_backend() {
    log_step "Запуск сервиса API бэкенда"

    # Проверка занятости порта
    if port_in_use "$BACKEND_PORT"; then
        log_warning "Порт $BACKEND_PORT занят, попытка остановки существующего сервиса..."
        stop_process "$BACKEND_PID_FILE" "Сервис бэкенда"
    fi

    log_info "Запуск сервиса бэкенда (порт: $BACKEND_PORT)..."
    nohup python -m uvicorn backend.main:app \
        --host 0.0.0.0 \
        --port "$BACKEND_PORT" \
        --reload \
        --reload-dir backend \
        --reload-include '*.py' \
        --reload-exclude 'data/*' \
        --reload-exclude 'logs/*' \
        --reload-exclude 'uploads/*' \
        --reload-exclude '*.log' \
        > "$BACKEND_LOG" 2>&1 &

    local backend_pid=$!
    echo "$backend_pid" > "$BACKEND_PID_FILE"

    # Ожидание запуска бэкенда
    if wait_for_service "http://localhost:$BACKEND_PORT/api/v1/health/" "$BACKEND_STARTUP_TIMEOUT" "Сервис бэкенда"; then
        log_success "Сервис бэкенда запущен (PID: $backend_pid)"
    else
        log_error "Не удалось запустить сервис бэкенда"
        log_info "Просмотр логов: tail -f $BACKEND_LOG"
        exit 1
    fi
}

start_frontend() {
    log_step "Запуск сервиса фронтенда"

    # Проверка занятости порта
    if port_in_use "$FRONTEND_PORT"; then
        log_warning "Порт $FRONTEND_PORT занят, попытка остановки существующего сервиса..."
        stop_process "$FRONTEND_PID_FILE" "Сервис фронтенда"
    fi

    # Переход в директорию фронтенда
    cd frontend || {
        log_error "Не удалось войти в директорию фронтенда"
        exit 1
    }

    # Проверка зависимостей фронтенда
    if [[ ! -d "node_modules" ]]; then
        log_info "Установка зависимостей фронтенда..."
        npm install
    fi

    log_info "Запуск сервиса фронтенда (порт: $FRONTEND_PORT)..."
    nohup npm run dev -- --host 0.0.0.0 --port "$FRONTEND_PORT" \
        > "../$FRONTEND_LOG" 2>&1 &

    local frontend_pid=$!
    echo "$frontend_pid" > "../$FRONTEND_PID_FILE"

    # Возврат в корневую директорию проекта
    cd ..

    # Ожидание запуска фронтенда
    if wait_for_service "http://localhost:$FRONTEND_PORT/" "$FRONTEND_STARTUP_TIMEOUT" "Сервис фронтенда"; then
        log_success "Сервис фронтенда запущен (PID: $frontend_pid)"
    else
        log_error "Не удалось запустить сервис фронтенда"
        log_info "Просмотр логов: tail -f $FRONTEND_LOG"
        exit 1
    fi
}

# =============================================================================
# Функции проверки здоровья
# =============================================================================

health_check() {
    log_header "Проверка здоровья системы"

    local all_healthy=true

    # Проверка бэкенда
    log_info "Проверка сервиса бэкенда..."
    if curl -fsS "http://localhost:$BACKEND_PORT/api/v1/health/" >/dev/null 2>&1; then
        log_success "Сервис бэкенда здоров"
    else
        log_error "Сервис бэкенда нездоров"
        all_healthy=false
    fi

    # Проверка фронтенда
    log_info "Проверка сервиса фронтенда..."
    if curl -fsS "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1; then
        log_success "Сервис фронтенда здоров"
    else
        log_error "Сервис фронтенда нездоров"
        all_healthy=false
    fi

    # Проверка Redis
    log_info "Проверка сервиса Redis..."
    if redis-cli ping >/dev/null 2>&1; then
        log_success "Сервис Redis здоров"
    else
        log_error "Сервис Redis нездоров"
        all_healthy=false
    fi

    # Проверка Celery Worker
    log_info "Проверка Celery Worker..."
    if pgrep -f "celery.*worker" >/dev/null; then
        log_success "Celery Worker здоров"
    else
        log_error "Celery Worker нездоров"
        all_healthy=false
    fi

    if [[ "$all_healthy" == true ]]; then
        log_success "Все сервисы прошли проверку здоровья"
        return 0
    else
        log_error "Некоторые сервисы не прошли проверку здоровья"
        return 1
    fi
}

# =============================================================================
# Функции очистки
# =============================================================================

cleanup() {
    log_header "Очистка сервисов"

    stop_process "$BACKEND_PID_FILE" "Сервис бэкенда"
    stop_process "$FRONTEND_PID_FILE" "Сервис фронтенда"
    stop_process "$CELERY_PID_FILE" "Celery Worker"

    # Остановка всех связанных процессов
    pkill -f "celery.*worker" 2>/dev/null || true
    pkill -f "uvicorn.*backend.main:app" 2>/dev/null || true
    pkill -f "npm.*dev" 2>/dev/null || true

    log_success "Очистка завершена"
}

# =============================================================================
# Отображение информации о системе
# =============================================================================

show_system_info() {
    log_header "Запуск системы завершен"

    echo -e "${WHITE}🎉 Система AutoClip успешно запущена!${NC}"
    echo ""
    echo -e "${CYAN}📊 Состояние сервисов:${NC}"
    echo -e "  ${ICON_WEB} API бэкенда:    http://localhost:$BACKEND_PORT"
    echo -e "  ${ICON_WEB} Интерфейс:      http://localhost:$FRONTEND_PORT"
    echo -e "  ${ICON_WEB} Документация API: http://localhost:$BACKEND_PORT/docs"
    echo -e "  ${ICON_HEALTH} Проверка здоровья: http://localhost:$BACKEND_PORT/api/v1/health/"
    echo ""
    echo -e "${CYAN}📝 Файлы логов:${NC}"
    echo -e "  Логи бэкенда: tail -f $BACKEND_LOG"
    echo -e "  Логи фронтенда: tail -f $FRONTEND_LOG"
    echo -e "  Логи Celery: tail -f $CELERY_LOG"
    echo ""
    echo -e "${CYAN}🛑 Остановка системы:${NC}"
    echo -e "  ./stop_autoclip.sh или нажмите Ctrl+C"
    echo ""
    echo -e "${YELLOW}💡 Инструкция по использованию:${NC}"
    echo -e "  1. Откройте http://localhost:$FRONTEND_PORT в браузере"
    echo -e "  2. Загрузите видеофайл или укажите ссылку на Bilibili"
    echo -e "  3. Система автоматически запустит AI конвейер обработки"
    echo -e "  4. Отслеживайте прогресс и результаты в реальном времени"
    echo ""
}

# =============================================================================
# Обработка сигналов
# =============================================================================

trap cleanup EXIT INT TERM

# =============================================================================
# Главная функция
# =============================================================================

main() {
    log_header "Запуск системы AutoClip v2.0"

    # Проверка окружения
    check_environment

    # Запуск сервисов
    start_redis
    setup_environment
    init_database
    start_celery
    start_backend
    start_frontend

    # Проверка здоровья
    if health_check; then
        show_system_info

        # Поддержание работы скрипта (без циклической проверки)
        log_info "Система работает... Нажмите Ctrl+C для остановки"
        log_info "Для проверки состояния системы выполните: ./status_autoclip.sh"
        while true; do
            sleep 3600  # Проверка каждый час, снижение частоты
        done
    else
        log_error "Не удалось запустить систему, проверьте логи"
    fi
            read -p "Нажмите Enter для завершения работы скрипта (сервисы продолжат работу в фоне)..."
}

# Запуск главной функции
main "$@"