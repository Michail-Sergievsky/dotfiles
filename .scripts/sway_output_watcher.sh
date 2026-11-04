#!/usr/bin/env bash
set -u

LAYOUT="$HOME/.scripts/sway_layout.sh"
WAYBAR="$HOME/.scripts/waybar_launch.sh"

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
INSTANCE_LOCK="$RUNTIME/sway-output-watcher.instance.lock"

command -v swaymsg >/dev/null 2>&1 || exit 1
command -v jq >/dev/null 2>&1 || exit 1
command -v flock >/dev/null 2>&1 || exit 1

[[ -x "$LAYOUT" ]] || exit 1
[[ -x "$WAYBAR" ]] || exit 1


#
# Singleton: only one watcher may exist.
#
exec 200>"$INSTANCE_LOCK"

if ! flock -n 200; then
    echo "sway_output_watcher: another instance is already running" >&2
    exit 0
fi


get_outputs() {
    swaymsg -t get_outputs -r
}


#
# Return success if monitor positions/state need repair.
#
layout_needed() {
    local outputs_json="$1"

    #
    # If Sway knows about an output but it is inactive, try the layout helper.
    # This handles the KVM case where an external output reappears but remains
    # active=false/power=false.
    #
    if jq -e '.[] | select(.active != true)' \
        <<<"$outputs_json" >/dev/null
    then
        return 0
    fi

    #
    # Check whether active outputs are arranged in our desired order:
    #
    #   eDP/LVDS -> HDMI -> DP -> other
    #
    local expected_x=0
    local priority name width x

    while IFS=$'\t' read -r priority name width x; do
        [[ -n "$name" ]] || continue

        if [[ ! "$width" =~ ^[0-9]+$ ]] || (( width <= 0 )); then
            return 0
        fi

        if [[ "$x" != "$expected_x" ]]; then
            return 0
        fi

        expected_x=$((expected_x + width))

    done < <(
        jq -r '
            .[]
            | select(.active == true)
            | .name as $name
            | (
                if   ($name | test("^(eDP|LVDS)-")) then 10
                elif ($name | test("^HDMI-"))       then 20
                elif ($name | test("^DP-"))         then 30
                else 90
                end
              ) as $priority
            | (
                if (.rect.width // 0) > 0 then
                    .rect.width
                elif (.current_mode.width // 0) > 0 then
                    ((.current_mode.width / (.scale // 1)) | floor)
                else
                    0
                end
              ) as $width
            | [
                $priority,
                $name,
                $width,
                (.rect.x // -1)
              ]
            | @tsv
        ' <<<"$outputs_json" |
        sort -n -k1,1 -k2,2
    )

    return 1
}


desired_waybar_output() {
    local outputs_json="$1"

    if jq -e '
        .[]
        | select(
            .name == "HDMI-A-1"
            and .active == true
            and .power == true
        )
    ' <<<"$outputs_json" >/dev/null
    then
        printf '%s\n' "HDMI-A-1"
    else
        printf '%s\n' "eDP-1"
    fi
}


current_waybar_output() {
    local config="$RUNTIME/waybar-config.jsonc"

    if [[ -f "$config" ]]; then
        jq -r '.output // empty' "$config" 2>/dev/null
    fi
}


echo "sway_output_watcher: started"

while sleep 0.5; do
    outputs_json="$(get_outputs)" || continue

    #
    # 1. Reconcile monitor layout.
    #
    if layout_needed "$outputs_json"; then
        echo "sway_output_watcher: monitor layout/state mismatch"

        "$LAYOUT" 200>&-

        # Let Sway settle before deciding where Waybar belongs.
        sleep 0.5

        outputs_json="$(get_outputs)" || continue
    fi


    #
    # 2. Independently reconcile Waybar.
    #
    # This runs EVERY loop and therefore does not depend on detecting a
    # topology transition correctly.
    #
    desired="$(desired_waybar_output "$outputs_json")"
    current="$(current_waybar_output)"

    if ! pgrep -x waybar >/dev/null; then
        echo "sway_output_watcher: Waybar missing; desired=$desired"

        "$WAYBAR" 200>&-

    elif [[ "$current" != "$desired" ]]; then
        echo "sway_output_watcher: Waybar mismatch: current=$current desired=$desired"

        "$WAYBAR" 200>&-
    fi
done
