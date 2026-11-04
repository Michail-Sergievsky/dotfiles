#!/usr/bin/env bash
set -u

# Show every connected Ethernet interface.
# If no wired interface is connected, print an empty Waybar module.

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

mapfile -t rows < <(
    LC_ALL=C nmcli -w 3 -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
    awk -F: '$2 == "ethernet" && $3 == "connected"'
)

if ((${#rows[@]} == 0)); then
    printf '{"text":"","tooltip":"","class":"disconnected"}\n'
    exit 0
fi

texts=()
tips=()

for row in "${rows[@]}"; do
    iface="${row%%:*}"

    # Read the free-form name alone; terse multi-column output escapes ':'.
    connection="$(LC_ALL=C nmcli -w 3 -t -e no -g GENERAL.CONNECTION device show "$iface" 2>/dev/null)"

    ip4="$(
        LC_ALL=C nmcli -w 3 -g IP4.ADDRESS device show "$iface" 2>/dev/null |
        head -n1 |
        cut -d/ -f1
    )"

    texts+=("🔌")

    tip="Ethernet: $iface"
    [[ -n "$connection" && "$connection" != "--" ]] && tip+=$'\n'"Connection: $connection"
    [[ -n "$ip4" ]] && tip+=$'\n'"IPv4: $ip4"
    tips+=("$tip")
done

text="$(printf '%s ' "${texts[@]}")"
text="${text% }"

tooltip="$(printf '%s\n\n' "${tips[@]}")"
tooltip="${tooltip%$'\n\n'}"

printf '{"text":%s,"tooltip":%s,"class":"connected"}\n' \
    "$(printf '%s' "$text" | json_escape)" \
    "$(printf '%s' "$tooltip" | json_escape)"
