#!/bin/bash
tmux new-session -d -s VifmSession -n vifm -d "~/.config/vifm/scripts/vifmrun"
tmux attach -tVifmSession
