#!/bin/sh
set -euo pipefail

ARCHIVE=${1:?Usage: verify-backup.sh <backup.tar.gz>}
NAMESPACE="${MOODLE_NAMESPACE:-moodle-prod}"
DB_POD="${DB_POD:?Set DB_POD to the PostgreSQL primary pod}"
APP_POD="${APP_POD:?Set APP_POD to a Moodle app pod}"
DB_PASSWORD="${DB_PASSWORD:?Set DB_PASSWORD env var}"
DB_USER="${DB_USER:-moodle}"
DB_NAME="${DB_NAME:-moodle}"
VERIFY_DB="${VERIFY_DB:-${DB_NAME}_verify}"
TIMEOUT="${TIMEOUT:-300}"

TARGET_DIR="/tmp/openmoodle-verify-$$"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

echo "Extracting backup archive..."
tar xzf "$ARCHIVE" -C "$TARGET_DIR"
BACKUP_DIR=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit)
test -f "$BACKUP_DIR/database.dump"
test -f "$BACKUP_DIR/moodledata.tar.gz"

echo "Creating temporary verification database $VERIFY_DB..."
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
  sh -c "PGPASSWORD='$DB_PASSWORD' psql -U '$DB_USER' -c 'DROP DATABASE IF EXISTS \"$VERIFY_DB\";' ; PGPASSWORD='$DB_PASSWORD' psql -U '$DB_USER' -c 'CREATE DATABASE \"$VERIFY_DB\";'"

echo "Restoring database into $VERIFY_DB (non-destructive)..."
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
  sh -c "PGPASSWORD='$DB_PASSWORD' pg_restore -Fc -U '$DB_USER' -d '$VERIFY_DB' --clean --if-exists" \
  < "$BACKUP_DIR/database.dump"

echo "Validating restored schema..."
TABLE_COUNT=$(kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
  sh -c "PGPASSWORD='$DB_PASSWORD' psql -U '$DB_USER' -d '$VERIFY_DB' -t -A -c \"SELECT count(*) FROM pg_tables WHERE schemaname='public';\"" \
  | tr -d '\r')
if [ "${TABLE_COUNT:-0}" -eq 0 ]; then
  echo "ERROR: restored database contains no tables."
  kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
    sh -c "PGPASSWORD='$DB_PASSWORD' psql -U '$DB_USER' -c 'DROP DATABASE IF EXISTS \"$VERIFY_DB\";'"
  rm -rf "$TARGET_DIR"
  exit 1
fi
echo "Restored database has $TABLE_COUNT tables."

echo "Validating moodledata archive..."
DATA_FILES=$(tar tzf "$BACKUP_DIR/moodledata.tar.gz" | wc -l)
if [ "${DATA_FILES:-0}" -eq 0 ]; then
  echo "ERROR: moodledata archive is empty."
  kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
    sh -c "PGPASSWORD='$DB_PASSWORD' psql -U '$DB_USER' -c 'DROP DATABASE IF EXISTS \"$VERIFY_DB\";'"
  rm -rf "$TARGET_DIR"
  exit 1
fi
echo "Moodledata archive contains $DATA_FILES entries."

echo "Cleaning up verification database..."
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
  sh -c "PGPASSWORD='$DB_PASSWORD' psql -U '$DB_USER' -c 'DROP DATABASE IF EXISTS \"$VERIFY_DB\";'"

echo "Verification complete: backup $ARCHIVE is valid."
rm -rf "$TARGET_DIR"
