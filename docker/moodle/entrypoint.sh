#!/bin/sh
set -eu

mkdir -p /var/moodledata

if [ "${WAIT_FOR_DATABASE:-true}" = "true" ]; then
  if [ -z "${DB_HOST:-}" ] || [ -z "${DB_NAME:-}" ]; then
    echo "DB_HOST or DB_NAME not set; skipping database wait."
  else
    echo "Waiting for database at ${DB_HOST}..."
    until php -r 'new PDO("mysql:host=" . getenv("DB_HOST") . ";dbname=" . getenv("DB_NAME"), getenv("DB_USER"), getenv("DB_PASS"));' 2>/dev/null; do
      echo "Database not ready, retrying in 2s..."
      sleep 2
    done
    echo "Database is ready."
  fi
fi

exec "$@"
