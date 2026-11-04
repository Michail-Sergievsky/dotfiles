#!/usr/bin/env bash
set -u

# Show every connected Wi-Fi interface with signal strength.
# If no Wi-Fi interface is connected, print an empty Waybar module.

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

mapfile -t rows < <(
    LC_ALL=C nmcli -w 3 -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
    awk -F: '$2 == "wifi" && $3 == "connected"'
)

if ((${#rows[@]} == 0)); then
    printf '{"text":"","tooltip":"","class":"disconnected"}\n'
    exit 0
fi

texts=()
tips=()

for row in "${rows[@]}"; do
    iface="${row%%:*}"

    connection="$(LC_ALL=C nmcli -w 3 -t -e no -g GENERAL.CONNECTION device show "$iface" 2>/dev/null)"

    signal="$(
        LC_ALL=C nmcli -w 3 -t -f IN-USE,SIGNAL dev wifi list ifname "$iface" 2>/dev/null |
        awk -F: '$1 == "*" {print $2; exit}'
    )"

    ip4="$(
        LC_ALL=C nmcli -w 3 -g IP4.ADDRESS device show "$iface" 2>/dev/null |
        head -n1 |
        cut -d/ -f1
    )"

    [[ "$signal" =~ ^[0-9]+$ ]] || signal="?"

    texts+=("📶 ${signal}%")

    tip="Wi-Fi: $iface"
    [[ -n "$connection" && "$connection" != "--" ]] && tip+=$'\n'"SSID: $connection"
    [[ -n "$ip4" ]] && tip+=$'\n'"IPv4: $ip4"
    [[ "$signal" != "?" ]] && tip+=$'\n'"Signal: ${signal}%"
    tips+=("$tip")
done

text="$(printf '%s ' "${texts[@]}")"
text="${text% }"

tooltip="$(printf '%s\n\n' "${tips[@]}")"
tooltip="${tooltip%$'\n\n'}"

printf '{"text":%s,"tooltip":%s,"class":"connected"}\n' \
    "$(printf '%s' "$text" | json_escape)" \
    "$(printf '%s' "$tooltip" | json_escape)"
