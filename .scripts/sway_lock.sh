#!/usr/bin/env bash
set -euo pipefail

# --wait-ready returns once Sway confirms the screen is locked, not on unlock.
# The background worker keeps the original layout until swaylock exits.
case "${1:-}" in
    ""|--wait-ready) ;;
    *) echo "Usage: $0 [--wait-ready]" >&2; exit 2 ;;
esac

# Serialize startup separately from the lock's lifetime. A second caller may
# reuse a running worker only after the first caller has confirmed readiness.
exec 8>"${XDG_RUNTIME_DIR:?}/smy-swaylock-startup.lock"
flock -w 3 8 || exit 1
exec 9>"$XDG_RUNTIME_DIR/smy-swaylock.lock"
if ! flock -n 9; then
    exit 0
fi

# Remember the currently active keyboard layout, force US for swaylock,
# then restore the previous layout after a successful unlock.
#
# Layout order in Sway:
#   0 = us
#   1 = ru

get_current_layout() {
    swaymsg -t get_inputs |
        jq -r '
            .[]
            | select(.type == "keyboard")
            | select(.xkb_active_layout_index != null)
            | .xkb_active_layout_index
        ' |
        head -n1
}

restore_layout() {
    if [[ -n "${ORIGINAL_LAYOUT:-}" ]]; then
        swaymsg "input type:keyboard xkb_switch_layout $ORIGINAL_LAYOUT" >/dev/null
    fi
}

coproc LOCK_WORKER {
    # Do not inherit the startup mutex; retain fd 9 until after layout restore.
    exec 8>&-
    ORIGINAL_LAYOUT="$(get_current_layout || true)"

    # If layout detection somehow fails, still make the lock screen usable.
    if [[ -z "$ORIGINAL_LAYOUT" || ! "$ORIGINAL_LAYOUT" =~ ^[0-9]+$ ]]; then
        ORIGINAL_LAYOUT=0
    fi

    # Always use English on the lock screen.
    swaymsg "input type:keyboard xkb_switch_layout 0" >/dev/null || true

    # Restore the previous layout even if swaylock is interrupted/errors.
    trap 'restore_layout || true' EXIT

    # Do not use -f: the worker must wait until unlock to restore the layout.
    swaylock --ready-fd 3 3>&1 >/dev/null &
    locker_pid=$!
    trap 'kill "$locker_pid" 2>/dev/null || true; wait "$locker_pid" 2>/dev/null || true; exit 1' INT TERM HUP
    wait "$locker_pid"

    # The EXIT trap restores the original layout here.
}
worker_pid=$LOCK_WORKER_PID
ready_fd=${LOCK_WORKER[0]}

# Stay below logind's default 5-second delay-inhibitor deadline. An EOF,
# failed locker, or timeout is a failure, never permission to initiate sleep.
if ! IFS= read -r -t 3 -u "$ready_fd"; then
    kill "$worker_pid" 2>/dev/null || true
    wait "$worker_pid" 2>/dev/null || true
    echo "sway_lock: lock readiness failed; refusing requested sleep" >&2
    exit 1
fi
exec 8>&-
# Only the worker should retain the lifetime lock after readiness.
exec 9>&-

if [[ "${1:-}" != --wait-ready ]]; then
    wait "$worker_pid"
fi
