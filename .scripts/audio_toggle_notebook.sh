#!/bin/bash

DEV1="alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo"
DEV2="alsa_output.usb-GHW-136D-20231007_USB_Audio_20210726905926-00.analog-stereo"

CURRENT=$(pactl get-default-sink)

if [[ "$CURRENT" == "$DEV1" ]]; then
    pactl set-default-sink "$DEV2"
    notify-send "Audio" "Switched to USB Audio"
else
    pactl set-default-sink "$DEV1"
    notify-send "Audio" "Switched to USB Audio Device"
fi
