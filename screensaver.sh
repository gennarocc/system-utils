#!/bin/bash

# Array with screensaver commands
screensavers=("pipes -f 20 -p 2" "lavat -c cyan -R1 -F @@:::::: -r3", "terminal-rain")

# Seed random generator
RANDOM=$$$(date +%s)

# Select random screensaver
selected_screensaver=${screensavers[$RANDOM % ${#screensavers[@]}]}

# Run the selected screensaver
echo "Running: $selected_screensaver"
eval $selected_screensaver
