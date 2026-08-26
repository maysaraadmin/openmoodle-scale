#!/bin/sh
set -euo pipefail

ARCHIVE=${1:?Usage: restore.sh <backup.tar.gz>}
TARGET_DIR=${2:-/tmp/openmoodle-restore-$$}
NAMESPACE="${MOODLE_NAMESPACE:-moodle-prod}"
DB_POD="${DB_POD:?Set DB_POD to the PostgreSQL primary pod}"
APP_POD="${APP_POD:?Set APP_POD to a Moodle app pod}"
DB_PASSWORD="${DB_PASSWORD:?Set DB_PASSWORD env var}"
DB_USER="${DB_USER:-moodle}"
DB_NAME="${DB_NAME:-moodle}"

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
tar xzf "$ARCHIVE" -C "$TARGET_DIR"
BACKUP_DIR=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit)
test -f "$BACKUP_DIR/database.dump"
test -f "$BACKUP_DIR/moodledata.tar.gz"

echo "Creating database $DB_NAME if it does not exist..."
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
  sh -c "PGPASSWORD='$DB_PASSWORD' psql -U '$DB_USER' -tc \"SELECT 1 FROM pg_database WHERE datname='$DB_NAME'\" | grep -q 1 || PGPASSWORD='$DB_PASSWORD' psql -U '$DB_USER' -c 'CREATE DATABASE \"$DB_NAME\";'"

echo "Restoring database..."
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
  sh -c "PGPASSWORD='$DB_PASSWORD' pg_restore -Fc -U '$DB_USER' -d '$DB_NAME' --clean --if-exists" \
  < "$BACKUP_DIR/database.dump"

echo "Restoring moodledata..."
kubectl exec -i -n "$NAMESPACE" "$APP_POD" -- \
  tar xzf - -C /var \
  < "$BACKUP_DIR/moodledata.tar.gz"

echo "Database and Moodledata restored from $ARCHIVE"
rm -rf "$TARGET_DIR"
