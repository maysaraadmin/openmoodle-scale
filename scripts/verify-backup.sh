#!/bin/sh
set -eu

ARCHIVE=${1:?Usage: verify-backup.sh <backup.tar.gz>}
NAMESPACE="${VERIFY_NAMESPACE:-moodle-verify}"
DB_POD="${DB_POD:?Set DB_POD to the MariaDB primary pod}"
APP_POD="${APP_POD:?Set APP_POD to a Moodle app pod}"
DB_PASSWORD="${DB_PASSWORD:?Set DB_PASSWORD env var}"
TIMEOUT="${TIMEOUT:-300}"

TARGET_DIR="/tmp/openmoodle-verify-$$"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

echo "Creating verification namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "Extracting backup archive..."
tar xzf "$ARCHIVE" -C "$TARGET_DIR"
BACKUP_DIR=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit)
test -f "$BACKUP_DIR/database.sql"
test -f "$BACKUP_DIR/moodledata.tar.gz"

echo "Restoring database..."
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
  mariadb -u "${DB_USER:-moodle}" -p"${DB_PASSWORD}" "${DB_NAME:-moodle}" \
  < "$BACKUP_DIR/database.sql"

echo "Restoring moodledata..."
kubectl exec -i -n "$NAMESPACE" "$APP_POD" -- \
  tar xzf - -C /var \
  < "$BACKUP_DIR/moodledata.tar.gz"

echo "Running smoke test..."
kubectl get pods -n "$NAMESPACE" -o wide
kubectl get pvc -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"

echo "Verification complete. Clean up with: kubectl delete namespace $NAMESPACE"
rm -rf "$TARGET_DIR"
