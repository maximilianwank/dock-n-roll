#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_RESTORE_PATH="$SCRIPT_DIR/docker_volumes"

# Function to display usage
usage() {
  echo "Usage: $0 <backup_file>"
  echo ""
  echo "Examples:"
  echo "  $0 /path/to/monday.tar.gz.gpg"
  echo "  $0 monday.tar.gz.gpg"
  echo ""
  echo "This script decrypts and extracts an encrypted backup archive."
  exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
  usage
fi

BACKUP_FILE=$1

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' not found!"
  exit 1
fi

# Get the restore destination
read -p "Enter the full path where volumes should be restored [default: $DEFAULT_RESTORE_PATH]: " RESTORE_PATH

# Use default if empty
if [ -z "$RESTORE_PATH" ]; then
  RESTORE_PATH="$DEFAULT_RESTORE_PATH"
  echo "Using default restore path: $RESTORE_PATH"
fi

# Confirm before proceeding
echo ""
echo "WARNING: This will restore the backup to: $RESTORE_PATH"
echo "Existing data at this location may be overwritten!"
read -p "Are you sure you want to continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
  echo "Restore cancelled."
  exit 0
fi

echo ""

# Handle GPG encrypted files
if [[ "$BACKUP_FILE" == *.gpg ]]; then
  read -sp "Enter backup password: " BACKUP_PASSWORD
  echo ""
  
  echo "Decrypting backup..."
  TEMP_FILE="${BACKUP_FILE%.gpg}"
  echo "$BACKUP_PASSWORD" | gpg --batch --yes --passphrase-fd 0 -d "$BACKUP_FILE" > "$TEMP_FILE"
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to decrypt backup. Check your password."
    exit 1
  fi
  
  BACKUP_FILE="$TEMP_FILE"
  CLEANUP_TEMP=true
fi

# Restore full backup
echo "Extracting backup to $RESTORE_PATH..."
tar -xzf "$BACKUP_FILE" -C "$(dirname "$RESTORE_PATH")"

if [ $? -eq 0 ]; then
  echo "Backup extracted successfully to $RESTORE_PATH!"
else
  echo "Error: Failed to extract backup"
  [ "$CLEANUP_TEMP" = true ] && rm -f "$BACKUP_FILE"
  exit 1
fi

# Cleanup temp file if decrypted
if [ "$CLEANUP_TEMP" = true ]; then
  rm -f "$BACKUP_FILE"
fi

echo ""
echo "Restore complete!"
