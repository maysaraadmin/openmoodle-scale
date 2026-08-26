#!/bin/sh
set -eu

mkdir -p /var/moodledata
chown -R www-data:www-data /var/moodledata

wait_for() {
  echo "Waiting for $1 at ${2:-}..."
  until php -r '$driver = getenv("DB_TYPE") ?: "pgsql"; $dsn = $driver . ":host=" . getenv("DB_HOST") . ";dbname=" . getenv("DB_NAME"); new PDO($dsn, getenv("DB_USER"), getenv("DB_PASS"));' 2>/dev/null; do
    echo "$1 not ready, retrying in 2s..."
    sleep 2
  done
  echo "$1 is ready."
}

if [ "${WAIT_FOR_DATABASE:-true}" = "true" ]; then
  if [ -z "${DB_HOST:-}" ] || [ -z "${DB_NAME:-}" ]; then
    echo "DB_HOST or DB_NAME not set; skipping database wait."
  else
    wait_for "database" "$DB_HOST"
  fi
fi

if [ "${WAIT_FOR_REDIS:-true}" = "true" ]; then
  if [ -z "${REDIS_HOST:-}" ]; then
    echo "REDIS_HOST not set; skipping redis wait."
  else
    echo "Waiting for redis at ${REDIS_HOST}:${REDIS_PORT:-6379}..."
    until php -r '$host = getenv("REDIS_HOST") ?: "redis"; $port = getenv("REDIS_PORT") ?: 6379; $pass = getenv("REDIS_PASSWORD"); $conn = @fsockopen($host, $port, $errno, $errstr, 2); if ($conn) { fclose($conn); exit(0); } exit(1);' 2>/dev/null; do
      echo "Redis not ready, retrying in 2s..."
      sleep 2
    done
    echo "Redis is ready."
  fi
fi

exec "$@"
