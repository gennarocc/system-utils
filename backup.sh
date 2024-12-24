#!/bin/bash
MAX_BACKUPS=3
BACKUP_DIR=/hdd/.backup/

echo "[INFO] Starting Backup Script"
echo "[INFO] Mounting Backup Drive..."
if [$(mount UUID=bd25d834-eeb7-45e0-a152-9b226238b9a9 /hdd/.backup) -eq 1]; then
        echo "[ERROR] Backup drive not connected."
        exit
fi
echo "[INFO] Successfuly Mounted Backup Drive"
echo "[INFO] Starting Tar Backup"
START_TIME=$(date +%s)
tar -c -I 'zstd -22 --fast=3 -T0' -f /hdd/.backup/backup-$(date -I).tar.xz --exclude=/hdd/media/tv --exclude=/hdd/media/movies --exclude=/hdd/.torrents --exclude=/hdd/.backup /hdd
TIME_ELAPSED=$(( date +%s - $START_TIME))
if [ $? -eq 0 ]; then
        echo "[INFO] Backup Successful"
        printf '[INFO] Backup duration - %dh:%dm:%ds\n' $((TIME_ELAPSED/3600)) $((TIME_ELAPSED%3600/60 $((TIME_ELAPSED%60))
else
        echo "[ERROR] Tar Backup Failed"
        exit
fi


if (( ls | wc -l > MAX_BACKUPS )); then
        echo "[INFO] Removing oldest backup."
        ls -1t created | tail -n 1 | xargs -d '\n' rm -f
fi

echo "[INFO] Listing Backups"
ls -la /hdd/.backups

echo "[INFO] Backup Script Completed Successfuly"
