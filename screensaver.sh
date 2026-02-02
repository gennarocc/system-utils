#!/bin/bash

screensavers=("pipes -f 30 -p 2 -r 2500" "lavat -c cyan -R1 -F @@:::::: -r3" "mystify-term -s")
screensaver_pid=""

get_weather() {
    # Get weather data for Raleigh
    local weather=$(curl -s "wttr.in/Raleigh?format=%C")
    echo "$weather"
}

select_screensaver() {
    local weather=$(get_weather)
    if echo "$weather" | grep -iE "thunder|storm" > /dev/null; then
        echo "terminal-rain -t"
    elif echo "$weather" | grep -iE "rain|drizzle|shower" > /dev/null; then
        echo "terminal-rain"
    else
        # Pick random screensaver from array
        echo "${screensavers[$RANDOM % ${#screensavers[@]}]}"
    fi
}

cleanup() {
    echo "Cleaning up..."
    if [ -n "$screensaver_pid" ]; then
        kill $screensaver_pid 2>/dev/null
        wait $screensaver_pid 2>/dev/null
    fi
    exit 0
}

# Trap SIGINT (Ctrl+C) and SIGTERM
trap cleanup SIGINT SIGTERM

while true; do
    selected_screensaver=$(select_screensaver)
    (exec $selected_screensaver < /dev/tty) &
    screensaver_pid=$!
    
    # Check weather every 3 hours
    sleep 10800
    #sleep 10
    
    kill $screensaver_pid 2>/dev/null
    wait $screensaver_pid 2>/dev/null
    screensaver_pid=""
    
    sleep 1
    clear
done
