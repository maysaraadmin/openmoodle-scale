#!/bin/sh
set -eu

mkdir -p /var/moodledata

if [ "${WAIT_FOR_DATABASE:-true}" = "true" ]; then
  until php -r 'new PDO("mysql:host=" . getenv("DB_HOST") . ";dbname=" . getenv("DB_NAME"), getenv("DB_USER"), getenv("DB_PASS"));' 2>/dev/null; do
    echo "Waiting for database at ${DB_HOST}..."
    sleep 2
  done
fi

exec "$@"