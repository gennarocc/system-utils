#!/bin/bash
# Automated system update script

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
LOG_FILE="/var/log/system-update.log"
NOTIFICATION_SCRIPT="/home/pi/system-utils/send-email.sh"

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

# Prepare notification body
NOTIFICATION_BODY="System update completed successfully on $(hostname)\n\n"
NOTIFICATION_BODY+="Updated Packages ($UPGRADE_COUNT):\n"
NOTIFICATION_BODY+="==================================\n"
NOTIFICATION_BODY+="$UPGRADEABLE\n\n"

# Check if reboot is required
if [[ -f /var/run/reboot-required ]]; then
    log "Reboot required after update"
    NOTIFICATION_BODY+="==================================\n"
    NOTIFICATION_BODY+="[[REBOOT REQUIRED]]\n"
    if [[ -f /var/run/reboot-required.pkgs ]]; then
        cat /var/run/reboot-required.pkgs
    fi
fi

# Send Email Notification
if [[ -n "$EMAIL" ]]; then
    if echo "$NOTIFICATION_BODY" | "$NOTIFICATION_SCRIPT" "$EMAIL" " System Update"; then
        log "Email notification sent to $EMAIL"
    else
        log "Warning: Failed to send email notification"
    fi
else
    log "EMAIL env var not set - skipping email notification"
fi 

log "System update completed successfully"
