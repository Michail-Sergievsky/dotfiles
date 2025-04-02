#!/bin/bash
# ~/.scripts/polybar/setup-polybar.sh

CONFIG_DIR="$HOME/.config/polybar"
BASE_CONFIG="$CONFIG_DIR/config.base.ini"
FINAL_CONFIG="$CONFIG_DIR/config.ini"

BATTERY_CONFIG="$CONFIG_DIR/battery.ini"
ETH_TEMPLATE="$CONFIG_DIR/eth.template.ini"
WLAN_TEMPLATE="$CONFIG_DIR/wlan.template.ini"
VPN_CONFIG="$CONFIG_DIR/vpn.ini"
NET_CONFIG="$CONFIG_DIR/net.generated.ini"

# --- Step 1: Start from base config with placeholders ---
cp "$BASE_CONFIG" "$FINAL_CONFIG"

# --- Step 2: Detect Battery ---
BATTERY_MODULE=""
if [ -d /sys/class/power_supply/BAT0 ]; then
    BATTERY_MODULE="battery"
fi

# --- Step 3: Detect Default Network Interface ---
DEFAULT_IF=$(ip route | awk '/^default/ {print $5}' | head -n1)

# --- Step 4: Detect Wi-Fi Interfaces using iw ---
WIFI_IFS=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}')
IS_WIFI=false
for wifi_if in $WIFI_IFS; do
    if [[ "$DEFAULT_IF" == "$wifi_if" ]]; then
        IS_WIFI=true
        break
    fi
done

# --- Step 5: Generate network module config (eth/wlan) ---
NETWORK_MODULE="eth"
if $IS_WIFI; then
    NETWORK_MODULE="wlan"
    sed "s|__IFACE__|$DEFAULT_IF|g" "$WLAN_TEMPLATE" > "$NET_CONFIG"
else
    sed "s|__IFACE__|$DEFAULT_IF|g" "$ETH_TEMPLATE" > "$NET_CONFIG"
fi

# --- Step 6: Combine dynamic modules ---
DYNAMIC_LEFT_MODULES="vpn $NETWORK_MODULE $BATTERY_MODULE"
sed -i "s|\${dynamic_modules_left}|$DYNAMIC_LEFT_MODULES|g" "$FINAL_CONFIG"

# --- Step 7: Append dynamic module configs to final config ---
cat "$NET_CONFIG" >> "$FINAL_CONFIG"
cat "$VPN_CONFIG" >> "$FINAL_CONFIG"

# --- Step 8: Launch Polybar ---
~/.scripts/polybar/launchpolybar.sh
