#!/usr/bin/env bash

pkill -x swayidle 2>/dev/null

exec swayidle -w \
    timeout 2700 'swaymsg "output * power off"' \
    resume 'swaymsg "output * power on"' \
    before-sleep "\"$HOME/.scripts/sway_lock.sh\" --wait-ready" \
    after-resume 'swaymsg "output * power on"'
