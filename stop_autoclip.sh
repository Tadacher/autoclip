#!/bin/bash
set -euo pipefail

set -euo pipefail

# =============================================================================
# Конфигурация
# =============================================================================

# PID файлы
BACKEND_PID_FILE="backend.pid"
FRONTEND_PID_FILE="frontend.pid"
CELERY_PID_FILE="celery.pid"

# Директория для логов
LOG_DIR="logs"

# =============================================================================
# Определение цветов и стилей
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # Без цвета

# Определение иконок
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_STOP="🛑"
ICON_CLEAN="🧹"

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
    echo -e "\n${PURPLE}${ICON_STOP} $1${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..50})${NC}"
}

# Остановка процесса
stop_process() {
    local pid_file="$1"
    local service_name="$2"

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Остановка $service_name (PID: $pid)..."

            # Плавная остановка
            kill "$pid" 2>/dev/null || true

            # Ожидание завершения процесса
            local count=0
            while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
                sleep 1
                ((count++))
            done

            # Принудительная остановка, если процесс все еще работает
            if kill -0 "$pid" 2>/dev/null; then
                log_warning "Принудительная остановка $service_name..."
                kill -9 "$pid" 2>/dev/null || true
                sleep 1
            fi

            if kill -0 "$pid" 2>/dev/null; then
                log_error "Не удалось остановить $service_name"
            else
                log_success "$service_name остановлен"
            fi
        else
            log_warning "Процесс $service_name не существует"
        fi
        rm -f "$pid_file"
    else
        log_info "PID файл для $service_name не найден"
    fi
}

# Остановка всех связанных процессов
stop_all_processes() {
    log_header "Остановка всех сервисов AutoClip"

    # Остановка процессов, управляемых через PID файлы
    stop_process "$BACKEND_PID_FILE" "Сервис бэкенда"
    stop_process "$FRONTEND_PID_FILE" "Сервис фронтенда"
    stop_process "$CELERY_PID_FILE" "Celery Worker"

    # Остановка всех связанных процессов
    log_info "Остановка всех Celery Worker процессов..."
    pkill -f "celery.*worker" 2>/dev/null || true

    log_info "Остановка всех процессов API бэкенда..."
    pkill -f "uvicorn.*backend.main:app" 2>/dev/null || true

    log_info "Остановка всех серверов разработки фронтенда..."
    pkill -f "npm.*dev" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true

    # Ожидание полной остановки процессов
    sleep 2

    log_success "Все сервисы остановлены"
}

# Очистка временных файлов
cleanup_temp_files() {
    log_header "Очистка временных файлов"

    # Очистка PID файлов
    rm -f "$BACKEND_PID_FILE" "$FRONTEND_PID_FILE" "$CELERY_PID_FILE"
    log_success "PID файлы очищены"

    # Очистка временных файлов Celery
    rm -f /tmp/celerybeat-schedule /tmp/celerybeat.pid 2>/dev/null || true
    log_success "Временные файлы Celery очищены"

    # Очистка кэша Python
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    log_success "Кэш Python очищен"
}

# Отображение состояния системы
show_system_status() {
    log_header "Проверка состояния системы"

    local services_running=false

    # Проверка сервиса бэкенда
    if pgrep -f "uvicorn.*backend.main:app" >/dev/null; then
        log_warning "Сервис бэкенда все еще работает"
        services_running=true
    else
        log_success "Сервис бэкенда остановлен"
    fi

    # Проверка сервиса фронтенда
    if pgrep -f "npm.*dev\|vite" >/dev/null; then
        log_warning "Сервис фронтенда все еще работает"
        services_running=true
    else
        log_success "Сервис фронтенда остановлен"
    fi

    # Проверка Celery Worker
    if pgrep -f "celery.*worker" >/dev/null; then
        log_warning "Celery Worker все еще работает"
        services_running=true
    else
        log_success "Celery Worker остановлен"
    fi

    if [[ "$services_running" == true ]]; then
        log_warning "Некоторые сервисы все еще работают, может потребоваться ручная остановка"
        echo ""
        echo "Запущенные процессы:"
        pgrep -f "uvicorn.*backend.main:app\|npm.*dev\|vite\|celery.*worker" | while read pid; do
            ps -p "$pid" -o pid,ppid,cmd --no-headers 2>/dev/null || true
        done
    else
        log_success "Все сервисы AutoClip полностью остановлены"
    fi
}

# Отображение информации о логах
show_log_info() {
    log_header "Информация о файлах логов"

    if [[ -d "$LOG_DIR" ]]; then
        echo "Расположение файлов логов:"
        ls -la "$LOG_DIR"/*.log 2>/dev/null | while read line; do
            echo "  $line"
        done
        echo ""
        echo "Просмотр последних логов:"
        echo "  Логи бэкенда: tail -f $LOG_DIR/backend.log"
        echo "  Логи фронтенда: tail -f $LOG_DIR/frontend.log"
        echo "  Логи Celery: tail -f $LOG_DIR/celery.log"
    else
        log_info "Директория логов не существует"
    fi
}

# =============================================================================
# Главная функция
# =============================================================================

main() {
    log_header "Остановщик системы AutoClip v2.0"

    # Остановка всех сервисов
    stop_all_processes

    # Очистка временных файлов
    cleanup_temp_files

    # Отображение состояния системы
    show_system_status

    # Отображение информации о логах
    show_log_info

    echo ""
    log_success "Система AutoClip полностью остановлена"
    echo ""
    echo "Для повторного запуска выполните: ./start_autoclip.sh"
    read -p "Нажмите Enter для завершения работы скрипта ..."
}

# 运行主函数
main "$@"
