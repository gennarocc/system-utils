#!/bin/bash
MAX_BACKUPS=3
BACKUP_DIR=/hdd/.backup/
BACKUP_NAME="backup-$(date -I)"

echo "[INFO] Starting Backup Script"
echo "[INFO] Mounting Backup Drive..."

if ! mount UUID=bd25d834-eeb7-45e0-a152-9b226238b9a9 ${BACKUP_DIR}; then
    echo "[ERROR] Backup drive not connected."
    exit 1
fi


echo "[INFO] Successfully Mounted Backup Drive"

# --- Secrets ----------------------------------------------------------------
# The homelab repo lives on the SD card, not /hdd, so the gitignored plaintext
# secret.yaml files are NOT covered by the tar below.
# Restore: extract into the repo, run ./reseal, commit the sealed-secret.yamls.
HOMELAB_REPO=${HOMELAB_REPO:-/home/pi/homelab}

echo "[INFO] Backing up plaintext secret.yaml files"
SECRET_OUT="${BACKUP_DIR}/secrets-$(date -I).tar.gz"
if (cd "${HOMELAB_REPO}" && find apps -name secret.yaml -print0 | tar --null -T - -czf -) > "${SECRET_OUT}"; then
    chmod 600 "${SECRET_OUT}"
    echo "[INFO] Secrets backed up to ${SECRET_OUT}"
    ls -1t "${BACKUP_DIR}"/secrets-*.tar.gz 2>/dev/null | tail -n +7 | xargs -r rm -f
else
    echo "[ERROR] Secret backup failed"
    rm -f "${SECRET_OUT}"
fi

# Check available space before backup
AVAILABLE_SPACE=$(df -B1 ${BACKUP_DIR} | awk 'NR==2 {print $4}')
echo "[INFO] Available space: $(numfmt --to=iec-i --suffix=B ${AVAILABLE_SPACE})"

# Estimate backup size (optional)
ESTIMATE_SIZE=$(du -sb /hdd --exclude=/hdd/media/tv --exclude=/hdd/media/movies --exclude=/hdd/.torrents --exclude=/hdd/.backup | cut -f1)
ESTIMATE_SIZE=$((ESTIMATE_SIZE / 3)) # Rough compression estimate
echo "[INFO] Estimated backup size: $(numfmt --to=iec-i --suffix=B ${ESTIMATE_SIZE})"

# Remove old backups if needed
cd ${BACKUP_DIR}
if [ $AVAILABLE_SPACE -lt $ESTIMATE_SIZE ]; then
    echo "[INFO] Insufficient space for backup, removing oldest backup"
    OLDEST_BACKUP=$(ls -1t *.tar.zst 2>/dev/null | tail -n 1)
    if [ -n "$OLDEST_BACKUP" ]; then
        echo "[INFO] Removing ${OLDEST_BACKUP}"
        rm -f "${OLDEST_BACKUP}"
        # Recalculate available space
        AVAILABLE_SPACE=$(df -B1 ${BACKUP_DIR} | awk 'NR==2 {print $4}')
        echo "[INFO] Available space after removal: $(numfmt --to=iec-i --suffix=B ${AVAILABLE_SPACE})"
    fi
fi

echo "[INFO] Starting Tar Backup"
START_TIME=$(date +%s)
tar -c -I'zstd -3 -T0' -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.zst" --exclude=/hdd/media/tv --exclude=/hdd/media/movies --exclude=/hdd/.torrents --exclude=/hdd/.backup /hdd

TIME_ELAPSED=$(($(date +%s) - START_TIME))
if [ $? -eq 0 ]; then
    echo "[INFO] Backup Successful"
    printf '[INFO] Backup duration - %dh:%dm:%ds\n' $((TIME_ELAPSED/3600)) $((TIME_ELAPSED%3600/60)) $((TIME_ELAPSED%60))

    # Enforce max backups limit
    cd ${BACKUP_DIR}
    BACKUP_COUNT=$(ls -1 *.tar.zst 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
        NUM_TO_DELETE=$((BACKUP_COUNT - MAX_BACKUPS))
        echo "[INFO] Too many backups ($BACKUP_COUNT), removing oldest $NUM_TO_DELETE"
        ls -1t *.tar.zst | tail -n $NUM_TO_DELETE | xargs -d '\n' rm -f
    fi
else
    echo "[ERROR] Tar Backup Failed"
    exit 1
fi

echo "[INFO] Listing Backups"
ls -la ${BACKUP_DIR}
echo "[INFO] Backup Script Completed Successfully"
