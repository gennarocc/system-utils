#!/bin/bash
# Automated system update script

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
LOG_FILE="/var/log/system-update.log"

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error_exit "This script must be run as root"
fi

log "System update started"

# Update package lists
if DEBIAN_FRONTEND=noninteractive apt update -y >> "$LOG_FILE" 2>&1; then
    log "Package lists updated successfully"
else
    error_exit "Failed to update package lists"
fi

# Show upgradeable packages
UPGRADEABLE=$(apt list --upgradeable 2>/dev/null | tail -n +2 | sort)
if [[ -n "$UPGRADEABLE" ]]; then
    log "Upgradeable packages: $(echo "$UPGRADEABLE" | wc -l) packages"
else
    echo "No packages to upgrade"
    echo "System is already up to date!"
    exit 0
fi

# Perform upgrade
if DEBIAN_FRONTEND=noninteractive apt -y upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >> "$LOG_FILE" 2>&1; then
    log "Packages upgraded successfully"
else
    error_exit "Failed to upgrade packages"
fi

# Check if reboot is required
if [[ -f /var/run/reboot-required ]]; then
    log "Reboot required after update"
    if [[ -f /var/run/reboot-required.pkgs ]]; then
        cat /var/run/reboot-required.pkgs
    fi
fi

log "System update completed successfully"
