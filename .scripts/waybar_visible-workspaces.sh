#!/bin/bash

outputs=$(swaymsg -t get_outputs -r)
workspaces=$(swaymsg -t get_workspaces -r)

echo "$outputs" |
jq -r '
    .[]
    | select(.active == true)
    | [.rect.x, .name]
    | @tsv
' |
sort -n |
while IFS=$'\t' read -r x output; do
    echo "$workspaces" |
    jq -r --arg output "$output" '
        .[]
        | select(.visible == true and .output == $output)
        | .name
    '
done |
paste -sd ' ' -
