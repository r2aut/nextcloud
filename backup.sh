# Путь к папке проекта, где лежит ваш docker-compose.yml
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/opt/nextcloud/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Создаем папку для бэкапов, если её еще нет
mkdir -p "$BACKUP_DIR"

# Переходим в папку проекта, чтобы команды docker compose работали корректно
cd "$PROJECT_DIR"

echo "1. Включение режима обслуживания..."
docker compose exec -T --user www-data app php occ maintenance:mode --on

echo "2. Дамп базы данных PostgreSQL..."
# ИСПРАВЛЕНО: флаг -T вместо -t, имя сервиса db, имя пользователя nextcloud_user
docker compose exec -T db pg_dump -U nextcloud_user nextcloud > "$BACKUP_DIR/db_$DATE.sql"

echo "3. Архивация файлов Nextcloud (корень веб-сервера)..."
# ИСПРАВЛЕНО: используется правильное имя сервиса app и флаг -T
docker compose exec -T app tar -czf - -C /var/www html > "$BACKUP_DIR/files_$DATE.tar.gz"

echo "4. Выключение режима обслуживания..."
# ИСПРАВЛЕНО: имя сервиса приведено к единому стандарту app
docker compose exec -T --user www-data app php occ maintenance:mode --off

echo "5. Очистка бэкапов старше 7 дней..."
# Ищет в папке бэкапов файлы, измененные более 7 дней назад, и удаляет их
find "$BACKUP_DIR" -type f \( -name "*.sql" -o -name "*.tar.gz" \) -mtime +7 -delete

echo "Бэкап успешно создан в $BACKUP_DIR"
