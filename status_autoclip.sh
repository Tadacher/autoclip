#!/bin/bash

# AutoClip 系统状态检查脚本
# 版本: 2.0
# 功能: 检查AutoClip系统各服务的运行状态

set -euo pipefail

# =============================================================================
# 配置区域
# =============================================================================

# 服务端口配置
BACKEND_PORT=8000
FRONTEND_PORT=3000
REDIS_PORT=6379

# PID文件
BACKEND_PID_FILE="backend.pid"
FRONTEND_PID_FILE="frontend.pid"
CELERY_PID_FILE="celery.pid"

# 日志目录
LOG_DIR="logs"

# =============================================================================
# 颜色和样式定义
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 图标定义
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_HEALTH="💚"
ICON_SICK="🤒"
ICON_ROCKET="🚀"

# =============================================================================
# 工具函数
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

# Проверка состояния здоровья сервиса
check_service_health() {
    local url="$1"
    local service_name="$2"

    if curl -fsS "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}${ICON_HEALTH} $service_name здоров${NC}"
        return 0
    else
        echo -e "${RED}${ICON_SICK} $service_name нездоров${NC}"
        return 1
    fi
}

# Проверка состояния процесса
check_process_status() {
    local pid_file="$1"
    local service_name="$2"
    local process_pattern="$3"

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}${ICON_SUCCESS} $service_name запущен (PID: $pid)${NC}"
            return 0
        else
            echo -e "${RED}${ICON_ERROR} $service_name PID файл существует, но процесс отсутствует${NC}"
            return 1
        fi
    else
        # Проверка наличия запущенных процессов
        if pgrep -f "$process_pattern" >/dev/null; then
            local pids=$(pgrep -f "$process_pattern" | tr '\n' ' ')
            echo -e "${YELLOW}${ICON_WARNING} $service_name запущен без PID файла (PIDs: $pids)${NC}"
            return 0
        else
            echo -e "${RED}${ICON_ERROR} $service_name не запущен${NC}"
            return 1
        fi
    fi
}

# Получение информации о сервисе
get_service_info() {
    local service_name="$1"
    local pid_file="$2"
    local process_pattern="$3"

    echo -e "\n${CYAN}📊 Детальная информация $service_name:${NC}"

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "  PID: $pid"
            echo "  Информация о процессе:"
            ps -p "$pid" -o pid,ppid,etime,pcpu,pmem,cmd --no-headers 2>/dev/null | while read line; do
                echo "    $line"
            done
        fi
    else
        local pids=$(pgrep -f "$process_pattern" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            echo "  PIDs: $pids"
            echo "  Информация о процессах:"
            echo "$pids" | while read pid; do
                ps -p "$pid" -o pid,ppid,etime,pcpu,pmem,cmd --no-headers 2>/dev/null | while read line; do
                    echo "    $line"
                done
            done
        fi
    fi
}

# =============================================================================
# Функции проверки
# =============================================================================

check_redis() {
    log_header "Состояние сервиса Redis"

    if redis-cli ping >/dev/null 2>&1; then
        log_success "Сервис Redis работает нормально"

        # Получение информации о Redis
        echo -e "\n${CYAN}📊 Детальная информация Redis:${NC}"
        redis-cli info server | grep -E "(redis_version|uptime_in_seconds|connected_clients)" | while read line; do
            echo "  $line"
        done
        return 0
    else
        log_error "Сервис Redis не запущен или недоступен"
        return 1
    fi
}

check_backend() {
    log_header "Состояние сервиса API бэкенда"

    # Проверка состояния процесса
    if check_process_status "$BACKEND_PID_FILE" "Сервис бэкенда" "uvicorn.*backend.main:app"; then
        # Проверка состояния здоровья
        if check_service_health "http://localhost:$BACKEND_PORT/api/v1/health/" "API бэкенда"; then
            get_service_info "Сервис бэкенда" "$BACKEND_PID_FILE" "uvicorn.*backend.main:app"
            return 0
        else
            log_warning "Процесс бэкенда запущен, но API не отвечает"
            return 1
        fi
    else
        return 1
    fi
}

check_frontend() {
    log_header "Состояние сервиса фронтенда"

    # Проверка состояния процесса
    if check_process_status "$FRONTEND_PID_FILE" "Сервис фронтенда" "npm.*dev\|vite"; then
        # Проверка состояния здоровья
        if check_service_health "http://localhost:$FRONTEND_PORT/" "Интерфейс фронтенда"; then
            get_service_info "Сервис фронтенда" "$FRONTEND_PID_FILE" "npm.*dev\|vite"
            return 0
        else
            log_warning "Процесс фронтенда запущен, но сервис не отвечает"
            return 1
        fi
    else
        return 1
    fi
}

check_celery() {
    log_header "Состояние Celery Worker"

    # Проверка состояния процесса
    if check_process_status "$CELERY_PID_FILE" "Celery Worker" "celery.*worker"; then
        get_service_info "Celery Worker" "$CELERY_PID_FILE" "celery.*worker"

        # Проверка подключения Celery
        if command -v celery >/dev/null 2>&1; then
            echo -e "\n${CYAN}📊 Детальная информация Celery:${NC}"
            if PYTHONPATH="${PWD}:${PYTHONPATH:-}" celery -A backend.core.celery_app inspect active >/dev/null 2>&1; then
                log_success "Подключение Celery работает нормально"

                # Получение активных задач
                local active_tasks=$(PYTHONPATH="${PWD}:${PYTHONPATH:-}" celery -A backend.core.celery_app inspect active 2>/dev/null | jq -r '.[] | length' 2>/dev/null || echo "0")
                echo "  Количество активных задач: $active_tasks"
            else
                log_warning "Не удалось проверить подключение Celery"
            fi
        fi
        return 0
    else
        return 1
    fi
}

check_database() {
    log_header "Состояние базы данных"

    if [[ -f "data/autoclip.db" ]]; then
        log_success "Файл базы данных существует"

        # Получение информации о базе данных
        echo -e "\n${CYAN}📊 Детальная информация базы данных:${NC}"
        local db_size=$(du -h "data/autoclip.db" 2>/dev/null | cut -f1)
        echo "  Размер файла: $db_size"

        # Проверка подключения к базе данных
        if python -c "
import sys
sys.path.insert(0, '.')
from backend.core.database import test_connection
if test_connection():
    print('Подключение к базе данных работает нормально')
else:
    print('Ошибка подключения к базе данных')
    sys.exit(1)
" 2>/dev/null; then
            log_success "Подключение к базе данных работает нормально"
        else
            log_error "Ошибка подключения к базе данных"
            return 1
        fi
    else
        log_warning "Файл базы данных не существует"
        return 1
    fi
}

check_logs() {
    log_header "Состояние файлов логов"

    if [[ -d "$LOG_DIR" ]]; then
        log_success "Директория логов существует"

        echo -e "\n${CYAN}📊 Информация о файлах логов:${NC}"
        ls -la "$LOG_DIR"/*.log 2>/dev/null | while read line; do
            echo "  $line"
        done

        # Отображение последних логов
        echo -e "\n${CYAN}📝 Последние логи (последние 10 строк):${NC}"
        for log_file in "$LOG_DIR"/*.log; do
            if [[ -f "$log_file" ]]; then
                echo -e "\n${YELLOW}$(basename "$log_file"):${NC}"
                tail -n 5 "$log_file" 2>/dev/null | while read line; do
                    echo "  $line"
                done
            fi
        done
    else
        log_warning "Директория логов не существует"
    fi
}

# =============================================================================
# Главная функция
# =============================================================================

main() {
    log_header "Проверка состояния системы AutoClip v2.0"

    local overall_status=0

    # Проверка каждого сервиса
    check_redis || overall_status=1
    check_database || overall_status=1
    check_celery || overall_status=1
    check_backend || overall_status=1
    check_frontend || overall_status=1
    check_logs

    # Отображение общего состояния
    log_header "Общее состояние системы"

    if [[ $overall_status -eq 0 ]]; then
        log_success "Все сервисы работают нормально"
        echo ""
        echo -e "${WHITE}🎉 Система AutoClip полностью работоспособна!${NC}"
        echo ""
        echo -e "${CYAN}🌐 Адреса для доступа:${NC}"
        echo -e "  Интерфейс фронтенда: http://localhost:$FRONTEND_PORT"
        echo -e "  API бэкенда: http://localhost:$BACKEND_PORT"
        echo -e "  Документация API: http://localhost:$BACKEND_PORT/docs"
    else
        log_error "Некоторые сервисы работают некорректно"
        echo ""
        echo -e "${YELLOW}💡 Рекомендации:${NC}"
        echo -e "  1. Просмотрите файлы логов для получения детальной информации об ошибках"
        echo -e "  2. Перезапустите систему: ./stop_autoclip.sh && ./start_autoclip.sh"
        echo -e "  3. Проверьте конфигурацию окружения и зависимости"
    fi

    echo ""
    echo -e "${CYAN}📋 Часто используемые команды:${NC}"
    echo -e "  Запуск системы: ./start_autoclip.sh"
    echo -e "  Остановка системы: ./stop_autoclip.sh"
    echo -e "  Просмотр логов: tail -f $LOG_DIR/*.log"

    read -p "Нажмите Enter для завершения работы скрипта (сервисы продолжат работу в фоне)..."
}

# 运行主函数
main "$@"
