#!/bin/bash

# First stop all running containers that have been defined in the docker-compose.yml file
docker-compose -f /home/maxi/dock-n-roll/docker-compose.yml down

# Define the source directory and the backup file name
BACKUP_DIR=~/docker_volumes_backups
DAY_OF_WEEK=$(date +%A | tr '[:upper:]' '[:lower:]')
BACKUP_FILE=$BACKUP_DIR/$DAY_OF_WEEK.zip
SOURCE_DIR=~/docker_volumes
PASSWORD="your_password_here"


# Create a zip backup with a password
zip -r -P "$PASSWORD" "$BACKUP_FILE" "$SOURCE_DIR"
echo "Backup completed: $BACKUP_FILE"

# Start all containers again
docker-compose  -f /home/maxi/dock-n-roll/docker-compose.yml up -d
