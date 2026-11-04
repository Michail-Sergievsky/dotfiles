#!/usr/bin/env bash

unset FZF_DEFAULT_OPTS

BASE_DIR="$(pwd)"
export BASE_DIR

make_search_pattern() {
    printf '%s' "$1" \
        | perl -CS -Mopen=locale -pe '
            s/([\\.^$|(){}\[\]*+?])/\\$1/g;
            s/\s+/[ ._:-]+/g;
        '
}
export -f make_search_pattern

fzf \
    --disabled \
    --ansi \
    --height 95% \
    --layout reverse \
    --prompt "rg here> " \
    --preview-window "right:60%:wrap:border-left" \
    --bind '?:toggle-preview' \
    --bind 'start:reload:printf ""' \
    --bind 'change:reload:bash -c '"'"'
        q="$1"
        [[ -z "$q" ]] && exit 0

        pattern="$(make_search_pattern "$q")"

        rg -i --files-with-matches --no-messages -- "$pattern" "$BASE_DIR" | sort -f
    '"'"' _ {q}' \
    --preview 'bash -c '"'"'
        q="$1"
        file="$2"

        [[ -z "$q" ]] && exit 0
        [[ -z "$file" ]] && exit 0
        [[ ! -f "$file" ]] && exit 0

        pattern="$(make_search_pattern "$q")"

        rg \
            --ignore-case \
            --pretty \
            --context 5 \
            --colors "match:bg:yellow" \
            -- "$pattern" "$file"
    '"'"' _ {q} {}'
