#!/usr/bin/env bash

mapfile -t windows < <(
    swaymsg -t get_tree -r |
    jq -r '
        .. | objects
        | select(.type? == "con")
        | select(
            (.app_id? != null) or
            (.window_properties.class? != null)
        )
        | [
            .id,
            (.name // ""),
            (.app_id // .window_properties.class // "unknown")
        ]
        | @tsv
    '
)

(( ${#windows[@]} == 0 )) && exit 0

index=$(
    for row in "${windows[@]}"; do
        IFS=$'\t' read -r id title app <<< "$row"
        printf '%s  [%s]\0icon\x1f%s\n' "$title" "$app" "$app"
    done |
    rofi -dmenu \
        -i \
        -show-icons \
        -format i \
        -p "Windows"
)

[[ -z "$index" ]] && exit 0

con_id=$(printf '%s' "${windows[$index]}" | cut -f1)

swaymsg -q "[con_id=$con_id] focus"
