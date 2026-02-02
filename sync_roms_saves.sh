#!/bin/bash

# Steam Deck ROM and Save Sync Script
# This script syncs ROMs from network share to Steam Deck
# and backs up saves from Steam Deck to network share

# Configuration
NETWORK_HOST="pi"
REMOTE_ROMS_PATH="/hdd/games/roms/"
LOCAL_ROMS_PATH="$HOME/Emulation/roms/"
LOCAL_SAVES_PATH="$HOME/Emulation/saves/"
REMOTE_SAVES_PATH="/hdd/games/saves/"

echo "=== Steam Deck ROM & Save Sync ==="
echo ""

# Sync ROMs from network share to Steam Deck (download new ROMs)
echo "Syncing ROMs from network share to Steam Deck..."
rsync -avh --progress \
    --exclude='.*' \
    --exclude='ps3/' \
    "$NETWORK_HOST:$REMOTE_ROMS_PATH" \
    "$LOCAL_ROMS_PATH"

if [ $? -eq 0 ]; then
    echo "ROMs synced successfully"
else
    echo "Error syncing ROMs"
fi
echo ""

# Sync saves from Steam Deck to network share (backup saves)
echo "Backing up saves to network share..."
if [ -d "$LOCAL_SAVES_PATH" ]; then
    rsync -avh --progress \
        --exclude='.*' \
        "$LOCAL_SAVES_PATH" \
        "$NETWORK_HOST:$REMOTE_SAVES_PATH"
    
    if [ $? -eq 0 ]; then
        echo "Saves backed up successfully"
    else
        echo "Error backing up saves"
    fi
else
    echo "Local saves directory not found: $LOCAL_SAVES_PATH"
fi
echo ""

echo "=== Sync Complete ==="
