#!/bin/bash

# Read config data from .env
source .env

# Define the path for the backup file
DAY_OF_WEEK=$(date +%A | tr '[:upper:]' '[:lower:]')
BACKUP_FILE=$BACKUP_DIR/$DAY_OF_WEEK.zip

# Stop all running containers that have been defined in the docker-compose.yml file
echo "Stopping containers..."
docker-compose -f ./docker-compose.yml down

# Create a zip backup with a password
echo "Creating backup..."
zip -r -P "$BACKUP_PASSWORD" "$BACKUP_FILE" "$DOCKER_VOLUMES"

# Start all containers again
echo "Starting containers..."
docker-compose  -f ./docker-compose.yml up -d
