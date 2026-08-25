#!/bin/sh
set -eu

ARCHIVE=${1:?Usage: restore.sh backup.tar.gz}
TARGET_DIR=${2:-/tmp/openmoodle-restore}
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
tar xzf "$ARCHIVE" -C "$TARGET_DIR"
echo "Backup extracted to $TARGET_DIR"