#!/bin/bash
# Automated system update script

# Configuration
DATE=$(date -I)
LOG_FILE="/home/pi/.local/log/system-updates/update-${DATE}.log"
NOTIFICATION_SCRIPT=/home/pi/system-utils/send-email.sh


# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}


# Error handler
error_exit() {
    echo "Error: $1" >&2
    log "ERROR: $1"
    exit 1
}

### Script Start

touch "$LOG_FILE"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error_exit "This script must be run as root"
fi

log "System update started"

# Update package lists
if DEBIAN_FRONTEND=noninteractive apt-get update -y >> "$LOG_FILE" 2>&1; then
    log "Package lists updated successfully"
else
    error_exit "Failed to update package lists"
fi

# Show upgradeable packages
UPGRADEABLE=$(apt list --upgradeable 2>/dev/null | cut -d/ -f1 | grep -v Listing)
UPGRADE_COUNT=$(echo "$UPGRADEABLE" | wc -l)

# Perform upgrade
if DEBIAN_FRONTEND=noninteractive apt-get -y upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >> "$LOG_FILE" 2>&1; then
    log "Packages upgraded successfully"
else
    error_exit "Failed to upgrade packages"
fi

# Get storage usage information
STORAGE_INFO=$(df -h /hdd /home 2>/dev/null | tail -n +2)
log "Storage information collected"

# Get RAID status for md0
if [[ -e /dev/md0 ]]; then
    RAID_STATUS=$(cat /proc/mdstat | grep -A 3 "md0" 2>/dev/null || echo "md0 array found but status unavailable")
    log "RAID status collected"
else
    RAID_STATUS="md0 array not found"
    log "Warning: md0 RAID array not found"
fi

# Prepare notification body
NOTIFICATION_BODY="System update completed successfully on $(hostname)\n\n"
NOTIFICATION_BODY+="Updated Packages ($UPGRADE_COUNT):\n"
NOTIFICATION_BODY+="==================================\n"
NOTIFICATION_BODY+="$UPGRADEABLE\n\n"
NOTIFICATION_BODY+="Storage Usage:\n"
NOTIFICATION_BODY+="==================================\n"
NOTIFICATION_BODY+="$STORAGE_INFO\n\n"
NOTIFICATION_BODY+="RAID Status (md0):\n"
NOTIFICATION_BODY+="==================================\n"
NOTIFICATION_BODY+="$RAID_STATUS\n\n"

# Send Email Notification
if [[ -n "$EMAIL" ]]; then
    if echo -e "$NOTIFICATION_BODY" | "$NOTIFICATION_SCRIPT" "$EMAIL" "System Update"; then
        log "Email notification sent to $EMAIL"
    else
        log "Warning: Failed to send email notification"
    fi
else
    log "EMAIL env var not set - skipping email notification"
fi 

log "System update completed successfully"
