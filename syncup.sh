#!/bin/bash

# Configuration
MAX_BACKUPS=5
BACKUP_DIR="/mnt/backup"
SOURCE_DIR="/hdd/"
EXCLUDE_DIRS=(
    "media/tv/"
    "media/movies/"
    "media/music/.tmp"
    "pictures/library/storage/backup/"
    "pictures/library/storage/users/"
    "pictures/library/storage/cache/"
    "pictures/library/database/"
    ".torrents/"
    ".monitoring"
    "games/.database"
)
DATE=$(date -I)
BACKUP_NAME="backup-${DATE}"
LOG_FILE="$HOME/.local/log/backups/backup-${DATE}.log"
NOTIFICATION_SCRIPT=/home/pi/system-utils/send-email.sh
RSYNC_OUTPUT=$(mktemp)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    local exit_code=$?
    if [[ -n "$EMAIL" ]] && [[ -f "$RSYNC_OUTPUT" ]]; then
        "$NOTIFICATION_SCRIPT" "$EMAIL" "Backup Report - ${DATE}" -f "$RSYNC_OUTPUT" \
            && log "INFO: Email notification sent to $EMAIL" \
            || log "Warning: Failed to send email notification"
    fi
    rm -f "$RSYNC_OUTPUT"
    exit "$exit_code"
}
trap cleanup EXIT

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Create log file
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

# Build rsync arguments
RSYNC_ARGS=(-aAXH --delete-after)

for dir in "${EXCLUDE_DIRS[@]}"; do
    RSYNC_ARGS+=(--exclude="$dir")
done

if [ -d "${LATEST_LINK}" ]; then
    RSYNC_ARGS+=(--link-dest="${LATEST_LINK}")
    log "INFO: Using incremental backup with reference to ${LATEST_LINK}"
else
    log "INFO: No previous backup found, performing full backup"
fi

RSYNC_ARGS+=(. "${SNAPSHOT_DIR}")

# Start rsync backup
log "INFO: Starting rsync Backup"
START_TIME=$(date +%s)

cd "${SOURCE_DIR}" || exit 1

if [ -t 1 ]; then
    # Interactive: progress bar on terminal, transfer log to file
    rsync "${RSYNC_ARGS[@]}" --info=progress2,stats2 --log-file="$LOG_FILE" 2>&1
else
    # Cron: all output to log file
    rsync "${RSYNC_ARGS[@]}" --info=stats2 >> "$LOG_FILE" 2>&1
fi

RSYNC_STATUS=$?
TIME_ELAPSED=$(($(date +%s) - START_TIME))
DURATION=$(printf '%dh:%dm:%ds' $((TIME_ELAPSED/3600)) $((TIME_ELAPSED%3600/60)) $((TIME_ELAPSED%60)))

# Create summary file
{
    echo "═══════════════════════════════════════════════════"
    echo "           BACKUP SUMMARY - ${DATE}"
    echo "═══════════════════════════════════════════════════"
    echo ""

    if [ $RSYNC_STATUS -eq 0 ]; then
        echo "✓ Status: SUCCESS"
    else
        echo "✗ Status: FAILED (exit code: $RSYNC_STATUS)"
    fi

    echo "Duration: ${DURATION}"
    echo "Available Space: $(numfmt --to=iec-i --suffix=B ${AVAILABLE_SPACE})"
    echo ""

    # Extract rsync statistics
    echo "─────────────────────────────────────────────────"
    echo "Transfer Statistics:"
    echo "─────────────────────────────────────────────────"
    grep -E "^(Number of files:|Number of created files:|Number of deleted files:|Number of regular files transferred:|Total file size:|Total transferred file size:|Literal data:|Matched data:|File list size:|Total bytes sent:|Total bytes received:)" "$LOG_FILE" | tail -11 | awk -F": " '
    function commafy(n,   s,p,out,i,len) {
      s = sprintf("%.1f", n); split(s, p, "."); s = p[1]; len = length(s); out = ""
      for (i = 1; i <= len; i++) {
        out = out substr(s, i, 1)
        if ((len - i) % 3 == 0 && i < len) out = out ","
      }
      return out "." p[2]
    }
    /^(Total file size|Total transferred file size|Literal data|Matched data|File list size|Total bytes sent|Total bytes received)/ {
      v = $2; gsub(/[^0-9]/, "", v)
      printf "  %s: %s MB\n", $1, commafy(v/1048576); next
    }
    { print "  " $0 }
    ' 
    echo ""

    # Check for errors or warnings in the log
    ERROR_COUNT=$(grep -c "ERROR:" "$LOG_FILE" 2>/dev/null || echo "0")
    WARNING_COUNT=$(grep -c "Warning:" "$LOG_FILE" 2>/dev/null || echo "0")

    ERROR_COUNT=$(echo "$ERROR_COUNT" | tr -d '[:space:]')
    WARNING_COUNT=$(echo "$WARNING_COUNT" | tr -d '[:space:]')

    ERROR_COUNT=${ERROR_COUNT:-0}
    WARNING_COUNT=${WARNING_COUNT:-0}

    if [ "$ERROR_COUNT" -gt 0 ] || [ "$WARNING_COUNT" -gt 0 ]; then
        echo "─────────────────────────────────────────────────"
        echo "Issues Found:"
        echo "─────────────────────────────────────────────────"
        [ "$ERROR_COUNT" -gt 0 ] && echo "  Errors: $ERROR_COUNT"
        [ "$WARNING_COUNT" -gt 0 ] && echo "  Warnings: $WARNING_COUNT"
        echo ""
        echo "Recent errors/warnings:"
        grep -E "ERROR:|Warning:" "$LOG_FILE" | tail -5 | sed 's/^/  /'
        echo ""
    fi

    # List current backups
    cd "${BACKUP_DIR}" || exit 1
    BACKUP_COUNT=$(find . -maxdepth 1 -type d -name "backup-*" | wc -l)
    echo "─────────────────────────────────────────────────"
    echo "Current Backups: ${BACKUP_COUNT}/${MAX_BACKUPS}"
    echo "─────────────────────────────────────────────────"
    find . -maxdepth 1 -type d -name "backup-*" -printf "  %TY-%Tm-%Td %TH:%TM - %f\n" | sort -r
    echo ""
    echo "Full log available at: ${LOG_FILE}"
    echo "═══════════════════════════════════════════════════"
} > "$RSYNC_OUTPUT"

# Display summary in log
cat "$RSYNC_OUTPUT" | tee -a "$LOG_FILE"

if [ $RSYNC_STATUS -eq 0 ]; then
    log "INFO: Backup Successful"

    # Update the "latest" symlink to point to this backup
    rm -f "${LATEST_LINK}"
    ln -s "${SNAPSHOT_DIR}" "${LATEST_LINK}"
    log "INFO: Updated latest backup link"

    # Enforce max backups limit
    cd "${BACKUP_DIR}" || exit 1
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

