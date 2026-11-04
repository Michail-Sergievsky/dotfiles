#!/usr/bin/env bash

set -u

# Current focused workspace + output
current_ws=$(swaymsg -t get_workspaces -r | jq -r '
    .[] | select(.focused) | .name
')

current_output=$(swaymsg -t get_workspaces -r | jq -r '
    .[] | select(.focused) | .output
')

# Temporarily switch to previously active workspace
swaymsg -q 'workspace back_and_forth'

previous_ws=$(swaymsg -t get_workspaces -r | jq -r '
    .[] | select(.focused) | .name
')

previous_output=$(swaymsg -t get_workspaces -r | jq -r '
    .[] | select(.focused) | .output
')

# Return focus to original/current workspace
swaymsg -q "workspace --no-auto-back-and-forth \"$current_ws\""

# Nothing to swap
if [[ "$current_ws" == "$previous_ws" ]]; then
    exit 0
fi

# Swap the two workspaces between their outputs
swaymsg -q \
    "workspace --no-auto-back-and-forth \"$current_ws\"; move workspace to output \"$previous_output\""

swaymsg -q \
    "workspace --no-auto-back-and-forth \"$previous_ws\"; move workspace to output \"$current_output\""

# Return focus to the originally active workspace
swaymsg -q "workspace --no-auto-back-and-forth \"$current_ws\""
