#!/usr/bin/env bash
set -euo pipefail

command -v swaymsg >/dev/null 2>&1 || {
    echo "sway_layout: swaymsg not found" >&2
    exit 1
}

command -v jq >/dev/null 2>&1 || {
    echo "sway_layout: jq not found" >&2
    exit 1
}

get_outputs() {
    swaymsg -t get_outputs -r
}

outputs_json="$(get_outputs)"

mapfile -t present_outputs < <(
    jq -r '.[].name' <<<"$outputs_json"
)

if ((${#present_outputs[@]} == 0)); then
    echo "sway_layout: no outputs found" >&2
    exit 1
fi

echo "sway_layout: present outputs: ${present_outputs[*]}"

# KVM reconnect may leave outputs present but inactive.
for name in "${present_outputs[@]}"; do
    swaymsg "output \"$name\" enable" >/dev/null
done

# Wait up to ~1.5 seconds for modesetting/hotplug to settle.
for _ in {1..10}; do
    sleep 0.15
    outputs_json="$(get_outputs)"

    inactive_count="$(
        jq '[.[] | select(.active != true)] | length' <<<"$outputs_json"
    )"

    [[ "$inactive_count" == "0" ]] && break
done

outputs_json="$(get_outputs)"

mapfile -t outputs < <(
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
        | [$priority, $name, $width]
        | @tsv
    ' <<<"$outputs_json" | sort -n -k1,1 -k2,2
)

if ((${#outputs[@]} == 0)); then
    echo "sway_layout: no active outputs after enable phase" >&2
    exit 1
fi

mapfile -t still_inactive < <(
    jq -r '.[] | select(.active != true) | .name' <<<"$outputs_json"
)

if ((${#still_inactive[@]} > 0)); then
    echo "sway_layout: warning: still inactive: ${still_inactive[*]}" >&2
fi

x=0

echo "sway_layout: arranging ${#outputs[@]} active output(s)"

for row in "${outputs[@]}"; do
    IFS=$'\t' read -r priority name width <<<"$row"

    if [[ ! "$width" =~ ^[0-9]+$ ]] || (( width <= 0 )); then
        echo "sway_layout: cannot determine logical width of $name" >&2
        exit 1
    fi

    swaymsg "output \"$name\" position $x 0" >/dev/null
    echo "  $name -> ${x},0  width=${width}"

    x=$((x + width))
done
