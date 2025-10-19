#!/bin/bash

# Configuration
MAX_BACKUPS=3
BACKUP_DIR="/hdd/.backup/"
SOURCE_DIR="/hdd/"
# Define exclusions as an array (relative to SOURCE_DIR)
EXCLUDE_DIRS=(
    "media/tv/"
    "media/movies/"
    "media/music/.tmp"
    ".torrents/"
    ".backup/"
    ".backup"
)
DATE=$(date -I)
BACKUP_NAME="backup-${DATE}"
LOG_FILE="${BACKUP_DIR}/backup-${DATE}.log"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create log file
mkdir -p "${BACKUP_DIR}"
touch "$LOG_FILE"
log "INFO: Starting Backup Script"

log "INFO: Mounting Backup Drive..."
if ! mountpoint -q "${BACKUP_DIR}"; then
    if ! mount "${BACKUP_DIR}"; then
        log "ERROR: Failed to mount backup drive"
        exit 1
    fi
fi
log "INFO: Successfully Mounted Backup Drive"

# Check available space before backup
AVAILABLE_SPACE=$(df -B1 "${BACKUP_DIR}" | awk 'NR==2 {print $4}')
log "INFO: Available space: $(numfmt --to=iec-i --suffix=B ${AVAILABLE_SPACE})"

# Create snapshot directory
SNAPSHOT_DIR="${BACKUP_DIR}/${BACKUP_NAME}"
LATEST_LINK="${BACKUP_DIR}/latest"

# Check if previous backup exists to enable incremental backup
if [ -d "${LATEST_LINK}" ]; then
    LINK_DEST="--link-dest=${LATEST_LINK}"
    log "INFO: Using incremental backup with reference to ${LATEST_LINK}"
else
    LINK_DEST=""
    log "INFO: No previous backup found, performing full backup"
fi

# Build exclude parameters from the array
EXCLUDE_PARAMS=""
for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_PARAMS="${EXCLUDE_PARAMS} --exclude='${dir}'"
done

# Start rsync backup
log "INFO: Starting rsync Backup"
START_TIME=$(date +%s)

# Create the new backup using rsync with hardlinks for unchanged files
cd "${SOURCE_DIR}" || exit
# Using eval to properly handle the constructed exclude parameters
eval rsync -aAXHv --delete \
    ${EXCLUDE_PARAMS} \
    ${LINK_DEST} \
    . "${SNAPSHOT_DIR}" \
    2>&1 | tee -a "$LOG_FILE"

RSYNC_STATUS=${PIPESTATUS[0]}
TIME_ELAPSED=$(($(date +%s) - START_TIME))

if [ $RSYNC_STATUS -eq 0 ]; then
    log "INFO: Backup Successful"
    printf '[INFO] Backup duration - %dh:%dm:%ds\n' $((TIME_ELAPSED/3600)) $((TIME_ELAPSED%3600/60)) $((TIME_ELAPSED%60)) | tee -a "$LOG_FILE"

    # Update the "latest" symlink to point to this backup
    rm -f "${LATEST_LINK}"
    ln -s "${SNAPSHOT_DIR}" "${LATEST_LINK}"
    log "INFO: Updated latest backup link"

    # Enforce max backups limit
    cd "${BACKUP_DIR}" || exit
    BACKUP_COUNT=$(find . -maxdepth 1 -type d -name "backup-*" | wc -l)
    if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
        NUM_TO_DELETE=$((BACKUP_COUNT - MAX_BACKUPS))
        log "INFO: Too many backups ($BACKUP_COUNT), removing oldest $NUM_TO_DELETE"
        find . -maxdepth 1 -type d -name "backup-*" | sort | head -n $NUM_TO_DELETE | xargs rm -rf
    fi
else
    log "ERROR: rsync Backup Failed with status $RSYNC_STATUS"
    exit 1
fi

log "INFO: Listing Backups"
ls -la "${BACKUP_DIR}" | tee -a "$LOG_FILE"
log "INFO: Backup Script Completed Successfully"
