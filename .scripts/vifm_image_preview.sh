#!/bin/bash

file="$1"
x="$2"
y="$3"
w="$4"
h="$5"

read -r cols lines cell_w cell_h pane_tty < <(
    tmux display-message -p \
        '#{pane_width} #{pane_height} #{client_cell_width} #{client_cell_height} #{pane_tty}'
)

pixel_w=$((cols * cell_w))
pixel_h=$((lines * cell_h))

kitten icat \
    --stdin=no \
    --use-window-size="${cols},${lines},${pixel_w},${pixel_h}" \
    --transfer-mode=file \
    --place="${w}x${h}@${x}x${y}" \
    "$file" > "$pane_tty"
