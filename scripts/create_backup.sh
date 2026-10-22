#!/bin/bash
set -euo pipefail

# Get the repository root (parent of this script's directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$REPO_DIR/.env"
COMPOSE_FILE="$REPO_DIR/docker-compose.yml"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges to access all Docker volume files."
  echo "Please run with sudo: sudo ./scripts/create_backup.sh"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env not found at $ENV_FILE"
  exit 1
fi

# Read config data from .env
# shellcheck disable=SC1090
source "$ENV_FILE"

# Define the path for the backup file
DAY_OF_WEEK=$(date +%A | tr '[:upper:]' '[:lower:]')
BACKUP_FILE="$BACKUP_DIR/$DAY_OF_WEEK.tar.gz.gpg"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Stop all running containers that have been defined in the docker-compose.yml file
echo "Stopping containers"
docker compose -f "$COMPOSE_FILE" down

# Create and encrypt the backup
echo "Creating and encrypting backup with GPG"
tar -cz -C "$(dirname "$DOCKER_VOLUMES")" \
  --exclude="metube/downloads" \
  --exclude="pihole/pihole/pihole-FTL.db" \
  "$(basename "$DOCKER_VOLUMES")" \
| gpg --batch --yes --passphrase "$BACKUP_PASSWORD" -c > "$BACKUP_FILE"
echo "Encrypted backup: $BACKUP_FILE"

# Set owner and group of the backup file to BACKUP_USER
chown "$BACKUP_USER:$BACKUP_USER" "$BACKUP_FILE"
echo "Set owner and group of $BACKUP_FILE to $BACKUP_USER"
echo "Final size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Start all containers
echo "Starting containers"
docker compose -f "$COMPOSE_FILE" up -d
