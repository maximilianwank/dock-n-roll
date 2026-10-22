#!/bin/bash
#
# migrate_volumes.sh
#
# Migrates all Docker volumes to an external SSD and moves the backup
# directory there as well.
#
# Target layout on the SSD:
#   <TARGET_BASE>/docker_volumes            <- live Docker volumes
#   <TARGET_BASE>/docker_volumes_backups    <- encrypted backups
#
# The script:
#   1. Asks for the repository directory and the SSD target directory
#   2. Runs pre-flight checks (root, mount, filesystem, free space)
#   3. Stops all containers
#   4. Copies the volumes with rsync (preserving ownership/permissions)
#   5. Verifies the copy
#   6. Creates the backup directory on the SSD
#   7. Updates DOCKER_VOLUMES and BACKUP_DIR in .env (with a .env.bak)
#   8. Restarts the containers
#
# Usage:
#   sudo ./scripts/migrate_volumes.sh            # perform the migration
#   sudo ./scripts/migrate_volumes.sh --dry-run  # only show what would happen
#
# All paths are requested interactively. To run non-interactively, set the
# REPO_DIR and TARGET_BASE environment variables instead:
#   sudo REPO_DIR=/srv/dock-n-roll TARGET_BASE=/mnt/ssd ./scripts/migrate_volumes.sh
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# All paths are requested interactively (see "0. Gather paths"). They may be
# pre-set via environment variables for non-interactive runs.
REPO_DIR="${REPO_DIR:-}"
TARGET_BASE="${TARGET_BASE:-}"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[FAIL]\033[0m  $*" >&2; }

run() {
  if $DRY_RUN; then
    echo "  (dry-run) $*"
  else
    "$@"
  fi
}

# Prompt for a path, using the value from the environment if already set.
# Usage: ask_path <variable-name> <prompt-text>
ask_path() {
  local var_name="$1" prompt_text="$2" current answer
  current="${!var_name:-}"

  if [[ -n "$current" ]]; then
    info "$prompt_text: $current (from environment)"
    return 0
  fi

  while true; do
    if ! read -r -p "$prompt_text: " answer; then
      error "No input available. Set the corresponding environment variable for non-interactive runs."
      exit 1
    fi
    if [[ -z "$answer" ]]; then
      warn "A value is required."
      continue
    fi
    printf -v "$var_name" '%s' "$answer"
    return 0
  done
}

# ---------------------------------------------------------------------------
# 0. Gather paths
# ---------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
  error "This script must be run as root (needed to preserve file ownership)."
  error "Please run: sudo ./scripts/migrate_volumes.sh"
  exit 1
fi

info "Please provide the required paths."

ask_path REPO_DIR "Repository directory (contains docker-compose.yml and .env)"
ask_path TARGET_BASE "Target directory on the SSD (e.g. /mnt/ext_disk)"

# Normalize (strip trailing slashes)
REPO_DIR="${REPO_DIR%/}"
TARGET_BASE="${TARGET_BASE%/}"

# Derived paths
ENV_FILE="$REPO_DIR/.env"
COMPOSE_FILE="$REPO_DIR/docker-compose.yml"
TARGET_VOLUMES="$TARGET_BASE/docker_volumes"
TARGET_BACKUPS="$TARGET_BASE/docker_volumes_backups"

# ---------------------------------------------------------------------------
# 1. Pre-flight checks
# ---------------------------------------------------------------------------
info "Running pre-flight checks..."

if [[ ! -f "$ENV_FILE" ]]; then
  error ".env not found at $ENV_FILE"
  exit 1
fi

# Load current settings
# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${DOCKER_VOLUMES:-}" ]]; then
  error "DOCKER_VOLUMES is not set in $ENV_FILE"
  exit 1
fi

SOURCE_VOLUMES="$DOCKER_VOLUMES"

if [[ ! -d "$SOURCE_VOLUMES" ]]; then
  error "Source volume directory does not exist: $SOURCE_VOLUMES"
  exit 1
fi

# Make sure the SSD is actually mounted
if ! mountpoint -q "$TARGET_BASE"; then
  error "$TARGET_BASE is not a mountpoint. Is the SSD mounted?"
  exit 1
fi

# Ownership cannot be preserved on exFAT/NTFS
FS_TYPE="$(df -T "$TARGET_BASE" | awk 'NR==2 {print $2}')"
case "$FS_TYPE" in
  ext4|ext3|ext2|btrfs|xfs|zfs)
    ok "Target filesystem: $FS_TYPE"
    ;;
  *)
    error "Target filesystem '$FS_TYPE' does not support Linux ownership/permissions."
    error "Docker volumes require a Linux filesystem (ext4/btrfs/xfs). Aborting."
    exit 1
    ;;
esac

# Free space check
SRC_SIZE_KB="$(du -sk "$SOURCE_VOLUMES" | cut -f1)"
AVAIL_KB="$(df -Pk "$TARGET_BASE" | awk 'NR==2 {print $4}')"
info "Source size: $((SRC_SIZE_KB / 1024)) MB | Available on target: $((AVAIL_KB / 1024)) MB"
if (( AVAIL_KB < SRC_SIZE_KB )); then
  error "Not enough free space on $TARGET_BASE."
  exit 1
fi

if [[ "$SOURCE_VOLUMES" == "$TARGET_VOLUMES" ]]; then
  warn "DOCKER_VOLUMES already points to $TARGET_VOLUMES. Nothing to migrate."
  exit 0
fi

ok "Pre-flight checks passed."

# ---------------------------------------------------------------------------
# 2. Stop containers
# ---------------------------------------------------------------------------
info "Stopping containers..."
run docker compose -f "$COMPOSE_FILE" down
ok "Containers stopped."

# ---------------------------------------------------------------------------
# 3. Copy volumes (preserve ownership, permissions, ACLs, xattrs)
# ---------------------------------------------------------------------------
info "Copying volumes: $SOURCE_VOLUMES -> $TARGET_VOLUMES"
run mkdir -p "$TARGET_VOLUMES"
run rsync -aHAX --info=progress2 \
  "$SOURCE_VOLUMES/" \
  "$TARGET_VOLUMES/"
ok "Copy finished."

# ---------------------------------------------------------------------------
# 4. Verify the copy
# ---------------------------------------------------------------------------
info "Verifying copy (dry-run diff)..."
if $DRY_RUN; then
  echo "  (dry-run) skipping verification"
else
  DIFF_OUTPUT="$(rsync -aHAXn --delete "$SOURCE_VOLUMES/" "$TARGET_VOLUMES/")"
  if [[ -n "$DIFF_OUTPUT" ]]; then
    error "Verification found differences between source and target:"
    echo "$DIFF_OUTPUT"
    error "Aborting before changing .env. Source data is untouched."
    exit 1
  fi
  ok "Verification passed: target is identical to source."
fi

# ---------------------------------------------------------------------------
# 5. Create the backup directory on the SSD
# ---------------------------------------------------------------------------
info "Creating backup directory: $TARGET_BACKUPS"
run mkdir -p "$TARGET_BACKUPS"
if [[ -n "${BACKUP_USER:-}" ]]; then
  run chown "$BACKUP_USER:$BACKUP_USER" "$TARGET_BACKUPS"
  ok "Backup directory owned by $BACKUP_USER."
fi

# ---------------------------------------------------------------------------
# 6. Update .env
# ---------------------------------------------------------------------------
info "Updating $ENV_FILE ..."
if $DRY_RUN; then
  echo "  (dry-run) would set DOCKER_VOLUMES=$TARGET_VOLUMES"
  echo "  (dry-run) would set BACKUP_DIR=$TARGET_BACKUPS"
else
  cp -a "$ENV_FILE" "$ENV_FILE.bak"
  sed -i \
    -e "s|^DOCKER_VOLUMES=.*|DOCKER_VOLUMES=$TARGET_VOLUMES|" \
    -e "s|^BACKUP_DIR=.*|BACKUP_DIR=$TARGET_BACKUPS|" \
    "$ENV_FILE"
  ok "Updated .env (backup saved as .env.bak)."
  grep -E '^(DOCKER_VOLUMES|BACKUP_DIR)=' "$ENV_FILE" || true
fi

# ---------------------------------------------------------------------------
# 7. Restart containers
# ---------------------------------------------------------------------------
info "Starting containers..."
run docker compose -f "$COMPOSE_FILE" up -d
ok "Containers started."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
ok "Migration complete!"
echo
echo "Next steps:"
echo "  1. Verify all services are running:  docker compose ps"
echo "  2. Check logs for permission errors: docker compose logs --tail=50 postgres odoo"
echo "  3. Test each service in the browser (ports 314-320)."
echo "  4. Once verified, remove the old data:"
echo "       sudo rm -rf \"$SOURCE_VOLUMES\""
echo
echo "Rollback if needed:"
echo "  - Restore .env:  cp \"$ENV_FILE.bak\" \"$ENV_FILE\""
echo "  - Restart:       docker compose -f \"$COMPOSE_FILE\" up -d"
