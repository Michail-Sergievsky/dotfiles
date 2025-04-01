#!/bin/sh
# Script to reload an instance of polybar
if [ -z "$(pidof polybar)" ]; then
  setup-polybar.sh &
else
  polybar-msg cmd restart
fi
