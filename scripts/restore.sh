#!/bin/sh
set -eu

ARCHIVE=${1:?Usage: restore.sh backup.tar.gz}
TARGET_DIR=${2:-/tmp/openmoodle-restore}
NAMESPACE="${MOODLE_NAMESPACE:-moodle-prod}"
DB_POD="${DB_POD:?Set DB_POD to the MariaDB primary pod}"
APP_POD="${APP_POD:?Set APP_POD to a Moodle app pod}"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
tar xzf "$ARCHIVE" -C "$TARGET_DIR"
BACKUP_DIR=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit)
test -f "$BACKUP_DIR/database.sql"
test -f "$BACKUP_DIR/moodledata.tar.gz"
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- mariadb \
	-u "${DB_USER:-moodle}" -p"${DB_PASSWORD:?Set DB_PASSWORD}" "${DB_NAME:-moodle}" < "$BACKUP_DIR/database.sql"
kubectl exec -i -n "$NAMESPACE" "$APP_POD" -- tar xzf - -C /var < "$BACKUP_DIR/moodledata.tar.gz"
echo "Database and Moodledata restored from $ARCHIVE"