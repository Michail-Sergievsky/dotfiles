#!/usr/bin/env bash
set -o pipefail

# JSON preserves spaces in labels and mount paths and the parent/child relation.
out=$(lsblk --json --tree -o PATH,TYPE,RM,SIZE,LABEL,MOUNTPOINTS 2>/dev/null |
    python3 "$HOME/.scripts/priv/waybar_usb_format.py") || {
  notify-send -t 2500 "USB" "USB information unavailable"
  exit 0
}

if [[ -z "$out" ]]; then
  notify-send -t 2500 "USB" "No removable devices"
  exit 0
fi

notify-send -t 7000 "USB devices" "$out"
