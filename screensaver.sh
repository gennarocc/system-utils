#!/bin/bash

screensavers=("pipes -f 20 -p 2" "lavat -c cyan -R1 -F @@:::::: -r3")

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
        # Pick random screensaver from base array
        echo "${screensavers[$RANDOM % ${#screensavers[@]}]}"
    fi
}

while true; do
    selected_screensaver=$(select_screensaver)
    
    # Run the selected screensaver
    eval $selected_screensaver &
    screensaver_pid=$!
    
    # Check weather every 3 hours
    sleep 10800
    
    # Kill the screensaver
    kill $screensaver_pid 2>/dev/null
    wait $screensaver_pid 2>/dev/null
    
    sleep 1
done
