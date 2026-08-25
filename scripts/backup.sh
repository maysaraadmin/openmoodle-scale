#!/bin/sh
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backup/openmoodle-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$BACKUP_DIR"
kubectl get all -n "${MOODLE_NAMESPACE:-moodle-prod}" -o yaml > "$BACKUP_DIR/k8s-resources.yaml"
kubectl get configmap -n "${MOODLE_NAMESPACE:-moodle-prod}" -o yaml > "$BACKUP_DIR/configmaps.yaml"
tar czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"
echo "Backup created at ${BACKUP_DIR}.tar.gz"