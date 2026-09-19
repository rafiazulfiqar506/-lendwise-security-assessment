#!/usr/bin/env bash
# Takes a snapshot of the lab's data volume so it can be restored later
# to a clean state (required deliverable: "snapshot can revert the
# environment to a clean state").
set -e

BACKUP_DIR="$(dirname "$0")/../backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/app-data-$TIMESTAMP.tar.gz"

echo "Snapshotting lendwise-app data volume..."

docker run --rm \
  -v lendwise-lab_app-data:/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine \
  tar czf "/backup/app-data-$TIMESTAMP.tar.gz" -C /data .

echo "Snapshot saved to $BACKUP_FILE"
echo "$TIMESTAMP" > "$BACKUP_DIR/latest.txt"
