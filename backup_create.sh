#!/bin/bash

# Read config data from .env
source ./.env

# Define the path for the backup file
DAY_OF_WEEK=$(date +%A | tr '[:upper:]' '[:lower:]')
BACKUP_FILE=$BACKUP_DIR/$DAY_OF_WEEK.zip

# Stop all running containers that have been defined in the docker-compose.yml file
docker-compose -f ./docker-compose.yml down

# Create a zip backup with a password
zip -r -P "$PASSWORD_BACKUP" "$BACKUP_FILE" "$DOCKER_VOLUMES"
echo "Backup completed: $BACKUP_FILE"

# Start all containers again
docker-compose  -f ./docker-compose.yml up -d
