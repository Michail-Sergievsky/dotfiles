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
    --prompt "pdfgrep here> " \
    --preview-window "right:60%:wrap:border-left" \
    --bind '?:toggle-preview' \
    --bind 'start:reload:printf ""' \
    --bind 'change:reload:bash -c '"'"'
        q="$1"
        [[ -z "$q" ]] && exit 0

        pattern="$(make_search_pattern "$q")"

        pdfgrep \
            --ignore-case \
            --perl-regexp \
            --with-filename \
            --recursive \
            -- "$pattern" "$BASE_DIR" 2>/dev/null \
            | awk -F ".pdf:" "{print \$1 \".pdf\"}" \
            | sort -fu
    '"'"' _ {q}' \
    --preview 'bash -c '"'"'
        q="$1"
        file="$2"

        [[ -z "$q" ]] && exit 0
        [[ -z "$file" ]] && exit 0
        [[ ! -f "$file" ]] && exit 0

        pattern="$(make_search_pattern "$q")"

        pdfgrep \
            --ignore-case \
            --perl-regexp \
            --page-number \
            --with-filename \
            --context 3 \
            -- "$pattern" "$file" 2>/dev/null
    '"'"' _ {q} {}'
