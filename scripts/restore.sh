#!/usr/bin/env bash
# Restores the lab's data volume from the most recent snapshot (or a
# specific one passed as $1), resetting it to a known clean state.
set -e

BACKUP_DIR="$(dirname "$0")/../backups"

if [ -n "$1" ]; then
  TIMESTAMP="$1"
else
  TIMESTAMP=$(cat "$BACKUP_DIR/latest.txt")
fi

BACKUP_FILE="$BACKUP_DIR/app-data-$TIMESTAMP.tar.gz"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Stopping app so we can safely restore..."
docker compose stop lendwise-app

echo "Restoring from $BACKUP_FILE..."
docker run --rm \
  -v lendwise-lab_app-data:/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/app-data-$TIMESTAMP.tar.gz -C /data"

echo "Restarting app..."
docker compose start lendwise-app

echo "Lab restored to snapshot: $TIMESTAMP"
