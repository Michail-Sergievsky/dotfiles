#!/usr/bin/env bash
set -euo pipefail

snippets_file="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/clipboard-static.txt"
snippets=()
saved_snippets=()
history=()
choices=()

if [[ -r "$snippets_file" ]]; then
    mapfile -t snippets < "$snippets_file"
fi

history_output="$(cliphist list)" || {
    printf 'Could not read clipboard history.\n' >&2
    exit 1
}
if [[ -n "$history_output" ]]; then
    mapfile -t history <<< "$history_output"
fi

for entry in "${history[@]}"; do
    preview="${entry#*$'\t'}"
    choices+=("↻  $preview")
done

for snippet in "${snippets[@]}"; do
    [[ -n "$snippet" ]] || continue
    saved_snippets+=("$snippet")
    choices+=("★  $snippet")
done

(( ${#choices[@]} > 0 )) || exit 0

if ! selected_index="$(printf '%s\n' "${choices[@]}" | rofi -dmenu -i -format i -p 'Clipboard')"; then
    exit 0
fi
[[ "$selected_index" =~ ^[0-9]+$ ]] || exit 0

if (( selected_index < ${#history[@]} )); then
    printf '%s\n' "${history[selected_index]}" | cliphist decode | wl-copy
else
    snippet_index=$((selected_index - ${#history[@]}))
    (( snippet_index < ${#saved_snippets[@]} )) || exit 1
    printf '%s' "${saved_snippets[snippet_index]}" | wl-copy
fi
