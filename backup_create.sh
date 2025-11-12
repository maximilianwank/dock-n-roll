#!/bin/bash

# Read config data from .env
source .env

# Define the path for the backup file
DAY_OF_WEEK=$(date +%A | tr '[:upper:]' '[:lower:]')
BACKUP_FILE=$BACKUP_DIR/$DAY_OF_WEEK.tar.gz

# Stop all running containers that have been defined in the docker-compose.yml file
echo "Stopping containers..."
docker-compose -f ./docker-compose.yml down

# Create a tar.gz backup
echo "Creating backup..."
tar -czf "$BACKUP_FILE" \
  -C "$(dirname "$DOCKER_VOLUMES")" \
  --exclude="metube/downloads" \
  "$(basename "$DOCKER_VOLUMES")"

echo "Backup created: $BACKUP_FILE"
echo "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Start all containers again to minimize downtime
echo "Starting containers..."
docker-compose -f ./docker-compose.yml up -d

# Encrypt with gpg
echo "Encrypting backup with GPG..."
echo "$BACKUP_PASSWORD" | gpg --batch --yes --passphrase-fd 0 -c "$BACKUP_FILE"
rm "$BACKUP_FILE"
BACKUP_FILE="${BACKUP_FILE}.gpg"
echo "Encrypted backup: $BACKUP_FILE"
echo "Final size: $(du -h "$BACKUP_FILE" | cut -f1)"
