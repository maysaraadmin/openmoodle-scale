#!/bin/sh
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backup/openmoodle-$(date +%Y%m%d-%H%M%S)}"
NAMESPACE="${MOODLE_NAMESPACE:-moodle-prod}"
DB_POD="${DB_POD:?Set DB_POD to the MariaDB primary pod}"
APP_POD="${APP_POD:?Set APP_POD to a Moodle app pod}"
mkdir -p "$BACKUP_DIR"
kubectl get all -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s-resources.yaml"
kubectl get configmap -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/configmaps.yaml"
kubectl exec -n "$NAMESPACE" "$DB_POD" -- mariadb-dump --single-transaction --routines --events \
	-u "${DB_USER:-moodle}" -p"${DB_PASSWORD:?Set DB_PASSWORD}" "${DB_NAME:-moodle}" > "$BACKUP_DIR/database.sql"
kubectl exec -n "$NAMESPACE" "$APP_POD" -- tar czf - -C /var moodledata > "$BACKUP_DIR/moodledata.tar.gz"
kubectl get secret -n "$NAMESPACE" "${SECRET_NAME:?Set SECRET_NAME}" -o yaml > "$BACKUP_DIR/secret.yaml"
tar czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"
echo "Backup created at ${BACKUP_DIR}.tar.gz"