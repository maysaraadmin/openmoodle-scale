#!/bin/sh
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backup/openmoodle-$(date +%Y%m%d-%H%M%S)}"
NAMESPACE="${MOODLE_NAMESPACE:-moodle-prod}"
DB_POD="${DB_POD:?Set DB_POD to the PostgreSQL primary pod}"
APP_POD="${APP_POD:?Set APP_POD to a Moodle app pod}"
SECRET_NAME="${SECRET_NAME:-}"
DB_PASSWORD="${DB_PASSWORD:?Set DB_PASSWORD env var}"
DB_USER="${DB_USER:-moodle}"
DB_NAME="${DB_NAME:-moodle}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-minio.minio.svc.cluster.local:9000}"
MINIO_BUCKET="${MINIO_BUCKET:-backups}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-}"
MAINTENANCE_MODE="${MAINTENANCE_MODE:-false}"

enable_maintenance() {
  if [ "$MAINTENANCE_MODE" = "true" ]; then
    echo "Enabling Moodle maintenance mode..."
    kubectl exec -n "$NAMESPACE" "$APP_POD" -- --request-timeout=300s \
      php /var/www/html/admin/cli/maintenance.php --enable >/dev/null 2>&1 || true
  fi
}

disable_maintenance() {
  if [ "$MAINTENANCE_MODE" = "true" ]; then
    echo "Disabling Moodle maintenance mode..."
    kubectl exec -n "$NAMESPACE" "$APP_POD" -- --request-timeout=300s \
      php /var/www/html/admin/cli/maintenance.php --disable >/dev/null 2>&1 || true
  fi
}

trap disable_maintenance EXIT

mkdir -p "$BACKUP_DIR"

enable_maintenance

kubectl get pods,services,deployments,statefulsets,configmaps,secrets -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s-resources.yaml" --request-timeout=300s
kubectl get configmap -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/configmaps.yaml"

kubectl exec -n "$NAMESPACE" "$DB_POD" -- --request-timeout=300s \
  sh -c "PGPASSWORD='$DB_PASSWORD' pg_dump -U '$DB_USER' -d '$DB_NAME' -Fc -b" \
  > "$BACKUP_DIR/database.dump"

kubectl exec -n "$NAMESPACE" "$APP_POD" -- --request-timeout=300s \
  tar czf - -C /var moodledata \
  > "$BACKUP_DIR/moodledata.tar.gz"

disable_maintenance

tar czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
rm -rf "$BACKUP_DIR"

if command -v mc >/dev/null 2>&1; then
  if [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
    echo "MinIO client (mc) found but MINIO_ACCESS_KEY/MINIO_SECRET_KEY are not set. Backup stored locally at ${BACKUP_DIR}.tar.gz"
  else
    mc alias set myminio "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" --api s3v4
    mc cp "${BACKUP_DIR}.tar.gz" "myminio/$MINIO_BUCKET/"
    echo "Backup uploaded to MinIO bucket $MINIO_BUCKET"
  fi
else
  echo "MinIO client (mc) not found. Backup stored locally at ${BACKUP_DIR}.tar.gz"
fi

echo "Backup created at ${BACKUP_DIR}.tar.gz"
