#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges to access all Docker volume files."
  echo "Please run with sudo: sudo ./backup_create.sh"
  exit 1
fi

# Read config data from .env
source .env

# Define the path for the backup file
DAY_OF_WEEK=$(date +%A | tr '[:upper:]' '[:lower:]')
BACKUP_FILE="$BACKUP_DIR/$DAY_OF_WEEK.tar.gz.gpg"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Stop all running containers that have been defined in the docker-compose.yml file
echo "Stopping containers..."
docker-compose -f ./docker-compose.yml down


# Create and encrypt the backup
echo "Creating and encrypting backup with GPG (single step)..."
tar -cz -C "$(dirname "$DOCKER_VOLUMES")" \
  --exclude="metube/downloads" \
  --exclude="pihole/pihole/pihole-FTL.db" \
  "$(basename "$DOCKER_VOLUMES")" \
| echo "$BACKUP_PASSWORD" | gpg --batch --yes --passphrase-fd 0 -c > "$BACKUP_FILE"

echo "Encrypted backup: $BACKUP_FILE"

# Set owner and group of the backup file to BACKUP_USER
chown "$BACKUP_USER:$BACKUP_USER" "$BACKUP_FILE"
echo "Set owner and group of $BACKUP_FILE to $BACKUP_USER"
echo "Final size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Start all containers
echo "Starting containers..."
docker-compose -f ./docker-compose.yml up -d
