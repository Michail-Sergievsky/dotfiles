#!/bin/sh
# Keep the Waybar module responsive when the weather service is unavailable.
weather=$(curl --fail --silent --location --connect-timeout 3 --max-time 8 \
    --max-filesize 128 'https://wttr.in/Krasnodar?format=%c+%t' 2>/dev/null) || {
    printf '%s\n' 'WETH_PROB'
    exit 0
}

weather=$(printf '%s' "$weather" | tr -d '\r\n' | tr -s ' ')
if printf '%s' "$weather" | grep -Eq '^[^[:space:][:cntrl:]]{1,8}[[:space:]]+[+-]?[0-9]{1,3}°C$'; then
    printf '%s\n' "$weather"
else
    printf '%s\n' 'WETH_PROB'
fi
