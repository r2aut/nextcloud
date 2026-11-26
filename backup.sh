#!/bin/bash

# ----------------------------------------------
# Процедура резервного копирования для Nextcloud
# ----------------------------------------------

# Функция для вывода сообщений с временной отметкой
log() {
    if [ -n "$1" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    else
        while IFS= read -r line; do
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $line"
        done
    fi
}


# Путь к папке проекта, где лежит ваш docker-compose.yml
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/opt/nextcloud/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Создаем папку для бэкапов, если её еще нет
mkdir -p "$BACKUP_DIR"

# Переходим в папку проекта, чтобы команды docker compose работали корректно
cd "$PROJECT_DIR"

log "Начало резервного копирования."

log "Включение режима обслуживания..."
docker compose exec -T --user www-data app php occ maintenance:mode --on 2>&1 | log

log "Дамп базы данных PostgreSQL..."
docker compose exec -T db pg_dump --clean --if-exists -U nextcloud_user nextcloud > "$BACKUP_DIR/db_$DATE.sql" 2> >(log)

log "Архивация файлов Nextcloud (корень веб-сервера)..."
docker compose exec -T app tar -czf - -C /var/www html > "$BACKUP_DIR/files_$DATE.tar.gz" 2> >(log)

log "Выключение режима обслуживания..."
docker compose exec -T --user www-data app php occ maintenance:mode --off 2>&1 | log

log "Очистка бэкапов старше 7 дней..."
# Ищет в папке бэкапов файлы, измененные более 7 дней назад, и удаляет их
find "$BACKUP_DIR" -type f \( -name "*.sql" -o -name "*.tar.gz" \) -mtime +7 -delete

log "Бэкап успешно создан в $BACKUP_DIR"

