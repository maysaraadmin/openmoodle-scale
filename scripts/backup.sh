#!/bin/sh
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backup/openmoodle-$(date +%Y%m%d-%H%M%S)}"
NAMESPACE="${MOODLE_NAMESPACE:-moodle-prod}"
DB_POD="${DB_POD:?Set DB_POD to the MariaDB primary pod}"
APP_POD="${APP_POD:?Set APP_POD to a Moodle app pod}"
SECRET_NAME="${SECRET_NAME:?Set SECRET_NAME to the openmoodle secrets name}"
DB_PASSWORD="${DB_PASSWORD:?Set DB_PASSWORD env var}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-minio.minio.svc.cluster.local:9000}"
MINIO_BUCKET="${MINIO_BUCKET:-backups}"

mkdir -p "$BACKUP_DIR"

kubectl get all -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s-resources.yaml"
kubectl get configmap -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/configmaps.yaml"

kubectl exec -n "$NAMESPACE" "$DB_POD" -- \
  sh -c 'mariadb-dump --single-transaction --routines --events \
    -u "${DB_USER:-moodle}" -p"${DB_PASSWORD}" "${DB_NAME:-moodle}"' \
  > "$BACKUP_DIR/database.sql"

kubectl exec -n "$NAMESPACE" "$APP_POD" -- \
  tar czf - -C /var moodledata \
  > "$BACKUP_DIR/moodledata.tar.gz"

tar czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
rm -rf "$BACKUP_DIR"

if command -v mc >/dev/null 2>&1; then
  mc alias set myminio "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" --api s3v4
  mc cp "${BACKUP_DIR}.tar.gz" "myminio/$MINIO_BUCKET/"
  echo "Backup uploaded to MinIO bucket $MINIO_BUCKET"
else
  echo "MinIO client (mc) not found. Backup stored locally at ${BACKUP_DIR}.tar.gz"
fi

echo "Backup created at ${BACKUP_DIR}.tar.gz"
