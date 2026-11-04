#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/waybar/config.jsonc"
TMP_CONFIG="${XDG_RUNTIME_DIR:-/tmp}/waybar-config.jsonc"
WAYBAR_LOG="${XDG_RUNTIME_DIR:-/tmp}/waybar.log"

command -v swaymsg >/dev/null 2>&1 || {
    echo "waybar_launch: swaymsg not found" >&2
    exit 1
}

command -v jq >/dev/null 2>&1 || {
    echo "waybar_launch: jq not found" >&2
    exit 1
}

command -v waybar >/dev/null 2>&1 || {
    echo "waybar_launch: waybar not found" >&2
    exit 1
}

command -v setsid >/dev/null 2>&1 || {
    echo "waybar_launch: setsid not found" >&2
    exit 1
}

# Give HDMI a short opportunity to become active after KVM reconnect.
for _ in {1..10}; do
    if swaymsg -t get_outputs -r |
        jq -e '
            .[]
            | select(
                .name == "HDMI-A-1"
                and .active == true
                and .power == true
            )
        ' >/dev/null
    then
        break
    fi

    sleep 0.1
done

# Prefer HDMI-A-1 whenever it is available.
if swaymsg -t get_outputs -r |
    jq -e '
        .[]
        | select(
            .name == "HDMI-A-1"
            and .active == true
            and .power == true
        )
    ' >/dev/null
then
    OUTPUT="HDMI-A-1"
else
    OUTPUT="eDP-1"
fi

echo "waybar_launch: selected output: $OUTPUT"

# Generate runtime Waybar config with the selected output.
jq \
    --arg output "$OUTPUT" \
    '. + {"output": $output}' \
    "$CONFIG" >"$TMP_CONFIG"

# Stop existing Waybar.
pkill -x waybar 2>/dev/null || true

# Wait until the old process is really gone.
for _ in {1..20}; do
    if ! pgrep -x waybar >/dev/null; then
        break
    fi

    sleep 0.05
done

# Start Waybar in a completely detached session.
#
# This is deliberately NOT "exec waybar" and NOT a normal shell background
# job. It must survive the watcher being interrupted from the terminal.
setsid -f waybar -c "$TMP_CONFIG" \
    >>"$WAYBAR_LOG" 2>&1 \
    </dev/null

# Verify startup.
sleep 0.3

if pgrep -x waybar >/dev/null; then
    echo "waybar_launch: Waybar started on $OUTPUT"
else
    echo "waybar_launch: ERROR: Waybar failed to start" >&2
    exit 1
fi
