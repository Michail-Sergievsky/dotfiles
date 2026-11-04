#!/bin/bash
set -euo pipefail

# Optional paths allow generation/testing without replacing the live file.
alias_source="${1:-$HOME/.bash_aliases}"
alias_output="${2:-$HOME/.config/vifm/vifm_aliases}"
alias_temp="$(mktemp "${alias_output}.tmp.XXXXXX")"
trap 'rm -f -- "$alias_temp"' EXIT

# Only active aliases inside the marked section; never execute/source them.
awk '
    /^#start_alias$/ { f=1; started=1; next }
    /^#end_alias$/ { f=0; ended=1; next }
    f && /^alias[[:space:]]/ {
        name=$0
        sub(/^alias[[:space:]]+/, "", name)
        sub(/=.*/, "", name)
        if (name !~ /^[A-Za-z][A-Za-z0-9]*$/) {
            print "Skipping alias unsupported as a Vifm command: " name > "/dev/stderr"
            next
        }
        print
    }
    END {
        if (!started || !ended || f) {
            print "Missing or incomplete Bash alias section" > "/dev/stderr"
            exit 1
        }
    }
' "$alias_source"\
	| sed 's/^alias/command!/g'\
	| sed "s/='/ :!!/"\
	| sed 's/="/ :!!/'\
	| sed "s/['\"]$//"\
	| sed '/^command! config /d'\
	> "$alias_temp"

if [[ -e "$alias_output" ]]; then
    chmod --reference="$alias_output" "$alias_temp"
else
    chmod 600 "$alias_temp"
fi
mv -- "$alias_temp" "$alias_output"
