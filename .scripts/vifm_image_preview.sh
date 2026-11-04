#!/bin/bash
# Vifm graphical previews: TYPE FILE X Y W H, or clear. Coordinates are cells.
# %N keeps /dev/tty available; %pc must invoke clear when the preview closes.
set -u
umask 077

fail() { printf 'Vifm preview: %s\n' "$1" >&2; exit 1; }
positive() { [[ $1 =~ ^[0-9]{1,6}$ ]] && ((10#$1 > 0)); }
integer() { [[ $1 =~ ^-?[0-9]{1,6}$ ]]; }

mode=${1:-}
case $mode in
    clear) (( $# == 1 )) || fail 'usage: clear' ;;
    image|pdf|djvu|epub|font) (( $# == 6 )) || fail 'usage: TYPE FILE X Y W H' ;;
    *) fail 'unknown preview type' ;;
esac

passthrough=none
if [[ -n ${TMUX:-} ]]; then
    [[ ${TMUX_PANE:-} =~ ^%[0-9]+$ ]] || fail 'missing tmux pane'
    passthrough=tmux
    context="tmux:${TMUX%%,*}:$TMUX_PANE"
else
    [[ ${KITTY_WINDOW_ID:-} =~ ^[0-9]+$ ]] || fail 'Kitty terminal required'
    # No terminal probing or input reads. tty identifies the controlling session.
    terminal=$(ps -o tty= -p "$$") || fail 'controlling terminal unavailable'
    terminal=${terminal//[[:space:]]/}
    [[ $terminal == pts/[0-9]* || $terminal == tty[0-9]* ]] || fail 'controlling terminal unavailable'
    context="kitty:$KITTY_WINDOW_ID:$terminal"
fi

# Small runtime state only; thumbnails are never cached. Reject foreign/symlink dirs.
runtime=${XDG_RUNTIME_DIR:-/tmp}
[[ -d $runtime && -O $runtime && ! -L $runtime ]] || runtime=/tmp
state_root=$runtime/vifm-kitty-$UID
if ! mkdir -m 700 -- "$state_root" 2>/dev/null; then
    [[ -d $state_root && -O $state_root && ! -L $state_root &&
       $(stat -c %a -- "$state_root") == 700 ]] || fail 'unsafe runtime directory'
fi
key=$(printf '%s' "$context" | sha256sum); key=${key%% *}
state=$state_root/$key
[[ ! -L $state && ! -L $state.lock ]] || fail 'unsafe preview state'
exec {lock}>"$state.lock" || fail 'cannot open preview lock'
token='' work='' child='' target='' image_id=0 cursor_saved=0

geometry() {
    local data session viewers zoom active in_mode name term cw ch utf8 seen=0 metrics=
    if [[ $passthrough == tmux ]]; then
        data=$(tmux -N display-message -p -t "$TMUX_PANE" \
            '#{session_id}|#{pane_width}|#{pane_height}|#{pane_tty}|#{window_active_clients_list}|#{window_zoomed_flag}|#{pane_active}|#{pane_in_mode}') || return 1
        IFS='|' read -r session cols rows target viewers zoom active in_mode <<< "$data"
        [[ $session == \$[0-9]* && -n $viewers && $in_mode == 0 &&
           ( $zoom == 0 || $active == 1 ) ]] || return 1
        data=$(tmux -N list-clients -t "$session" -F \
            '#{client_name}|#{client_termname}|#{client_cell_width}|#{client_cell_height}|#{client_utf8}') || return 1
        while IFS='|' read -r name term cw ch utf8; do
            case ",${viewers// /,}," in *,"$name",*) ;; *) continue ;; esac
            [[ $term == xterm-kitty && $utf8 == 1 ]] && positive "$cw" && positive "$ch" || return 1
            [[ -z $metrics || $metrics == "$cw,$ch" ]] || return 1
            metrics=$cw,$ch; seen=1
        done <<< "$data"
        (( seen )) || return 1
        positive "$cols" && positive "$rows" || return 1
        IFS=, read -r cw ch <<< "$metrics"
        cols=$((10#$cols)); rows=$((10#$rows))
        pixels_w=$((cols * 10#$cw)); pixels_h=$((rows * 10#$ch))
    else
        target=/dev/$terminal
        # Bash has no ioctl primitive. Stdlib TIOCGWINSZ reads kernel geometry,
        # including real pixel metrics, without sending terminal queries.
        data=$(python3 - <<'PY'
import fcntl, os, struct, termios
fd = os.open('/dev/tty', os.O_RDONLY | os.O_NOCTTY)
try:
    rows, cols, width, height = struct.unpack('HHHH', fcntl.ioctl(fd, termios.TIOCGWINSZ, b'\0' * 8))
    print(cols, rows, width, height)
finally:
    os.close(fd)
PY
        ) || return 1
        read -r cols rows pixels_w pixels_h <<< "$data"
    fi
    [[ $target == /dev/pts/[0-9]* || $target == /dev/tty[0-9]* ]] &&
        [[ -c $target && -O $target && -w $target ]] || return 1
    positive "$cols" && positive "$rows" && positive "$pixels_w" && positive "$pixels_h" || return 1
    (( pixels_w >= cols && pixels_h >= rows ))
}

delete_image() {
    local id=$1 packet
    [[ $id =~ ^[0-9]+$ ]] && (( id > 0 && id <= 4294967295 )) || return 0
    [[ -n $target && -c $target && -O $target ]] || return 0
    # ID-targeted deletion also removes Unicode virtual placements; never clear-all.
    printf -v packet '\033_Ga=d,d=I,i=%s,q=2\033\134' "$id"
    if [[ $passthrough == tmux ]]; then
        packet=${packet//$'\033'/$'\033\033'}
        printf '\033Ptmux;%s\033\134' "$packet" > "$target"
    else
        printf '%s' "$packet" > "$target"
    fi
}

read_state() {
    old_token='' old_id=0 old_target=''
    if [[ -f $state ]]; then IFS='|' read -r old_token old_id old_target < "$state" || :; fi
    # Only accept a pane/terminal owned by this user, never an arbitrary state path.
    [[ $old_target == /dev/pts/[0-9]* || $old_target == /dev/tty[0-9]* ]] || old_target=
}

begin_request() {
    flock -x "$lock" || fail 'cannot lock preview state'
    read_state
    target=$old_target
    delete_image "$old_id"
    token=$BASHPID-$RANDOM-$RANDOM
    # Random IDs reduce collisions with other Kitty applications; each context owns one.
    read -r image_id < <(od -An -N4 -tu4 /dev/urandom)
    image_id=$((image_id % 4294967295 + 1))
    [[ $mode != clear ]] || image_id=0
    printf '%s|%s|\n' "$token" "$image_id" > "$state"
    flock -u "$lock"
}

stop_child() {
    if [[ -n $child ]]; then
        # GNU timeout forwards TERM to its converter process group.
        kill -TERM "$child" 2>/dev/null || :
        wait "$child" 2>/dev/null || :
        child=
    fi
}
cleanup() {
    stop_child
    (( ! cursor_saved )) || printf '\0338' >&"$tty_fd"
    [[ -z $work ]] || rm -rf -- "$work"
}
cancel() {
    stop_child
    flock -x "$lock"
    read_state
    if [[ $old_token == "$token" ]]; then
        target=$old_target; delete_image "$old_id"
        printf '%s|0|\n' "$token-cancelled" > "$state"
    fi
    flock -u "$lock"
    exit "$1"
}
trap cleanup EXIT
trap 'cancel 130' INT
trap 'cancel 143' TERM
begin_request
[[ $mode != clear ]] || exit 0

input=$2
[[ ! -L $input && -f $input && -r $input ]] || fail 'readable regular local file required (no symlinks)'
[[ $input != *://* ]] || fail 'URLs are not preview inputs'
IFS= read -r -d '' input < <(realpath -e -z -- "$input") || fail 'cannot resolve input file'
for value in "${@:3}"; do integer "$value" || fail 'invalid preview rectangle'; done
# Avoid leading-zero octal interpretation and bound arithmetic before using it.
number() { if [[ $1 == -* ]]; then printf '%d' "$((-10#${1#-}))"; else printf '%d' "$((10#$1))"; fi; }
raw_x=$(number "$3"); raw_y=$(number "$4"); raw_w=$(number "$5"); raw_h=$(number "$6")
(( raw_w > 0 && raw_h > 0 )) || fail 'empty preview rectangle'
geometry || fail 'visible Kitty terminal with valid cell/pixel geometry required'
if [[ $passthrough == tmux ]]; then
    setting=$(tmux -N show-options -gv allow-passthrough) || fail 'cannot inspect tmux passthrough'
    [[ $setting == on || $setting == all ]] || fail 'tmux allow-passthrough is disabled; load the approved config before graphical testing'
fi

rectangle() {
    x=$((raw_x > 0 ? raw_x : 0)); y=$((raw_y > 0 ? raw_y : 0))
    local right=$((raw_x + raw_w)) bottom=$((raw_y + raw_h))
    (( right <= cols )) || right=$cols
    (( bottom <= rows )) || bottom=$rows
    w=$((right - x)); h=$((bottom - y))
    (( w > 0 && h > 0 )) || return 1
    limit_w=$((w * pixels_w / cols)); limit_h=$((h * pixels_h / rows))
    (( limit_w <= 2048 )) || limit_w=2048
    (( limit_h <= 2048 )) || limit_h=2048
    limit=$((limit_w > limit_h ? limit_w : limit_h))
}
rectangle || fail 'preview rectangle is outside the terminal'
work=$(mktemp -d "$state_root/request.XXXXXXXX") || fail 'cannot create temporary preview directory'

run_converter() {
    timeout --kill-after=1s 5s "$@" </dev/null >"$work/converter.out" 2>"$work/converter.err" &
    child=$!
    local result=0
    wait "$child" || result=$?
    child=
    (( result == 0 )) || fail 'conversion failed or timed out (source unchanged)'
}

convert_image() {
    rendered=$input
    case $mode in
        pdf)
            run_converter pdftoppm -f 1 -l 1 -singlefile -png -scale-to "$limit" "$input" "$work/preview"
            rendered=$work/preview.png ;;
        djvu)
            run_converter ddjvu -format=ppm -page=1 "-size=${limit_w}x${limit_h}" "$input" "$work/page.ppm"
            run_converter magick "$work/page.ppm" "$work/preview.png"
            rendered=$work/preview.png ;;
        epub)
            # The validated absolute regular input prevents thumbnailer's URL fallback.
            run_converter epub-thumbnailer "$input" "$work/preview.png" "$limit"
            rendered=$work/preview.png ;;
        font)
            local sample=$'ABCDEFGHIJKLM\nNOPQRSTUVWXYZ\nabcdefghijklm\nnopqrstuvwxyz\n1234567890\n!@$%(){}[]\nالسلام عليكم'
            run_converter magick -size 1000x1000 xc:white -gravity center -pointsize 38 \
                -font "$input" -fill black -annotate +0+0 "$sample" -flatten \
                -resize "${limit_w}x${limit_h}>" "$work/preview.png"
            rendered=$work/preview.png ;;
        image)
            local mime
            mime=$(file --brief --mime-type -- "$input") || fail 'cannot identify image'
            if [[ $mime == image/svg+xml ]]; then
                run_converter rsvg-convert --width "$limit_w" --height "$limit_h" \
                    --keep-aspect-ratio --output "$work/preview.png" "$input"
                rendered=$work/preview.png
            fi ;;
    esac
    [[ -f $rendered && -s $rendered ]] || fail 'converter produced no image'
}
convert_image

# Conversion never holds the lock. Only a still-current request may draw.
flock -x "$lock" || fail 'cannot lock preview state'
read_state
[[ $old_token == "$token" ]] || exit 0
# Recheck dimensions after conversion so a resize cannot make placeholders wrap.
if ! geometry || ! rectangle; then fail 'terminal geometry changed or became unavailable'; fi
printf '%s|%s|%s\n' "$token" "$image_id" "$target" > "$state"
exec {tty_fd}>"$target" || fail 'cannot write pane terminal'
printf '\0337' >&"$tty_fd"
cursor_saved=1
timeout --kill-after=1s 5s kitten icat --stdin=no --transfer-mode=stream \
    "--passthrough=$passthrough" "--image-id=$image_id" \
    "--use-window-size=$cols,$rows,$pixels_w,$pixels_h" \
    "--place=${w}x${h}@${x}x${y}" -- "$rendered" \
    </dev/null 1>&"$tty_fd" 2>"$work/renderer.err" &
child=$!
result=0
wait "$child" || result=$?
child=
printf '\0338' >&"$tty_fd"
cursor_saved=0
if (( result != 0 )); then
    delete_image "$image_id"
    fail 'Kitty image transfer failed or timed out'
fi
flock -u "$lock"
