#!/bin/bash

usb_print() {
    EXCLUDE_MOUNTPOINTS=(
        "/" "/home" "/boot/efi"
        "/home/freeman/DiskD"
        "/home/freeman/DiskE"
        "/home/freeman/Media"
    )

    devices=$(lsblk -Jplno NAME,TYPE,RM,SIZE,MOUNTPOINT,VENDOR)
    output=""

    for dev in $(echo "$devices" | jq -r '
        .blockdevices[] | select(.type == "part") | select(.mountpoint != null) | .name'); do

        mountpoint=$(echo "$devices" | jq -r --arg dev "$dev" '
            .blockdevices[] | select(.name == $dev) | .mountpoint')

        if [[ " ${EXCLUDE_MOUNTPOINTS[*]} " =~ " $mountpoint " ]]; then
            continue
        fi

        size=$(echo "$devices" | jq -r --arg dev "$dev" '
            .blockdevices[] | select(.name == $dev) | .size')

        # Use base directory name from mountpoint (e.g. 'Main' from '/run/media/freeman/Main')
        mountname=$(basename "$mountpoint")

        # If mountname is empty, fallback to vendor
        if [[ -z "$mountname" || "$mountname" == "null" ]]; then
            parent=$(echo "$dev" | sed 's/[0-9]*$//') # get parent device
            mountname=$(echo "$devices" | jq -r --arg parent "$parent" '
                .blockdevices[] | select(.name == $parent) | .vendor' | tr -d ' ')
            [[ "$mountname" == "null" ]] && mountname="USB"
        fi

        output="$output$mountname $size  "
    done

    echo "$output" | sed 's/ *$//'
}

usb_update() {
    pid=$(cat "$path_pid" 2>/dev/null)
    [ -n "$pid" ] && kill -10 "$pid"
}

path_pid="/tmp/polybar-system-usb-udev.pid"

case "$1" in
    --update)
        usb_update
        ;;
    --mount)
        devices=$(lsblk -Jplno NAME,TYPE,RM,MOUNTPOINT)
        for mount in $(echo "$devices" | jq -r '
            .blockdevices[] | select(.type == "part") | select(.rm == true) | select(.mountpoint == null) | .name'); do
            mountpoint=$(udisksctl mount --no-user-interaction -b "$mount")
            mountpoint=$(echo "$mountpoint" | cut -d " " -f 4 | tr -d ".")
            termite -e "bash -lc 'mc $mountpoint'" &
        done
        usb_update
        ;;
    --unmount)
        devices=$(lsblk -Jplno NAME,TYPE,RM,MOUNTPOINT)
        for unmount in $(echo "$devices" | jq -r '
            .blockdevices[] | select(.type == "part") | select(.mountpoint != null) | .name'); do
            udisksctl unmount --no-user-interaction -b "$unmount"
            udisksctl power-off --no-user-interaction -b "$unmount"
        done
        usb_update
        ;;
    *)
        echo $$ > "$path_pid"
        trap exit INT
        trap "echo" USR1
        while true; do
            usb_print
            sleep 60 &
            wait
        done
        ;;
esac
