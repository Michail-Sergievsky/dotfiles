#!/bin/bash
set -u
set -o pipefail

# ============================================================
# Unified YouTube downloader for freeman
# v3.7: adds [audio-channel] with per-channel N-month date window
#
# Input:
#   ~/Downloads/youtube/inbox.txt
#
# Sections:
#   [video]           -> single video, best modern formats, MKV
#   [video-mp4]       -> single video, MP4 compatibility mode
#   [video-subtitles] -> single video, MKV + real uploaded English subtitles
#   [video-playlist]  -> whole playlist, best modern formats, MKV
#   [video-clips]     -> smart music-video search; downloads remaster + normal variants when distinct; v3.5 precision fallback + alias-safe relevance + universal network retry, max 1080p
#   [audio]           -> single video audio, YYYYMMDD - Title.opus
#   [audio-playlist]  -> whole playlist as Opus audio files
#   [audio-channel]   -> channel audio for the last N months; inbox syntax: N | CHANNEL_URL
#   [music]           -> one song URL, Uploader - Title.opus
#   [music-search]    -> YouTube search query, first result, Uploader - Title.opus
#   [chapters]        -> split by chapters into separate Opus tracks
#
# Docker:
#   bgutil-pot container stays running
#   yt-dlp:pot container runs per item
# ============================================================

BASE_DIR="$HOME/Downloads/youtube"

INBOX_FILE="$BASE_DIR/inbox.txt"
STATE_DIR="$BASE_DIR/.state"
ARCHIVE_DIR="$STATE_DIR/archives"
DONE_FILE="$STATE_DIR/inbox.done.txt"
FAILED_FILE="$STATE_DIR/inbox.failed.log"
HISTORY_FILE="$STATE_DIR/inbox.history.tsv"

LOG_DIR="$BASE_DIR/logs"

FIREFOX_ROOT="$HOME/.mozilla/firefox"
FIREFOX_PROFILES_INI="$FIREFOX_ROOT/profiles.ini"

PROXY_URL="http://127.0.0.1:2080"
POT_URL="http://127.0.0.1:4416"

YTDLP_IMAGE="ghcr.io/jim60105/yt-dlp:pot"
POT_IMAGE="ghcr.io/jim60105/bgutil-pot:latest"
POT_CONTAINER="bgutil-pot"

ENABLE_LOG=1
LOG_FILE=""

MODE="inbox"
EXTRA_YTDLP_ARGS=()

FIREFOX_PROFILE_PATH=""
RUN_OUTPUT_FILE=""

PROCESSING_INBOX=0
declare -a QUEUE_SECTIONS=()
declare -a QUEUE_ITEMS=()
declare -a QUEUE_DONE=()

# [video-clips] runtime/search statistics
CLIP_SELECTED_URL=""
CLIP_SELECTED_ID=""
CLIP_SELECTED_TITLE=""
CLIP_SELECTED_UPLOADER=""
CLIP_SELECTED_SEARCH_MODE=""
CLIP_SAFE_INPUT=""

CLIP_REMASTER_URL=""
CLIP_REMASTER_ID=""
CLIP_REMASTER_TITLE=""
CLIP_REMASTER_UPLOADER=""

CLIP_NORMAL_URL=""
CLIP_NORMAL_ID=""
CLIP_NORMAL_TITLE=""
CLIP_NORMAL_UPLOADER=""

CLIP_DOWNLOADED=0
CLIP_DOWNLOADED_REMASTER=0
CLIP_DOWNLOADED_NORMAL=0
CLIP_SKIPPED_SAME_ID=0
# v3.6: distinguish a real new output from yt-dlp rc=0 caused by an
# archive/existing-file skip.  This prevents false DONE queue removal.
CLIP_CREATED_THIS_ITEM=0
CLIP_SKIPPED_NO_OUTPUT=0
CLIP_ITEM_OUTPUT_LINES=""

# Internal [video-clips] result codes.
# 44: searches succeeded, but no acceptable candidate exists.
# 45: search/API/network failure; stop this run and retry later.
# 46: candidate found, but all download routes failed / produced no new output.
# 47: internal per-variant marker: yt-dlp returned rc=0 but emitted no YTDL_FILE.
RC_CLIP_NOT_FOUND=44
RC_SEARCH_FAILURE=45
RC_DOWNLOAD_FAILURE=46
RC_CLIP_NO_OUTPUT=47


CLIP_REJECT_LYRICS=0
CLIP_REJECT_LIVE_HARD=0
CLIP_REJECT_LIVE_LOCATION=0
CLIP_REJECT_TEASER=0
CLIP_REJECT_TRAILER=0
CLIP_REJECT_REACTION=0
CLIP_REJECT_AUDIO=0
CLIP_REJECT_VISUALIZER=0
CLIP_REJECT_RELEVANCE=0
CLIP_REJECT_RELEVANCE_ARTIST=0
CLIP_REJECT_RELEVANCE_TRACK=0
CLIP_REJECT_FANCAM=0
CLIP_REJECT_PERFORMANCE=0
CLIP_REJECT_OTHER=0

declare -a CLIP_NOT_FOUND_ITEMS=()
declare -a CLIP_LIVE_LOCATION_ITEMS=()
declare -A CLIP_LIVE_LOCATION_SEEN=()

SECTIONS=(
    "video"
    "video-mp4"
    "video-subtitles"
    "video-playlist"
    "video-clips"
    "audio"
    "audio-playlist"
    "audio-channel"
    "music"
    "music-search"
    "chapters"
)

usage() {
    cat <<EOF_USAGE
Usage:
  ytdl.sh [--no-log] [extra yt-dlp args...]
  ytdl.sh --inbox [--no-log] [extra yt-dlp args...]

Input:
  $INBOX_FILE

Inbox format:
  [video]
  https://www.youtube.com/watch?v=AAAA

  [video-mp4]
  https://www.youtube.com/watch?v=BBBB

  [video-subtitles]
  https://www.youtube.com/watch?v=CCCC

  [video-playlist]
  https://www.youtube.com/playlist?list=...

  [video-clips]
  Artist - Track
  # smart search: remaster + normal variants; strict relevance/live filtering; max 1080p

  [audio]
  https://www.youtube.com/watch?v=DDDD

  [audio-playlist]
  https://www.youtube.com/playlist?list=...

  [audio-channel]
  14 | https://www.youtube.com/@SomeChannel/videos
  # downloads channel videos published during the last 14 months as Opus audio

  [music]
  https://www.youtube.com/watch?v=EEEE

  [music-search]
  Lady Gaga Americano Official Audio

  [chapters]
  https://www.youtube.com/watch?v=FFFF

Output:
  video:       $BASE_DIR/video/
  video-clips: $BASE_DIR/video-clips/
  audio:         $BASE_DIR/audio/
  audio-channel: $BASE_DIR/audio/<channel>/
  music:   $BASE_DIR/music/
  logs:    $LOG_DIR/

Human-readable history:
  $DONE_FILE
  $FAILED_FILE
  $HISTORY_FILE

Technical yt-dlp archive files:
  $ARCHIVE_DIR/video.txt
  $ARCHIVE_DIR/video_mp4.txt
  $ARCHIVE_DIR/video_subtitles.txt
  $ARCHIVE_DIR/video_playlist.txt
  $ARCHIVE_DIR/video_clips.txt
  $ARCHIVE_DIR/audio.txt
  $ARCHIVE_DIR/audio_playlist.txt
  $ARCHIVE_DIR/audio_channel.txt
  $ARCHIVE_DIR/music.txt
  $ARCHIVE_DIR/music_search.txt
  $ARCHIVE_DIR/chapters.txt

Options:
  --log               write log to default timestamped file (default)
  --log=/path/file    write log to specific file
  --no-log            disable logfile for this run
  -h, --help          show help

Examples:
  ytdl.sh
  ytdl.sh --limit-rate 2M
  ytdl.sh --no-log
EOF_USAGE
}

RUN_OUTPUT_FILE=""

cleanup_runtime_files() {
    if [[ -n "${RUN_OUTPUT_FILE:-}" && -f "${RUN_OUTPUT_FILE:-}" ]]; then
        rm -f -- "$RUN_OUTPUT_FILE"
    fi
}

trap cleanup_runtime_files EXIT INT TERM

log_msg() {
    local msg="$1"
    echo "$msg"
    if [[ "$ENABLE_LOG" -eq 1 ]]; then
        echo "$msg" >> "$LOG_FILE"
    fi
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

require_cmds() {
    command -v docker >/dev/null 2>&1 || die "docker not found"
    command -v curl >/dev/null 2>&1 || die "curl not found"
    command -v awk >/dev/null 2>&1 || die "awk not found"
    command -v grep >/dev/null 2>&1 || die "grep not found"
    command -v sed >/dev/null 2>&1 || die "sed not found"
    command -v python3 >/dev/null 2>&1 || die "python3 not found"
}

migrate_legacy_state_files() {
    local old new

    mkdir -p "$STATE_DIR" "$ARCHIVE_DIR"

    # Move old inbox state files only when destination does not already exist.
    for old in "$BASE_DIR/inbox.done.txt" "$BASE_DIR/inbox.history.tsv"; do
        [[ -f "$old" ]] || continue
        case "$(basename "$old")" in
            inbox.done.txt)    new="$DONE_FILE" ;;
            inbox.failed.log)  new="$FAILED_FILE" ;;
            inbox.history.tsv) new="$HISTORY_FILE" ;;
        esac

        if [[ ! -e "$new" ]]; then
            mv -- "$old" "$new"
        fi
    done

    # Legacy failed history from older versions -> append-only failed log.
    if [[ -f "$BASE_DIR/inbox.failed.txt" && ! -e "$FAILED_FILE" ]]; then
        mv -- "$BASE_DIR/inbox.failed.txt" "$FAILED_FILE"
    elif [[ -f "$BASE_DIR/inbox.failed.txt" && -e "$FAILED_FILE" ]]; then
        cat "$BASE_DIR/inbox.failed.txt" >> "$FAILED_FILE"
        rm -f -- "$BASE_DIR/inbox.failed.txt"
    fi

    # Legacy .state/inbox.failed.log from v3.x.
    if [[ -f "$STATE_DIR/inbox.failed.txt" && ! -e "$FAILED_FILE" ]]; then
        mv -- "$STATE_DIR/inbox.failed.log" "$FAILED_FILE"
    elif [[ -f "$STATE_DIR/inbox.failed.txt" && -e "$FAILED_FILE" ]]; then
        cat "$STATE_DIR/inbox.failed.txt" >> "$FAILED_FILE"
        rm -f -- "$STATE_DIR/inbox.failed.txt"
    fi

    # Move legacy yt-dlp archive files.
    while IFS='|' read -r old new; do
        [[ -f "$old" ]] || continue
        if [[ ! -e "$new" ]]; then
            mv -- "$old" "$new"
        fi
    done <<EOF
$BASE_DIR/.download_archive_video.txt|$ARCHIVE_DIR/video.txt
$BASE_DIR/.download_archive_video_mp4.txt|$ARCHIVE_DIR/video_mp4.txt
$BASE_DIR/.download_archive_video_subtitles.txt|$ARCHIVE_DIR/video_subtitles.txt
$BASE_DIR/.download_archive_video_playlist.txt|$ARCHIVE_DIR/video_playlist.txt
$BASE_DIR/.download_archive_video_clips.txt|$ARCHIVE_DIR/video_clips.txt
$BASE_DIR/.download_archive_audio.txt|$ARCHIVE_DIR/audio.txt
$BASE_DIR/.download_archive_audio_playlist.txt|$ARCHIVE_DIR/audio_playlist.txt
$BASE_DIR/.download_archive_music.txt|$ARCHIVE_DIR/music.txt
$BASE_DIR/.download_archive_music_search.txt|$ARCHIVE_DIR/music_search.txt
$BASE_DIR/.download_archive_chapters.txt|$ARCHIVE_DIR/chapters.txt
EOF

    # Stale temp captures from old versions are safe to remove.
    rm -f -- "$BASE_DIR"/.ytdl_output.* 2>/dev/null || true
}


prepare_dirs() {
    mkdir -p "$BASE_DIR" "$LOG_DIR" "$STATE_DIR" "$ARCHIVE_DIR"
    migrate_legacy_state_files
    mkdir -p "$BASE_DIR/video" "$BASE_DIR/audio" "$BASE_DIR/music" "$BASE_DIR/video-clips"

    if [[ ! -f "$INBOX_FILE" ]]; then
        write_clean_inbox
    fi

    touch "$DONE_FILE" "$FAILED_FILE" "$HISTORY_FILE"
}

setup_log() {
    if [[ "$ENABLE_LOG" -eq 1 ]]; then
        if [[ -z "$LOG_FILE" ]]; then
            LOG_FILE="$LOG_DIR/ytdl_$(date +%Y%m%d_%H%M%S).log"
        fi

        mkdir -p "$(dirname "$LOG_FILE")"
        : > "$LOG_FILE" || die "Cannot write log file: $LOG_FILE"

        log_msg "=================================================="
        log_msg "ytdl started at $(date)"
        log_msg "mode: inbox"
        log_msg "log: $LOG_FILE"
        log_msg "=================================================="
    fi
}

trim_line() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

tsv_escape() {
    local s="$1"
    s="${s//$'\t'/ }"
    s="${s//$'\n'/ }"
    s="${s//$'\r'/ }"
    printf '%s' "$s"
}

is_known_section() {
    local s="$1"
    local x

    for x in "${SECTIONS[@]}"; do
        [[ "$x" == "$s" ]] && return 0
    done

    return 1
}

write_clean_inbox() {
    {
        echo "[video]"
        echo
        echo "[video-mp4]"
        echo
        echo "[video-subtitles]"
        echo
        echo "[video-playlist]"
        echo
        echo "[video-clips]"
        echo
        echo "[audio]"
        echo
        echo "[audio-playlist]"
        echo
        echo "[audio-channel]"
        echo
        echo "[music]"
        echo
        echo "[music-search]"
        echo
        echo "[chapters]"
        echo
    } > "$INBOX_FILE"
}

find_default_firefox_profile() {
    [[ -f "$FIREFOX_PROFILES_INI" ]] || die "Firefox profiles.ini not found: $FIREFOX_PROFILES_INI"

    local install_default=""
    local profile_default=""
    local first_with_cookies=""

    install_default="$(
        awk -F= '
            /^\[Install/ { in_install=1; next }
            /^\[/ { in_install=0; next }
            in_install && $1 == "Default" { print $2; exit }
        ' "$FIREFOX_PROFILES_INI"
    )"

    if [[ -n "$install_default" && -f "$FIREFOX_ROOT/$install_default/cookies.sqlite" ]]; then
        printf '%s\n' "$install_default"
        return 0
    fi

    profile_default="$(
        awk -F= '
            /^\[Profile[0-9]+\]$/ {
                if (in_profile && def == "1" && path != "") { print path; exit }
                in_profile=1; path=""; def="0"; next
            }
            /^\[/ {
                if (in_profile && def == "1" && path != "") { print path; exit }
                in_profile=0; next
            }
            in_profile && $1 == "Path" { path=$2 }
            in_profile && $1 == "Default" && $2 == "1" { def="1" }
            END { if (in_profile && def == "1" && path != "") { print path } }
        ' "$FIREFOX_PROFILES_INI" | tail -n 1
    )"

    if [[ -n "$profile_default" && -f "$FIREFOX_ROOT/$profile_default/cookies.sqlite" ]]; then
        printf '%s\n' "$profile_default"
        return 0
    fi

    first_with_cookies="$(
        find "$FIREFOX_ROOT" -mindepth 2 -maxdepth 2 -name cookies.sqlite -printf '%h\n' 2>/dev/null \
            | sed "s#^$FIREFOX_ROOT/##" \
            | head -n 1
    )"

    if [[ -n "$first_with_cookies" ]]; then
        printf '%s\n' "$first_with_cookies"
        return 0
    fi

    return 1
}

ensure_firefox_profile() {
    FIREFOX_PROFILE_PATH="$(find_default_firefox_profile)"

    [[ -n "$FIREFOX_PROFILE_PATH" ]] || die "Could not detect default Firefox profile"

    if [[ ! -f "$FIREFOX_ROOT/$FIREFOX_PROFILE_PATH/cookies.sqlite" ]]; then
        die "cookies.sqlite not found in Firefox profile: $FIREFOX_ROOT/$FIREFOX_PROFILE_PATH"
    fi

    log_msg "Firefox profile: $FIREFOX_PROFILE_PATH"
}

update_docker_images() {
    log_msg "Checking latest Docker images..."

    log_msg "Image: $YTDLP_IMAGE"
    docker pull "$YTDLP_IMAGE" || die "Failed to pull $YTDLP_IMAGE"

    log_msg "Image: $POT_IMAGE"
    docker pull "$POT_IMAGE" || die "Failed to pull $POT_IMAGE"
}

start_bgutil_pot_server() {
    log_msg "Starting bgutil-pot server..."

    docker rm -f "$POT_CONTAINER" >/dev/null 2>&1 || true

    docker run -d \
        --name "$POT_CONTAINER" \
        --restart unless-stopped \
        --network host \
        -e HTTP_PROXY="$PROXY_URL" \
        -e HTTPS_PROXY="$PROXY_URL" \
        -e ALL_PROXY="$PROXY_URL" \
        -e NO_PROXY="127.0.0.1,localhost" \
        "$POT_IMAGE" \
        server --host 127.0.0.1 --port 4416 >/dev/null

    sleep 2

    if ! curl -fsS "$POT_URL/ping" >/dev/null 2>&1; then
        echo "bgutil-pot logs:" >&2
        docker logs --tail=80 "$POT_CONTAINER" >&2 || true
        die "bgutil-pot server did not start correctly"
    fi

    log_msg "bgutil-pot server started: $POT_URL"
}

ensure_bgutil_pot_server() {
    update_docker_images

    # Recreate container after pull: docker pull updates the image, not an already-running container.
    log_msg "Recreating bgutil-pot server after image check..."
    start_bgutil_pot_server
}

run_ytdlp_capture_with_extractor() {
    local extractor_args="$1"
    shift

    [[ -n "${RUN_OUTPUT_FILE:-}" && -f "${RUN_OUTPUT_FILE:-}" ]] && rm -f -- "$RUN_OUTPUT_FILE"
    RUN_OUTPUT_FILE="$(mktemp "${TMPDIR:-/tmp}/ytdl_output.XXXXXX")"

    log_msg "yt-dlp route: $extractor_args"
    log_msg "yt-dlp progress: enabled (--newline --progress)"

    if [[ "$ENABLE_LOG" -eq 1 ]]; then
        docker run --rm \
            --network host \
            --user "$(id -u):$(id -g)" \
            -v "$FIREFOX_ROOT:/firefox:ro" \
            -v "$BASE_DIR:/downloads" \
            -w /downloads \
            "$YTDLP_IMAGE" \
            --ignore-config \
            --proxy "$PROXY_URL" \
            --cookies-from-browser "firefox:/firefox/$FIREFOX_PROFILE_PATH" \
            --extractor-args "$extractor_args" \
            --newline \
            --progress \
            "$@" \
            2>&1 | tee -a "$LOG_FILE" | tee "$RUN_OUTPUT_FILE"

        return "${PIPESTATUS[0]}"
    else
        docker run --rm \
            --network host \
            --user "$(id -u):$(id -g)" \
            -v "$FIREFOX_ROOT:/firefox:ro" \
            -v "$BASE_DIR:/downloads" \
            -w /downloads \
            "$YTDLP_IMAGE" \
            --ignore-config \
            --proxy "$PROXY_URL" \
            --cookies-from-browser "firefox:/firefox/$FIREFOX_PROFILE_PATH" \
            --extractor-args "$extractor_args" \
            --newline \
            --progress \
            "$@" \
            2>&1 | tee "$RUN_OUTPUT_FILE"

        return "${PIPESTATUS[0]}"
    fi
}

run_ytdlp_capture() {
    # Metadata/default route.
    run_ytdlp_capture_with_extractor \
        "youtube:player_client=default,mweb,-android_sdkless;youtubepot-bgutilhttp:base_url=$POT_URL" \
        "$@"
}

ytdlp_last_error_was_forbidden() {
    [[ -n "${RUN_OUTPUT_FILE:-}" && -f "$RUN_OUTPUT_FILE" ]] || return 1
    grep -Eqi 'HTTP Error 403|Forbidden' "$RUN_OUTPUT_FILE"
}

ytdlp_last_error_was_network_failure() {
    [[ -n "${RUN_OUTPUT_FILE:-}" && -f "$RUN_OUTPUT_FILE" ]] || return 1

    # Only transient/global connectivity-style errors belong here.
    # Deliberately do NOT classify ordinary video-specific failures such as
    # private/unavailable/copyright/age-restricted videos as network failures.
    grep -Eqi \
        'Unable to download API page|Unable to download webpage|Unable to download player API JSON|\
Temporary failure in name resolution|Name or service not known|Could not resolve host|\
Network is unreachable|No route to host|Connection reset by peer|Connection refused|\
Connection aborted|Remote end closed connection|Read timed out|Connection timed out|\
timed out after|TimeoutError|ConnectTimeout|ReadTimeout|\
ProxyError|proxy error|Unable to connect to proxy|Tunnel connection failed|\
Failed to establish a new connection|Max retries exceeded|\
HTTP Error 502|HTTP Error 503|HTTP Error 504|Bad Gateway|Service Unavailable|Gateway Time-out|Gateway Timeout|\
SSL: WRONG_VERSION_NUMBER|SSL.*EOF|TLS.*failed|\
curl: \(5\)|curl: \(6\)|curl: \(7\)|curl: \(28\)' \
        "$RUN_OUTPUT_FILE"
}

normalize_ytdlp_rc() {
    local rc="$1"

    if [[ "$rc" -ne 0 ]] && ytdlp_last_error_was_network_failure; then
        return "$RC_SEARCH_FAILURE"
    fi

    return "$rc"
}

show_recent_partials() {
    local found

    found="$(
        find "$BASE_DIR" -type f -name "*.part" -printf '  %TY-%Tm-%Td %TH:%TM %10s bytes  %p\n' 2>/dev/null \
            | sort \
            | tail -n 10 \
            || true
    )"

    if [[ -n "$found" ]]; then
        log_msg "Recent partial files:"
        while IFS= read -r line; do
            log_msg "$line"
        done <<< "$found"
    else
        log_msg "Recent partial files: none"
    fi
}

run_video_download_routes() {
    local hls_format="$1"
    local normal_format="$2"
    shift 2
    local rc

    log_msg "Route order: HLS/iOS primary -> DASH mweb fallback -> DASH tv/mweb fallback"

    run_ytdlp_capture_with_extractor \
        "youtube:player_client=default,ios,-android_sdkless;formats=missing_pot;youtubepot-bgutilhttp:base_url=$POT_URL" \
        -f "$hls_format" \
        "$@"
    rc=$?
    [[ "$rc" -eq 0 ]] && return 0

    if ytdlp_last_error_was_forbidden; then
        log_msg "WARNING: HLS/iOS route returned 403/Forbidden. Trying DASH mweb fallback."
    else
        log_msg "WARNING: HLS/iOS route failed with rc=$rc. Trying DASH mweb fallback."
	fi

    run_ytdlp_capture_with_extractor \
        "youtube:player_client=default,mweb,-android_sdkless;youtubepot-bgutilhttp:base_url=$POT_URL" \
        -f "$normal_format" \
        "$@"
    rc=$?
    [[ "$rc" -eq 0 ]] && return 0

    if ytdlp_last_error_was_forbidden; then
        log_msg "WARNING: DASH mweb route returned 403/Forbidden. Trying DASH tv/mweb fallback."
    else
        log_msg "WARNING: DASH mweb route failed with rc=$rc. Trying DASH tv/mweb fallback."
    fi

    run_ytdlp_capture_with_extractor \
        "youtube:player_client=tv,mweb;youtubepot-bgutilhttp:base_url=$POT_URL" \
        -f "$normal_format" \
        "$@"
    rc=$?

    return "$rc"
}


contains_cyrillic() {
    local s="$1"
    [[ "$s" =~ [А-Яа-яЁё] ]]
}

build_video_clip_query() {
    local item="$1"
    local mode="$2"

    if contains_cyrillic "$item"; then
        if [[ "$mode" == "remaster" ]]; then
            printf '%s клип 4K remastered' "$item"
        else
            printf '%s клип' "$item"
        fi
    else
        if [[ "$mode" == "remaster" ]]; then
            printf '%s 4K remastered music video' "$item"
        else
            printf '%s official music video' "$item"
        fi
    fi
}

title_has_cjk_hangul_or_indic() {
    local title="$1"

    python3 - "$title" <<'PY'
import sys
s = sys.argv[1]

def special(ch):
    cp = ord(ch)
    return (
        # Japanese
        0x3040 <= cp <= 0x309F or
        0x30A0 <= cp <= 0x30FF or
        0x31F0 <= cp <= 0x31FF or

        # Chinese/CJK ideographs
        0x3400 <= cp <= 0x4DBF or
        0x4E00 <= cp <= 0x9FFF or
        0xF900 <= cp <= 0xFAFF or

        # Korean
        0x1100 <= cp <= 0x11FF or
        0x3130 <= cp <= 0x318F or
        0xAC00 <= cp <= 0xD7AF or

        # Major Indic scripts
        0x0900 <= cp <= 0x097F or   # Devanagari
        0x0980 <= cp <= 0x09FF or   # Bengali / Assamese
        0x0A00 <= cp <= 0x0A7F or   # Gurmukhi
        0x0A80 <= cp <= 0x0AFF or   # Gujarati
        0x0B00 <= cp <= 0x0B7F or   # Odia
        0x0B80 <= cp <= 0x0BFF or   # Tamil
        0x0C00 <= cp <= 0x0C7F or   # Telugu
        0x0C80 <= cp <= 0x0CFF or   # Kannada
        0x0D00 <= cp <= 0x0D7F      # Malayalam
    )

sys.exit(0 if any(special(ch) for ch in s) else 1)
PY
}

sanitize_clip_prefix() {
    local text="$1"

    python3 - "$text" <<'PY'
import re
import sys

s = sys.argv[1]
s = s.replace("/", "⧸").replace("\\", "⧹").replace("%", "％")
s = "".join(ch for ch in s if ord(ch) >= 32 and ord(ch) != 127)
s = re.sub(r"\s+", " ", s).strip()
print(s[:180])
PY
}

classify_video_clip_reject() {
    local item="$1"
    local title="$2"
    local uploader="$3"

    python3 - "$item" "$title" "$uploader" <<'PY'
import re
import sys
import unicodedata

item, title, uploader = sys.argv[1:4]
t = title.casefold()
u = uploader.casefold()
src = item.casefold()

def norm(s):
    s = unicodedata.normalize("NFKD", s)
    trans = str.maketrans({
        "ø": "o", "Ø": "O",
        "đ": "d", "Đ": "D",
        "ł": "l", "Ł": "L",
        "ß": "ss",
        "$": "s",
        "&": " and ",
        "×": " x ",
        "＊": " ",
    })
    s = s.translate(trans)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = s.casefold()
    s = re.sub(r"[^a-z0-9\u0400-\u052f\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()

def contains_any(patterns):
    return any(re.search(p, t, flags=re.IGNORECASE) for p in patterns)

# ------------------------------------------------------------------
# Strong non-MV filters
# ------------------------------------------------------------------

# Topic/autogenerated audio channels
if u.endswith(" - topic") or u == "topic" or " topic【" in u:
    print("audio")
    raise SystemExit

# Lyrics / subtitles / textual versions
if contains_any([
    r"\blyrics?\b",
    r"\blyric video\b",
    r"\blyrical\b",
    r"\blyrical video\b",
    r"\blyrical song\b",
    r"\bcolor coded\b",
    r"\bcolour coded\b",
    r"\bhan/rom/eng\b",
    r"\bkan/rom/eng\b",
    r"\bromaji\b",
    r"\blegendado\b",
    r"\btradu(?:ção|cao)\b",
    r"\bsub(?:bed|titles?)?\b",
    r"\bsub español\b",
    r"\benglish translation\b",
]):
    print("lyrics")
    raise SystemExit

# Audio/static-image style uploads
if contains_any([
    r"\bofficial audio\b",
    r"\bremastered audio\b",
    r"\baudio version\b",
    r"\baudio track\b",
    r"\balbum audio\b",
    r"\baudio only\b",
    r"\bfull audio\b",
    r"\baudio jukebox\b",
    r"\bhq audio\b",
    r"\baudio visuali[sz]er\b",
    r"\baudio\b",
]):
    # permit wording like "enhanced video and audio" only when there is explicit MV/video context
    if not re.search(r"\b(?:official )?(?:music )?video\b|\bmv\b|\bm/v\b", t, flags=re.IGNORECASE):
        print("audio")
        raise SystemExit

# Visualizer
if contains_any([
    r"\bvisuali[sz]er\b",
]):
    print("visualizer")
    raise SystemExit

# Fancam / audience-camera / individual-cam markers
if contains_any([
    r"\bfancam\b",
    r"\bfan cam\b",
    r"\bfocus cam\b",
    r"\bfocuscam\b",
    r"\bcam ver(?:sion)?\b",
    r"\bconcert cam\b",
    r"\bfestival cam\b",
    r"직캠",
]):
    print("fancam")
    raise SystemExit

# Live-location markers: reject, but track separately in summary.
live_location_patterns = [
    (r"\blive\s+at\b", "live at"),
    (r"\blive\s+from\b", "live from"),
    (r"\blive\s+in\b", "live in"),
    (r"\blive\s+on\b", "live on"),
    (r"\blive\s*@", "live @"),
]
for pat, label in live_location_patterns:
    if re.search(pat, t, flags=re.IGNORECASE) and label not in src:
        print("live-location:" + label)
        raise SystemExit

# Hard live/performance/event filters
hard_live_patterns = [
    r"\blive performance\b",
    r"\blive version\b",
    r"\blive session\b",
    r"\blive concert\b",
    r"\bofficial live video\b",
    r"\blive clip\b",
    r"\blive set\b",
    r"\bfull set\b",
    r"\bconcert\b",
    r"\btour\b",
    r"\bfestival\b",
    r"\bstage\b",
    r"\bspecial stage\b",
    r"\bshowcase\b",
    r"\baward show\b",
    r"\bmusic show\b",
    r"\bhalftime show\b",
    r"\bsuper bowl\b",
    r"\baward(?:s)?\b",
    r"\baward performance\b",
    r"\bmusic awards\b",
    r"\blive with\b",
    r"\blive film\b",
    r"\blive film ver(?:sion)?\b",
    r"\blive lounge\b",
    r"\bbudokan\b",
    r"\barena\b",
    r"\bstadium\b",
    r"\bstadion\b",
    r"\bstade de france\b",
    r"\bbercy\b",
    r"\bsession\b",
    r"\bcoachella\b",
    r"\bglastonbury\b",
    r"\blollapalooza\b",
    r"\bkcon\b",
    r"\bmama\b",
    r"\bmadison square garden\b",
    r"\bwembley\b",
    r"\bhitc\b",
    r"\blive\s+(?:19|20)\d{2}\b",
]
if contains_any(hard_live_patterns):
    print("live-hard")
    raise SystemExit

# Performance wording such as "Artist performs Track..." catches concert clips
if contains_any([
    r"\bperform\b",
    r"\bperforms\b",
    r"\bperformed\b",
    r"\bperforming\b",
    r"\bperformance at\b",
    r"\bperformance from\b",
    r"\bperformance on\b",
]):
    if not re.search(r"\bofficial (?:music )?video\b|\bmv\b|\bm/v\b", t, flags=re.IGNORECASE):
        print("performance")
        raise SystemExit

# Strong live markers at end of title
tail_live_patterns = [
    r"(?:\(|\[)\s*live\s*(?:\)|\])\s*$",
    r"(?:-|–|—|\|)\s*live\s*$",
    r"\blive\s*$",
]
if any(re.search(p, t, flags=re.IGNORECASE) for p in tail_live_patterns):
    if not re.search(r"\blive\s*$", src, flags=re.IGNORECASE):
        print("live-hard")
        raise SystemExit

# Other obvious junk/non-original variants
rules = [
    ("teaser", [
        r"\bteaser\b",
        r"\bmv teaser\b",
        r"\bm/v teaser\b",
    ]),
    ("trailer", [
        r"\btrailer\b",
    ]),
    ("reaction", [
        r"\breaction\b",
        r"\breacts?\b",
        r"\bfirst time hearing\b",
    ]),
    ("other", [
        r"\bacceptance speech\b",
        r"\baward speech\b",
        r"\bdj remix\b",
        r"\brecreated\b",
        r"\brecreation\b",
        r"\bnew version\b",
        r"\b(?:russian|english|spanish|german|french|italian|portuguese|korean|japanese)\s+version\b",
        r"\b(?:russian|english|spanish|german|french|italian|portuguese|korean|japanese)\s+ver\.?\b",
        r"\bmaking of\b",
        r"\bbehind the scenes\b",
        r"\blp\s*rip\b",
        r"\bvinyl\s*rip\b",
        r"\bvinyl\s*transfer\b",
        r"\bneedle\s*drop\b",
        r"\beaster eggs?\b",
        r"\bexplained\b",
        r"\bbreakdown\b",
        r"\bvideo essay\b",
        r"\bdocumentary\b",
        r"\binterview\b",
        r"\bnews report\b",
        r"\breportage\b",
        r"\blo[\s-]?fi\b",
        r"\bslowed(?:\s*\+\s*reverb|\s+and\s+reverb)?\b",
        r"\breverb\b",
        r"\bjhankar\b",
        r"\breverse\b",
        r"\breversed\b",
        r"\bmeme\b",
        r"\bmemes\b",
        r"\bmashup\b",
        r"\bfan edit\b",
        r"\bedit audio\b",
        r"\bdance cover\b",
        r"\bcover\b",
        r"\bkaraoke\b",
    ]),
]
for category, patterns in rules:
    if any(re.search(p, t, flags=re.IGNORECASE) for p in patterns):
        print(category)
        raise SystemExit

# ------------------------------------------------------------------
# Strict relevance: artist AND track must both match sufficiently.
# ------------------------------------------------------------------
if " - " in item:
    req_artist, req_track = item.split(" - ", 1)
else:
    req_artist, req_track = item, ""

cand_title_n = norm(title)
cand_uploader_n = norm(uploader)
cand_all = norm(title + " " + uploader)
artist_n = norm(req_artist)
track_n = norm(req_track)

artist_stop = {
    "feat", "featuring", "ft", "and", "x", "with", "the",
}
track_stop = {
    "official", "video", "music", "remastered", "remaster",
    "feat", "featuring", "with", "version", "full", "song",
}

def meaningful_tokens(s, stop):
    # preserve order, but deduplicate repeated words such as ME!ME!ME!
    out = []
    seen = set()
    for tok in norm(s).split():
        if tok in stop or not (len(tok) >= 2 or tok.isdigit()):
            continue
        if tok not in seen:
            out.append(tok)
            seen.add(tok)
    return out

def token_present(tok, hay):
    return re.search(rf"(?<![a-z0-9]){re.escape(tok)}(?![a-z0-9])", hay) is not None

def compact(s):
    return re.sub(r"[^a-z0-9\u0400-\u052f\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+", "", norm(s))

# Explicit MV/video marker.
official_marker = re.search(
    r"\bofficial (?:music )?video\b|\bofficial mv\b|\bm/v\b|\bmv\b|ミュージックビデオ",
    t,
    flags=re.IGNORECASE,
)

# ------------------------------------------------------------------
# Artist matching
# ------------------------------------------------------------------
artist_tokens = meaningful_tokens(req_artist, artist_stop)
artist_match = False
artist_match_kind = ""

if artist_n and artist_n in cand_all:
    artist_match = True
    artist_match_kind = "full"
elif artist_tokens:
    hits = sum(1 for tok in artist_tokens if token_present(tok, cand_all))
    need = 1 if len(artist_tokens) == 1 else max(1, (len(artist_tokens) + 1) // 2)
    if hits >= need:
        artist_match = True
        artist_match_kind = "tokens"

# Hyphen/spacing spelling variants:
#   Cho Yong-pil == Cho Yongpil
#   Lee Sang-eun == Lee Sangeun
#
# Keep this conservative: a compact-only match is trusted only when the
# candidate explicitly looks like an MV/video, or when uploader itself
# compact-matches the requested artist.
if not artist_match:
    req_artist_compact = compact(req_artist)
    title_compact = compact(title)
    uploader_compact = compact(uploader)
    compact_hit_title = bool(req_artist_compact and req_artist_compact in title_compact)
    compact_hit_uploader = bool(req_artist_compact and req_artist_compact in uploader_compact)

    if compact_hit_uploader or (compact_hit_title and official_marker):
        artist_match = True
        artist_match_kind = "compact"

# ------------------------------------------------------------------
# Track matching
# Parenthetical parts are aliases/alternate names:
#   Monster (Kaibutsu) -> Monster OR Kaibutsu
# rather than requiring both words.
# ------------------------------------------------------------------
raw_track = req_track.strip()
paren_aliases = [x.strip() for x in re.findall(r"\(([^()]*)\)", raw_track) if x.strip()]
base_track = re.sub(r"\([^()]*\)", " ", raw_track).strip()

track_variants = []
for variant in [base_track] + paren_aliases + [raw_track]:
    vn = norm(variant)
    if vn and vn not in track_variants:
        track_variants.append(vn)

track_match = False
matched_track_variant = ""
matched_track_tokens = []

for variant_n in track_variants:
    tokens = meaningful_tokens(variant_n, track_stop)
    if not tokens:
        continue

    # Exact normalized phrase first.
    if variant_n in cand_title_n:
        track_match = True
        matched_track_variant = variant_n
        matched_track_tokens = tokens
        break

    hits = sum(1 for tok in tokens if token_present(tok, cand_title_n))
    total = len(tokens)

    if total == 1:
        need = 1
    elif total == 2:
        need = 2
    elif total == 3:
        need = 2
    else:
        need = max(3, (total * 3 + 3) // 4)

    if hits >= need:
        track_match = True
        matched_track_variant = variant_n
        matched_track_tokens = tokens
        break

# Conservative transliteration fallback.
# If artist spelling is completely different (e.g. Cyrillic source vs Latin
# official distribution title), allow it only when:
#   - the track is an exact long phrase (>=3 meaningful words),
#   - title is structurally "Artist - exact track",
#   - uploader looks like an official/distribution channel.
trusted_uploader = bool(re.search(
    r"\bofficial\b|\bvevo\b|\bthe orchard\b|\bradial\b|\bsony music\b|"
    r"\bwarner\b|\buniversal\b|\bumg\b|\bavex\b|\bvictor entertainment\b",
    u,
    flags=re.IGNORECASE,
))

long_exact_track = False
for variant_n in track_variants:
    toks = meaningful_tokens(variant_n, track_stop)
    if len(toks) >= 3 and variant_n and variant_n in cand_title_n:
        long_exact_track = True
        break

structured_title = bool(re.search(r"\s[-–—|]\s", title))

if not artist_match and track_match and long_exact_track and structured_title and trusted_uploader:
    artist_match = True
    artist_match_kind = "trusted-transliteration"

if not artist_match:
    print("relevance-artist")
    raise SystemExit

if not track_match:
    # Single-word official MV exception remains useful for non-Latin titles.
    all_track_tokens = meaningful_tokens(raw_track, track_stop)
    if not (len(all_track_tokens) == 1 and official_marker and artist_match):
        print("relevance-track")
        raise SystemExit

print("")
PY
}

record_live_location_reject() {
    local item="$1"
    local label="$2"

    local key="${item}|${label}"

    if [[ -z "${CLIP_LIVE_LOCATION_SEEN[$key]+x}" ]]; then
        CLIP_LIVE_LOCATION_SEEN["$key"]=1
        CLIP_LIVE_LOCATION_ITEMS+=("$item [$label]")
    fi
}

increment_clip_reject_counter() {
    local category="$1"
    local item="${2:-}"
    local live_label=""

    case "$category" in
        lyrics)
            CLIP_REJECT_LYRICS=$((CLIP_REJECT_LYRICS + 1))
            ;;
        live-hard)
            CLIP_REJECT_LIVE_HARD=$((CLIP_REJECT_LIVE_HARD + 1))
            ;;
        live-location:*)
            CLIP_REJECT_LIVE_LOCATION=$((CLIP_REJECT_LIVE_LOCATION + 1))
            live_label="${category#live-location:}"
            [[ -n "$item" ]] && record_live_location_reject "$item" "$live_label"
            ;;
        teaser)
            CLIP_REJECT_TEASER=$((CLIP_REJECT_TEASER + 1))
            ;;
        trailer)
            CLIP_REJECT_TRAILER=$((CLIP_REJECT_TRAILER + 1))
            ;;
        reaction)
            CLIP_REJECT_REACTION=$((CLIP_REJECT_REACTION + 1))
            ;;
        audio)
            CLIP_REJECT_AUDIO=$((CLIP_REJECT_AUDIO + 1))
            ;;
        visualizer)
            CLIP_REJECT_VISUALIZER=$((CLIP_REJECT_VISUALIZER + 1))
            ;;
        relevance|relevance-artist|relevance-track)
            CLIP_REJECT_RELEVANCE=$((CLIP_REJECT_RELEVANCE + 1))
            if [[ "$category" == "relevance-artist" ]]; then
                CLIP_REJECT_RELEVANCE_ARTIST=$((CLIP_REJECT_RELEVANCE_ARTIST + 1))
            elif [[ "$category" == "relevance-track" ]]; then
                CLIP_REJECT_RELEVANCE_TRACK=$((CLIP_REJECT_RELEVANCE_TRACK + 1))
            fi
            ;;
        fancam)
            CLIP_REJECT_FANCAM=$((CLIP_REJECT_FANCAM + 1))
            ;;
        performance)
            CLIP_REJECT_PERFORMANCE=$((CLIP_REJECT_PERFORMANCE + 1))
            ;;
        other|fallback-no-video-evidence)
            CLIP_REJECT_OTHER=$((CLIP_REJECT_OTHER + 1))
            ;;
    esac
}


fallback_video_clip_has_positive_evidence() {
    local item="$1"
    local title="$2"
    local uploader="$3"

    python3 - "$item" "$title" "$uploader" <<'PY'
import re
import sys
import unicodedata

item, title, uploader = sys.argv[1:4]

def norm(s):
    s = unicodedata.normalize("NFKD", s)
    trans = str.maketrans({
        "ø": "o", "Ø": "O", "đ": "d", "Đ": "D",
        "ł": "l", "Ł": "L", "ß": "ss", "$": "s",
        "&": " and ", "×": " x ",
    })
    s = s.translate(trans)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = s.casefold()
    s = re.sub(r"[^a-z0-9\u0400-\u052f\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()

def compact(s):
    return re.sub(r"[^a-z0-9\u0400-\u052f\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+", "", norm(s))

t = title.casefold()
u = uploader.casefold()

# Strong title evidence that this is actually a music video or an enhanced MV.
video_marker = bool(re.search(
    r"\bofficial (?:music )?video\b|"
    r"\bmusic video\b|"
    r"\bofficial mv\b|"
    r"\bm/v\b|"
    r"(?<![a-z0-9])mv(?![a-z0-9])|"
    r"ミュージックビデオ|"
    r"\bvideo clip\b",
    t,
    flags=re.I,
))

enhancement_marker = bool(re.search(
    r"\b(?:4k|8k|uhd|hdr|60fps|50fps|120fps|"
    r"remaster(?:ed)?|upscal(?:e|ed)|ai[- ]?upscale|restor(?:e|ed|ation))\b",
    t,
    flags=re.I,
))

# Known label/distributor/official ecosystems.
trusted_distribution = bool(re.search(
    r"\bvevo\b|\bthe orchard\b|\bradial\b|\bsony music\b|"
    r"\bwarner(?: music)?\b|\buniversal(?: music)?\b|\bumg\b|"
    r"\bavex\b|\bvictor entertainment\b|\bemi\b|\bparlophone\b|"
    r"\bcolumbia records\b|\batlantic records\b|\brepublic records\b|"
    r"\binterscope\b|\bcapitol records\b",
    u,
    flags=re.I,
))

# Artist's own channel is also strong evidence. Keep this conservative:
# normalized or compact requested artist must actually occur in uploader.
req_artist = item.split(" - ", 1)[0].strip() if " - " in item else item.strip()
artist_uploader_match = False
if req_artist:
    ra = norm(req_artist)
    ua = norm(uploader)
    rc = compact(req_artist)
    uc = compact(uploader)
    if ra and ra in ua:
        artist_uploader_match = True
    elif rc and len(rc) >= 4 and rc in uc:
        artist_uploader_match = True

ok = video_marker or enhancement_marker or trusted_distribution or artist_uploader_match
raise SystemExit(0 if ok else 1)
PY
}

search_video_clip_candidates() {
    local item="$1"
    local mode="$2"
    local query
    local rc
    local line
    local cid
    local ctitle
    local cuploader
    local reject_category
    local display_category
    local n=0

    local search_limit=10

    if [[ "$mode" == "fallback" ]]; then
        # Broad exact-ish fallback. Do not add "official music video" or remaster
        # wording here; let the classifier decide among a larger result pool.
        query="$item"
        search_limit=20
        log_msg "Video clip search C (fallback, 20 results): $query"
    else
        query="$(build_video_clip_query "$item" "$mode")"
        if [[ "$mode" == "remaster" ]]; then
            log_msg "Video clip search A (4K/remaster): $query"
        else
            log_msg "Video clip search B (normal): $query"
        fi
    fi

    run_ytdlp_capture \
        --flat-playlist \
        --skip-download \
        --no-warnings \
        --playlist-end "$search_limit" \
        --print $'YTDL_CANDIDATE\t%(id)s\t%(title)s\t%(uploader)s' \
        "ytsearch${search_limit}:$query" >/dev/null
    rc=$?

    if [[ "$rc" -ne 0 ]]; then
        log_msg "  Search/API/network failure: rc=$rc"
        rm -f "${RUN_OUTPUT_FILE:-}"
        return "$RC_SEARCH_FAILURE"
    fi

    while IFS= read -r line; do
        [[ "$line" == YTDL_CANDIDATE$'\t'* ]] || continue

        IFS=$'\t' read -r _ cid ctitle cuploader <<< "$line"
        n=$((n + 1))

        [[ -n "$cid" ]] || continue
        [[ -n "$ctitle" ]] || continue

        reject_category="$(classify_video_clip_reject "$item" "$ctitle" "$cuploader")"

        # Remaster search should not become a generic "first acceptable song by artist" search.
        # Prefer titles that actually look remastered/upscaled/high-quality, but still allow
        # a clearly matching official MV if YouTube ranks it first.
        if [[ -z "$reject_category" && "$mode" == "remaster" ]]; then
            if ! python3 - "$ctitle" <<'PY'
import re, sys
t = sys.argv[1].casefold()
ok = bool(re.search(
    r"\b(?:4k|8k|60fps|50fps|120fps|hdr|remaster(?:ed)?|upscal(?:e|ed)|ai[- ]?upscale|uhd|qhd)\b"
    r"|\bofficial (?:music )?video\b|\bofficial mv\b|\bm/v\b|\bmv\b",
    t,
    flags=re.I,
))
raise SystemExit(0 if ok else 1)
PY
            then
                reject_category="relevance-track"
            fi
        fi

        # Search C is intentionally broader, so it must be STRICTER at acceptance.
        # Artist+track relevance alone is not enough. Require positive evidence:
        # real MV/video wording, enhanced/remastered-video wording, artist's own
        # uploader, or a known label/distributor.
        if [[ -z "$reject_category" && "$mode" == "fallback" ]]; then
            if ! fallback_video_clip_has_positive_evidence "$item" "$ctitle" "$cuploader"; then
                reject_category="fallback-no-video-evidence"
            fi
        fi

        if [[ -n "$reject_category" ]]; then
            increment_clip_reject_counter "$reject_category" "$item"
            display_category="$reject_category"
            [[ "$display_category" == live-location:* ]] && display_category="live-location (${display_category#live-location:})"
            log_msg "  Candidate #$n: REJECT [$display_category] $ctitle"
            continue
        fi

        CLIP_SELECTED_ID="$cid"
        CLIP_SELECTED_TITLE="$ctitle"
        CLIP_SELECTED_UPLOADER="$cuploader"
        CLIP_SELECTED_URL="https://www.youtube.com/watch?v=$cid"
        CLIP_SELECTED_SEARCH_MODE="$mode"

        log_msg "  Candidate #$n: ACCEPT $ctitle"
        [[ -n "$cuploader" ]] && log_msg "  Channel: $cuploader"
        log_msg "  URL: $CLIP_SELECTED_URL"

        rm -f "$RUN_OUTPUT_FILE"
        return 0
    done < "$RUN_OUTPUT_FILE"

    rm -f "$RUN_OUTPUT_FILE"
    log_msg "  No acceptable candidate among first $search_limit results."
    return 1
}

find_video_clip_variants() {
    local item="$1"
    local search_rc=0
    local remaster_search_failed=0
    local normal_search_failed=0

    CLIP_REMASTER_URL=""
    CLIP_REMASTER_ID=""
    CLIP_REMASTER_TITLE=""
    CLIP_REMASTER_UPLOADER=""

    CLIP_NORMAL_URL=""
    CLIP_NORMAL_ID=""
    CLIP_NORMAL_TITLE=""
    CLIP_NORMAL_UPLOADER=""

    CLIP_SAFE_INPUT="$(sanitize_clip_prefix "$item")"

    CLIP_SELECTED_URL=""
    CLIP_SELECTED_ID=""
    CLIP_SELECTED_TITLE=""
    CLIP_SELECTED_UPLOADER=""
    CLIP_SELECTED_SEARCH_MODE=""

    search_video_clip_candidates "$item" "remaster"
    search_rc=$?
    if [[ "$search_rc" -eq 0 ]]; then
        CLIP_REMASTER_URL="$CLIP_SELECTED_URL"
        CLIP_REMASTER_ID="$CLIP_SELECTED_ID"
        CLIP_REMASTER_TITLE="$CLIP_SELECTED_TITLE"
        CLIP_REMASTER_UPLOADER="$CLIP_SELECTED_UPLOADER"
    elif [[ "$search_rc" -eq "$RC_SEARCH_FAILURE" ]]; then
        remaster_search_failed=1
    fi

    CLIP_SELECTED_URL=""
    CLIP_SELECTED_ID=""
    CLIP_SELECTED_TITLE=""
    CLIP_SELECTED_UPLOADER=""
    CLIP_SELECTED_SEARCH_MODE=""

    search_video_clip_candidates "$item" "normal"
    search_rc=$?
    if [[ "$search_rc" -eq 0 ]]; then
        CLIP_NORMAL_URL="$CLIP_SELECTED_URL"
        CLIP_NORMAL_ID="$CLIP_SELECTED_ID"
        CLIP_NORMAL_TITLE="$CLIP_SELECTED_TITLE"
        CLIP_NORMAL_UPLOADER="$CLIP_SELECTED_UPLOADER"
    elif [[ "$search_rc" -eq "$RC_SEARCH_FAILURE" ]]; then
        normal_search_failed=1
    fi

    # A broken search means we cannot know whether a good candidate exists.
    # Treat it as infrastructure/network failure, not "not found".
    if [[ "$remaster_search_failed" -eq 1 || "$normal_search_failed" -eq 1 ]]; then
        log_msg "VIDEO CLIP SEARCH FAILURE: $item"
        log_msg "  remaster search failed: $remaster_search_failed"
        log_msg "  normal search failed:   $normal_search_failed"
        return "$RC_SEARCH_FAILURE"
    fi

    # If both normal searches produced no acceptable candidate, try one broader
    # 20-result search before declaring the item genuinely not found.
    if [[ -z "$CLIP_REMASTER_ID" && -z "$CLIP_NORMAL_ID" ]]; then
        CLIP_SELECTED_URL=""
        CLIP_SELECTED_ID=""
        CLIP_SELECTED_TITLE=""
        CLIP_SELECTED_UPLOADER=""
        CLIP_SELECTED_SEARCH_MODE=""

        search_video_clip_candidates "$item" "fallback"
        search_rc=$?

        if [[ "$search_rc" -eq 0 ]]; then
            CLIP_NORMAL_URL="$CLIP_SELECTED_URL"
            CLIP_NORMAL_ID="$CLIP_SELECTED_ID"
            CLIP_NORMAL_TITLE="$CLIP_SELECTED_TITLE"
            CLIP_NORMAL_UPLOADER="$CLIP_SELECTED_UPLOADER"
        elif [[ "$search_rc" -eq "$RC_SEARCH_FAILURE" ]]; then
            log_msg "VIDEO CLIP SEARCH FAILURE in fallback search: $item"
            return "$RC_SEARCH_FAILURE"
        fi
    fi

    if [[ -z "$CLIP_REMASTER_ID" && -z "$CLIP_NORMAL_ID" ]]; then
        CLIP_NOT_FOUND_ITEMS+=("$item")
        log_msg "VIDEO CLIP NOT FOUND: $item"
        return "$RC_CLIP_NOT_FOUND"
    fi

    return 0
}

cleanup_failed_clip_artifacts() {
    local safe_prefix="$1"
    local base="$BASE_DIR/video-clips"
    local prefix

    [[ -d "$base" ]] || return 0
    prefix="$safe_prefix - "

    # Only delete incomplete/intermediate files belonging to this inbox item.
    # Completed .mkv files are never touched.
    find "$base" -maxdepth 1 -type f \
        \( -name "${prefix}*.part" \
           -o -name "${prefix}*.temp.*" \
           -o -name "${prefix}*.f[0-9]*.*" \
           -o -name "${prefix}*.ytdl" \) \
        -print -delete 2>/dev/null || true
}


download_video_clip_variant() {
    local item="$1"
    local mode="$2"
    local clip_id="$3"
    local clip_title="$4"
    local clip_uploader="$5"
    local clip_url="$6"
    local clip_output_template
    local rc

    CLIP_SELECTED_ID="$clip_id"
    CLIP_SELECTED_TITLE="$clip_title"
    CLIP_SELECTED_UPLOADER="$clip_uploader"
    CLIP_SELECTED_URL="$clip_url"
    CLIP_SELECTED_SEARCH_MODE="$mode"

    # Always prefix with the canonical Artist - Track from inbox.
    # This prevents opaque names like "LIVWE.mkv" or "Latinoamerica.mkv".
    clip_output_template="video-clips/${CLIP_SAFE_INPUT} - %(title)s.%(ext)s"

    log_msg "Video clip download [$mode]:"
    log_msg "  Source   : $item"
    log_msg "  Selected : $clip_title"
    [[ -n "$clip_uploader" ]] && log_msg "  Channel  : $clip_uploader"
    log_msg "  URL      : $clip_url"
    log_msg "  Max res  : 1080p"

    run_video_download_routes \
        "bv[height<=1080][protocol=m3u8_native]+ba[protocol=m3u8_native]/b[height<=1080][protocol=m3u8_native]/bv[height<=1080]+ba/b[height<=1080]" \
        "bv*[height<=1080]+ba/b[height<=1080]" \
        --download-archive "/downloads/.state/archives/video_clips.txt" \
        --add-metadata \
        --embed-metadata \
        --embed-chapters \
        --no-playlist \
        --merge-output-format mkv \
        --remux-video mkv \
        --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
        -o "$clip_output_template" \
        "${EXTRA_YTDLP_ARGS[@]}" \
        "$clip_url"
    rc=$?

    if [[ "$rc" -eq 0 ]]; then
        # yt-dlp returns rc=0 when --download-archive skips an already-recorded
        # ID (and can also do so for some existing-file skips).  A real new
        # download in this script emits YTDL_FILE via --print after_move.
        local created_lines=""
        created_lines="$(grep -F $'YTDL_FILE\t' "$RUN_OUTPUT_FILE" 2>/dev/null || true)"

        if [[ -z "$created_lines" ]]; then
            CLIP_SKIPPED_NO_OUTPUT=$((CLIP_SKIPPED_NO_OUTPUT + 1))
            log_msg "WARNING: yt-dlp returned rc=0 but created no new output for [$mode]."
            log_msg "         Likely --download-archive or existing-file skip; NOT counting this variant as downloaded."
            return "$RC_CLIP_NO_OUTPUT"
        fi

        if [[ -n "$CLIP_ITEM_OUTPUT_LINES" ]]; then
            CLIP_ITEM_OUTPUT_LINES+=$'\n'
        fi
        CLIP_ITEM_OUTPUT_LINES+="$created_lines"
        CLIP_CREATED_THIS_ITEM=$((CLIP_CREATED_THIS_ITEM + 1))
        CLIP_DOWNLOADED=$((CLIP_DOWNLOADED + 1))
        if [[ "$mode" == "remaster" ]]; then
            CLIP_DOWNLOADED_REMASTER=$((CLIP_DOWNLOADED_REMASTER + 1))
        else
            CLIP_DOWNLOADED_NORMAL=$((CLIP_DOWNLOADED_NORMAL + 1))
        fi
        return 0
    fi

    if ytdlp_last_error_was_network_failure; then
        log_msg "Video clip download hit a network/API failure after route attempts: mode=$mode rc=$rc"
        cleanup_failed_clip_artifacts "$CLIP_SAFE_INPUT"
        return "$RC_SEARCH_FAILURE"
    fi

    log_msg "Video clip download failed after all routes: mode=$mode rc=$rc"
    cleanup_failed_clip_artifacts "$CLIP_SAFE_INPUT"
    return "$RC_DOWNLOAD_FAILURE"
}

process_video_clip_item() {
    local item="$1"
    local rc=0
    local one_rc=0
    local attempted=0

    CLIP_CREATED_THIS_ITEM=0
    CLIP_ITEM_OUTPUT_LINES=""

    find_video_clip_variants "$item"
    one_rc=$?

    if [[ "$one_rc" -eq "$RC_SEARCH_FAILURE" ]]; then
        return "$RC_SEARCH_FAILURE"
    elif [[ "$one_rc" -eq "$RC_CLIP_NOT_FOUND" ]]; then
        return "$RC_CLIP_NOT_FOUND"
    elif [[ "$one_rc" -ne 0 ]]; then
        return "$one_rc"
    fi

    if [[ -n "$CLIP_REMASTER_ID" ]]; then
        attempted=1
        download_video_clip_variant \
            "$item" "remaster" \
            "$CLIP_REMASTER_ID" "$CLIP_REMASTER_TITLE" "$CLIP_REMASTER_UPLOADER" "$CLIP_REMASTER_URL"
        one_rc=$?
        if [[ "$one_rc" -eq "$RC_SEARCH_FAILURE" ]]; then
            return "$RC_SEARCH_FAILURE"
        elif [[ "$one_rc" -eq "$RC_CLIP_NO_OUTPUT" ]]; then
            : # another variant may still produce a real file
        elif [[ "$one_rc" -ne 0 ]]; then
            rc="$RC_DOWNLOAD_FAILURE"
        fi
    fi

    if [[ -n "$CLIP_NORMAL_ID" ]]; then
        if [[ -n "$CLIP_REMASTER_ID" && "$CLIP_NORMAL_ID" == "$CLIP_REMASTER_ID" ]]; then
            CLIP_SKIPPED_SAME_ID=$((CLIP_SKIPPED_SAME_ID + 1))
            log_msg "Normal variant is the same YouTube ID as remaster; skipping duplicate download: $CLIP_NORMAL_ID"
        else
            attempted=1
            download_video_clip_variant \
                "$item" "normal" \
                "$CLIP_NORMAL_ID" "$CLIP_NORMAL_TITLE" "$CLIP_NORMAL_UPLOADER" "$CLIP_NORMAL_URL"
            one_rc=$?
            if [[ "$one_rc" -eq "$RC_SEARCH_FAILURE" ]]; then
                return "$RC_SEARCH_FAILURE"
            elif [[ "$one_rc" -eq "$RC_CLIP_NO_OUTPUT" ]]; then
                : # handled below at item level
            elif [[ "$one_rc" -ne 0 ]]; then
                rc="$RC_DOWNLOAD_FAILURE"
            fi
        fi
    fi

    [[ "$attempted" -eq 1 ]] || return "$RC_CLIP_NOT_FOUND"

    # Critical v3.6 rule: an item is DONE only when this run really created at
    # least one output file.  If every candidate was silently skipped by the
    # archive/existing-file logic, keep the item in inbox.txt.
    if [[ "$CLIP_CREATED_THIS_ITEM" -eq 0 ]]; then
        log_msg "VIDEO CLIP NO NEW OUTPUT: $item"
        return "$RC_DOWNLOAD_FAILURE"
    fi

    return "$rc"
}

parse_audio_channel_item() {
    local item="$1"
    local months url

    if [[ "$item" != *"|"* ]]; then
        log_msg "ERROR: [audio-channel] syntax must be: MONTHS | CHANNEL_URL"
        return 64
    fi

    months="$(trim_line "${item%%|*}")"
    url="$(trim_line "${item#*|}")"

    if [[ ! "$months" =~ ^[1-9][0-9]*$ ]]; then
        log_msg "ERROR: [audio-channel] months must be a positive integer: $months"
        return 64
    fi

    if [[ -z "$url" ]]; then
        log_msg "ERROR: [audio-channel] channel URL is empty"
        return 64
    fi

    AUDIO_CHANNEL_MONTHS="$months"
    AUDIO_CHANNEL_URL="$url"
    return 0
}

target_for_section() {
    local section="$1"
    local item="$2"

    case "$section" in
        music-search)
            printf 'ytsearch1:%s' "$item"
            ;;
        video-clips)
            printf '%s' "${CLIP_SELECTED_URL:-}"
            ;;
        audio-channel)
            AUDIO_CHANNEL_MONTHS=""
            AUDIO_CHANNEL_URL=""
            parse_audio_channel_item "$item" || return $?
            printf '%s' "$AUDIO_CHANNEL_URL"
            ;;
        *)
            printf '%s' "$item"
            ;;
    esac
}

print_video_clips_summary() {
    local rejected_total
    local item

    rejected_total=$(
        ((
            CLIP_REJECT_LYRICS +
            CLIP_REJECT_LIVE_HARD +
            CLIP_REJECT_LIVE_LOCATION +
            CLIP_REJECT_TEASER +
            CLIP_REJECT_TRAILER +
            CLIP_REJECT_REACTION +
            CLIP_REJECT_AUDIO +
            CLIP_REJECT_VISUALIZER +
            CLIP_REJECT_RELEVANCE +
            CLIP_REJECT_FANCAM +
            CLIP_REJECT_PERFORMANCE +
            CLIP_REJECT_OTHER
        ))
    )

    log_msg "=================================================="
    log_msg "VIDEO-CLIPS SUMMARY"
    log_msg "=================================================="
    log_msg "Downloaded video files: $CLIP_DOWNLOADED"
    log_msg "  remaster/4K variants: $CLIP_DOWNLOADED_REMASTER"
    log_msg "  normal variants:      $CLIP_DOWNLOADED_NORMAL"
    log_msg "  duplicate same-ID normal variants skipped: $CLIP_SKIPPED_SAME_ID"
    log_msg "Rejected candidates: $rejected_total"
    log_msg "  lyrics:          $CLIP_REJECT_LYRICS"
    log_msg "  live-hard:       $CLIP_REJECT_LIVE_HARD"
    log_msg "  live-location:   $CLIP_REJECT_LIVE_LOCATION"
    log_msg "  teaser:          $CLIP_REJECT_TEASER"
    log_msg "  trailer:         $CLIP_REJECT_TRAILER"
    log_msg "  reaction:        $CLIP_REJECT_REACTION"
    log_msg "  audio/topic:     $CLIP_REJECT_AUDIO"
    log_msg "  visualizer:      $CLIP_REJECT_VISUALIZER"
    log_msg "  fancam:          $CLIP_REJECT_FANCAM"
    log_msg "  performance:     $CLIP_REJECT_PERFORMANCE"
    log_msg "  relevance total: $CLIP_REJECT_RELEVANCE"
    log_msg "    artist mismatch:$CLIP_REJECT_RELEVANCE_ARTIST"
    log_msg "    track mismatch: $CLIP_REJECT_RELEVANCE_TRACK"
    log_msg "  other:           $CLIP_REJECT_OTHER"
    log_msg "Downloaded as lyrics: 0 (blocked)"
    log_msg "Downloaded as filtered live: 0 (blocked)"
    log_msg "Not found at all: ${#CLIP_NOT_FOUND_ITEMS[@]}"

    if [[ "${#CLIP_LIVE_LOCATION_ITEMS[@]}" -gt 0 ]]; then
        log_msg "LIVE-LOCATION CANDIDATES SKIPPED:"
        for item in "${CLIP_LIVE_LOCATION_ITEMS[@]}"; do
            log_msg "  $item"
        done
    fi

    if [[ "${#CLIP_NOT_FOUND_ITEMS[@]}" -gt 0 ]]; then
        log_msg "NOT FOUND:"
        for item in "${CLIP_NOT_FOUND_ITEMS[@]}"; do
            log_msg "  $item"
        done
    fi
}


get_metadata() {
    local section="$1"
    local item="$2"
    local target
    local rc
    local line

    META_ID=""
    META_TITLE=""
    META_URL=""
    META_UPLOADER=""

    target="$(target_for_section "$section" "$item")"

    if [[ "$section" == "video-playlist" || "$section" == "audio-playlist" || "$section" == "audio-channel" ]]; then
        run_ytdlp_capture \
            --skip-download \
            --flat-playlist \
            --playlist-items 1 \
            --no-warnings \
            --print $'YTDL_META\t%(playlist_id)s\t%(playlist_title)s\t%(webpage_url)s' \
            "$target" >/dev/null
    elif [[ "$section" == "chapters" ]]; then
        run_ytdlp_capture \
            --skip-download \
            --no-warnings \
            --print $'YTDL_META\t%(id)s\t%(title)s\t%(webpage_url)s\t%(uploader)s' \
            "$target" >/dev/null
    else
        run_ytdlp_capture \
            --skip-download \
            --no-warnings \
            --no-playlist \
            --print $'YTDL_META\t%(id)s\t%(title)s\t%(webpage_url)s\t%(uploader)s' \
            "$target" >/dev/null
    fi

    rc=$?

    if [[ "$rc" -ne 0 ]]; then
        if ytdlp_last_error_was_network_failure; then
            log_msg "Metadata lookup hit a network/API failure; marking rc=$RC_SEARCH_FAILURE"
            rm -f "$RUN_OUTPUT_FILE"
            return "$RC_SEARCH_FAILURE"
        fi

        rm -f "$RUN_OUTPUT_FILE"
        return "$rc"
    fi

    line="$(grep -F $'YTDL_META\t' "$RUN_OUTPUT_FILE" | tail -n 1 || true)"
    rm -f "$RUN_OUTPUT_FILE"

    if [[ -z "$line" ]]; then
        return 1
    fi

    IFS=$'\t' read -r _ META_ID META_TITLE META_URL META_UPLOADER <<< "$line"

    META_ID="$(tsv_escape "$META_ID")"
    META_TITLE="$(tsv_escape "$META_TITLE")"
    META_URL="$(tsv_escape "$META_URL")"
    META_UPLOADER="$(tsv_escape "$META_UPLOADER")"

    return 0
}

download_item() {
    local section="$1"
    local item="$2"
    local target
    local rc
    local output_line
    local output_paths

    DOWNLOAD_ID=""
    DOWNLOAD_TITLE=""
    DOWNLOAD_PATHS=""

    target="$(target_for_section "$section" "$item")"

    case "$section" in
        video)
            run_video_download_routes \
                "bv[protocol=m3u8_native]+ba[protocol=m3u8_native]/b[protocol=m3u8_native]/bv*+ba/b" \
                "bv*+ba/b" \
                --download-archive "/downloads/.state/archives/video.txt" \
                --add-metadata \
                --embed-metadata \
                --embed-chapters \
                --no-playlist \
                --merge-output-format mkv \
                --remux-video mkv \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "video/%(upload_date)s - %(title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?
            ;;

        video-mp4)
            run_video_download_routes \
                "b[protocol=m3u8_native]/bv[protocol=m3u8_native]+ba[protocol=m3u8_native]/bv*[ext=mp4][vcodec^=avc1]+ba[ext=m4a]/b[ext=mp4]/bv*[ext=mp4]+ba/b" \
                "bv*[ext=mp4][vcodec^=avc1]+ba[ext=m4a]/b[ext=mp4]/bv*[ext=mp4]+ba/b" \
                --download-archive "/downloads/.state/archives/video_mp4.txt" \
                --add-metadata \
                --embed-metadata \
                --embed-chapters \
                --no-playlist \
                --merge-output-format mp4 \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "video/%(upload_date)s - %(title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?
            ;;

        video-subtitles)
            run_video_download_routes \
                "bv[protocol=m3u8_native]+ba[protocol=m3u8_native]/b[protocol=m3u8_native]/bv*+ba/b" \
                "bv*+ba/b" \
                --download-archive "/downloads/.state/archives/video_subtitles.txt" \
                --add-metadata \
                --embed-metadata \
                --embed-chapters \
                --write-subs \
                --sub-langs "en.*" \
                --convert-subs srt \
                --no-playlist \
                --merge-output-format mkv \
                --remux-video mkv \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "video/%(upload_date)s - %(title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?
            ;;

        video-playlist)
            run_video_download_routes \
                "bv[protocol=m3u8_native]+ba[protocol=m3u8_native]/b[protocol=m3u8_native]/bv*+ba/b" \
                "bv*+ba/b" \
                --download-archive "/downloads/.state/archives/video_playlist.txt" \
                --ignore-errors \
                --yes-playlist \
                --no-warnings \
                --sleep-requests 2 \
                --sleep-interval 5 \
                --max-sleep-interval 15 \
                --add-metadata \
                --embed-metadata \
                --embed-chapters \
                --merge-output-format mkv \
                --remux-video mkv \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "video/%(playlist_title)s/%(playlist_index)03d - %(upload_date)s - %(title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?
            ;;

        video-clips)
            process_video_clip_item "$item"
            rc=$?
            ;;

        audio)
            run_ytdlp_capture \
                --download-archive "/downloads/.state/archives/audio.txt" \
                --no-playlist \
                -f "bestaudio/best" \
                --extract-audio \
                --audio-format opus \
                --audio-quality 0 \
                --add-metadata \
                --embed-metadata \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "audio/%(upload_date)s - %(title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?
            ;;

        audio-playlist)
            run_ytdlp_capture \
                --download-archive "/downloads/.state/archives/audio_playlist.txt" \
                --ignore-errors \
                --yes-playlist \
                --no-warnings \
                --sleep-requests 2 \
                --sleep-interval 5 \
                --max-sleep-interval 15 \
                -f "bestaudio/best" \
                --extract-audio \
                --audio-format opus \
                --audio-quality 0 \
                --add-metadata \
                --embed-metadata \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "audio/%(playlist_title)s/%(playlist_index)03d - %(upload_date)s - %(title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?
            ;;

        audio-channel)
            AUDIO_CHANNEL_MONTHS=""
            AUDIO_CHANNEL_URL=""
            if ! parse_audio_channel_item "$item"; then
                rc=64
            else
                local date_after
                date_after="$(date -d "${AUDIO_CHANNEL_MONTHS} months ago" +%Y%m%d)" || {
                    log_msg "ERROR: failed to calculate date for ${AUDIO_CHANNEL_MONTHS} months ago"
                    return 64
                }

                log_msg "Audio channel: $AUDIO_CHANNEL_URL"
                log_msg "Period: last $AUDIO_CHANNEL_MONTHS month(s), dateafter=$date_after"

                run_ytdlp_capture \
                    --download-archive "/downloads/.state/archives/audio_channel.txt" \
                    --ignore-errors \
                    --yes-playlist \
                    --no-warnings \
                    --dateafter "$date_after" \
                    --sleep-requests 2 \
                    --sleep-interval 5 \
                    --max-sleep-interval 15 \
                    -f "bestaudio/best" \
                    --extract-audio \
                    --audio-format opus \
                    --audio-quality 0 \
                    --add-metadata \
                    --embed-metadata \
                    --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                    -o "audio/%(uploader)s/%(upload_date)s - %(title)s.%(ext)s" \
                    "${EXTRA_YTDLP_ARGS[@]}" \
                    "$AUDIO_CHANNEL_URL"
                rc=$?
            fi
            ;;

        music)
            run_ytdlp_capture \
                --download-archive "/downloads/.state/archives/music.txt" \
                --no-playlist \
                -f "bestaudio/best" \
                --extract-audio \
                --audio-format opus \
                --audio-quality 0 \
                --add-metadata \
                --embed-metadata \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "music/%(uploader)s - %(title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?
            ;;

        music-search)
            run_ytdlp_capture \
                --download-archive "/downloads/.state/archives/music_search.txt" \
                --no-playlist \
                -f "bestaudio/best" \
                --extract-audio \
                --audio-format opus \
                --audio-quality 0 \
                --add-metadata \
                --embed-metadata \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "music/%(uploader)s - %(title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?
            ;;

        chapters)
            run_ytdlp_capture \
                --download-archive "/downloads/.state/archives/chapters.txt" \
                --ignore-errors \
                --yes-playlist \
                -f "bestaudio/best" \
                --extract-audio \
                --audio-format opus \
                --audio-quality 0 \
                --add-metadata \
                --embed-metadata \
                --embed-chapters \
                --split-chapters \
                --print after_move:$'YTDL_FILE\t%(id)s\t%(title)s\t%(filepath)s' \
                -o "music/%(title)s/_full.%(ext)s" \
                -o "chapter:music/%(title)s/%(section_number)02d - %(uploader)s - %(section_title)s.%(ext)s" \
                "${EXTRA_YTDLP_ARGS[@]}" \
                "$target"
            rc=$?

            find "$BASE_DIR/music" -type f \( \
                -name "_full.opus" -o \
                -name "_full.webm" -o \
                -name "_full.m4a" -o \
                -name "_full.mp3" \
            \) -delete 2>/dev/null || true
            ;;

        *)
            log_msg "Unknown section: [$section]"
            return 64
            ;;
    esac

    # Universal transient failure mapping for all ordinary sections.
    # video-clips already has richer 44/45/46 handling inside its own pipeline.
    if [[ "$section" != "video-clips" && "$rc" -ne 0 ]] && ytdlp_last_error_was_network_failure; then
        log_msg "Download hit a network/API failure; mapping rc=$rc -> rc=$RC_SEARCH_FAILURE"
        rc="$RC_SEARCH_FAILURE"
    fi

    if [[ "$section" == "video-clips" && -n "$CLIP_ITEM_OUTPUT_LINES" ]]; then
        output_line="$(printf '%s\n' "$CLIP_ITEM_OUTPUT_LINES" | tail -n 1)"
        output_paths="$(
            printf '%s\n' "$CLIP_ITEM_OUTPUT_LINES" \
                | awk -F '\t' '{print $4}' \
                | sed '/^$/d' \
                | paste -sd ';' -
        )"
    else
        output_line="$(grep -F $'YTDL_FILE\t' "$RUN_OUTPUT_FILE" 2>/dev/null | tail -n 1 || true)"
        output_paths="$(
            grep -F $'YTDL_FILE\t' "$RUN_OUTPUT_FILE" 2>/dev/null \
                | awk -F '\t' '{print $4}' \
                | sed '/^$/d' \
                | paste -sd ';' -
        )"
    fi

    rm -f "$RUN_OUTPUT_FILE"

    if [[ -n "$output_line" ]]; then
        IFS=$'\t' read -r _ DOWNLOAD_ID DOWNLOAD_TITLE _ <<< "$output_line"
        DOWNLOAD_ID="$(tsv_escape "$DOWNLOAD_ID")"
        DOWNLOAD_TITLE="$(tsv_escape "$DOWNLOAD_TITLE")"
    fi

    DOWNLOAD_PATHS="$(tsv_escape "$output_paths")"

    return "$rc"
}

append_done_failed() {
    local file="$1"
    local status="$2"
    local section="$3"
    local item="$4"
    local rc="$5"
    local id="$6"
    local title="$7"
    local url="$8"
    local paths="$9"

    {
        echo
        echo "# $(timestamp) $status rc=$rc id=${id:-UNKNOWN} title=${title:-UNKNOWN}"
        [[ -n "$url" ]] && echo "# url=$url"
        [[ -n "$paths" ]] && echo "# file=$paths"
        echo "[$section]"
        echo "$item"
    } >> "$file"
}

append_history() {
    local status="$1"
    local section="$2"
    local item="$3"
    local rc="$4"
    local id="$5"
    local title="$6"
    local url="$7"
    local paths="$8"

    if [[ ! -s "$HISTORY_FILE" ]]; then
        printf 'timestamp\tstatus\tsection\trc\tid\ttitle\tresolved_url\toutput_files\toriginal_item\n' >> "$HISTORY_FILE"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(timestamp)" \
        "$(tsv_escape "$status")" \
        "$(tsv_escape "$section")" \
        "$(tsv_escape "$rc")" \
        "$(tsv_escape "${id:-UNKNOWN}")" \
        "$(tsv_escape "${title:-UNKNOWN}")" \
        "$(tsv_escape "$url")" \
        "$(tsv_escape "$paths")" \
        "$(tsv_escape "$item")" \
        >> "$HISTORY_FILE"
}

read_inbox_queue() {
    local section=""
    local line=""
    local item=""

    QUEUE_SECTIONS=()
    QUEUE_ITEMS=()
    QUEUE_DONE=()

    [[ -f "$INBOX_FILE" ]] || write_clean_inbox

    while IFS= read -r line || [[ -n "$line" ]]; do
        item="$(trim_line "$line")"

        [[ -z "$item" ]] && continue
        [[ "$item" =~ ^# ]] && continue

        if [[ "$item" =~ ^\[(.*)\]$ ]]; then
            section="${BASH_REMATCH[1]}"

            if ! is_known_section "$section"; then
                log_msg "WARNING: unknown inbox section ignored: [$section]"
                section=""
            fi

            continue
        fi

        if [[ -z "$section" ]]; then
            log_msg "WARNING: inbox item without known section ignored: $item"
            continue
        fi

        QUEUE_SECTIONS+=("$section")
        QUEUE_ITEMS+=("$item")
        QUEUE_DONE+=("0")
    done < "$INBOX_FILE"
}

rewrite_inbox_from_queue() {
    local tmp="$INBOX_FILE.rewrite.$$"
    local section
    local i
    local wrote

    : > "$tmp" || die "Cannot write temp inbox: $tmp"

    for section in "${SECTIONS[@]}"; do
        echo "[$section]" >> "$tmp"

        wrote=0

        for i in "${!QUEUE_ITEMS[@]}"; do
            if [[ "${QUEUE_DONE[$i]}" == "0" && "${QUEUE_SECTIONS[$i]}" == "$section" ]]; then
                echo "${QUEUE_ITEMS[$i]}" >> "$tmp"
                wrote=1
            fi
        done

        echo >> "$tmp"
    done

    mv "$tmp" "$INBOX_FILE"
}

on_exit() {
    local rc=$?

    if [[ "$PROCESSING_INBOX" -eq 1 ]]; then
        rewrite_inbox_from_queue || true
    fi

    exit "$rc"
}

run_inbox() {
    local i
    local section
    local item
    local rc
    local abort_run=0
    local total
    local done_count=0
    local failed_count=0
    local meta_rc
    local id
    local title
    local url
    local paths

    read_inbox_queue

    total="${#QUEUE_ITEMS[@]}"

    if [[ "$total" -eq 0 ]]; then
        log_msg "Inbox has no active items: $INBOX_FILE"
        rewrite_inbox_from_queue
        return 0
    fi

    PROCESSING_INBOX=1
    trap on_exit INT TERM

    log_msg "Processing inbox: $INBOX_FILE"
    log_msg "Retry queue: inbox.txt; failed log is append-only history: $FAILED_FILE"
    log_msg "Items: $total"

    for i in "${!QUEUE_ITEMS[@]}"; do
        section="${QUEUE_SECTIONS[$i]}"
        item="${QUEUE_ITEMS[$i]}"

        META_ID=""
        META_TITLE=""
        META_URL=""
        META_UPLOADER=""
        CLIP_SELECTED_URL=""
        CLIP_SELECTED_ID=""
        CLIP_SELECTED_TITLE=""
        CLIP_SELECTED_UPLOADER=""
        CLIP_SELECTED_SEARCH_MODE=""
        CLIP_SAFE_INPUT=""

        CLIP_REMASTER_URL=""
        CLIP_REMASTER_ID=""
        CLIP_REMASTER_TITLE=""
        CLIP_REMASTER_UPLOADER=""

        CLIP_NORMAL_URL=""
        CLIP_NORMAL_ID=""
        CLIP_NORMAL_TITLE=""
        CLIP_NORMAL_UPLOADER=""
        CLIP_CREATED_THIS_ITEM=0
        CLIP_ITEM_OUTPUT_LINES=""

        DOWNLOAD_ID=""
        DOWNLOAD_TITLE=""
        DOWNLOAD_PATHS=""

        log_msg "=================================================="
        log_msg "Inbox item: [$section] $item"

        if [[ "$section" == "video-clips" ]]; then
            META_ID=""
            META_TITLE=""
            META_URL=""
            META_UPLOADER=""
            meta_rc=0

            download_item "$section" "$item"
            rc=$?

            # Preserve the last selected variant in the generic history fields.
            META_ID="${CLIP_SELECTED_ID:-}"
            META_TITLE="${CLIP_SELECTED_TITLE:-}"
            META_URL="${CLIP_SELECTED_URL:-}"
            META_UPLOADER="${CLIP_SELECTED_UPLOADER:-}"
        else
            get_metadata "$section" "$item"
            meta_rc=$?

            if [[ "$meta_rc" -eq 0 ]]; then
                log_msg "Metadata: id=$META_ID title=$META_TITLE"
                download_item "$section" "$item"
                rc=$?
            elif [[ "$meta_rc" -eq "$RC_SEARCH_FAILURE" ]]; then
                log_msg "Metadata lookup failed because of network/API connectivity for [$section] $item"
                rc="$RC_SEARCH_FAILURE"
            else
                log_msg "Metadata lookup failed for [$section] $item rc=$meta_rc"
                # Preserve previous behavior for ordinary item-specific metadata errors:
                # still let yt-dlp attempt the actual download.
                download_item "$section" "$item"
                rc=$?
            fi
        fi

        id="${DOWNLOAD_ID:-$META_ID}"
        title="${DOWNLOAD_TITLE:-$META_TITLE}"
        url="$META_URL"
        paths="$DOWNLOAD_PATHS"

        if [[ "$rc" -eq 0 ]]; then
            QUEUE_DONE[$i]="1"

            log_msg "DONE: [$section] ${title:-$item}"
            append_done_failed "$DONE_FILE" "DONE" "$section" "$item" "$rc" "$id" "$title" "$url" "$paths"
            append_history "DONE" "$section" "$item" "$rc" "$id" "$title" "$url" "$paths"
            done_count=$((done_count + 1))
        else
            QUEUE_DONE[$i]="0"
            log_msg "FAILED: [$section] $item rc=$rc"
            log_msg "Keeping failed item in inbox: $INBOX_FILE"
            show_recent_partials
            append_done_failed "$FAILED_FILE" "FAILED" "$section" "$item" "$rc" "$id" "$title" "$url" "$paths"
            append_history "FAILED" "$section" "$item" "$rc" "$id" "$title" "$url" "$paths"
            failed_count=$((failed_count + 1))

            if [[ "$rc" -eq "$RC_SEARCH_FAILURE" ]]; then
                log_msg "ABORTING RUN: transient network/API failure detected in [$section]."
                log_msg "Current item and all remaining inbox items stay in inbox.txt for retry."
                abort_run=1
            fi
        fi

        rewrite_inbox_from_queue

        if [[ "$abort_run" -eq 1 ]]; then
            break
        fi
    done

    PROCESSING_INBOX=0
    trap - INT TERM

    rewrite_inbox_from_queue

    if [[ "$CLIP_DOWNLOADED" -gt 0 || "${#CLIP_NOT_FOUND_ITEMS[@]}" -gt 0 || \
          "${#CLIP_LIVE_LOCATION_ITEMS[@]}" -gt 0 || \
          "$CLIP_REJECT_LYRICS" -gt 0 || "$CLIP_REJECT_LIVE_HARD" -gt 0 || \
          "$CLIP_REJECT_LIVE_LOCATION" -gt 0 || "$CLIP_REJECT_TEASER" -gt 0 || \
          "$CLIP_REJECT_TRAILER" -gt 0 || "$CLIP_REJECT_REACTION" -gt 0 || \
          "$CLIP_REJECT_AUDIO" -gt 0 || "$CLIP_REJECT_VISUALIZER" -gt 0 || \
          "$CLIP_REJECT_RELEVANCE" -gt 0 || "$CLIP_REJECT_OTHER" -gt 0 ]]; then
        print_video_clips_summary
    fi

    log_msg "=================================================="
    log_msg "Inbox finished"
    log_msg "Total: $total | Done: $done_count | Failed: $failed_count"
    log_msg "Active queue: $INBOX_FILE"
    log_msg "Done file:    $DONE_FILE"
    log_msg "Failed log:   $FAILED_FILE"
    log_msg "History file: $HISTORY_FILE"

    if [[ "$failed_count" -gt 0 ]]; then
        return 1
    fi

    return 0
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --inbox)
                MODE="inbox"
                ;;
            --log)
                ENABLE_LOG=1
                ;;
            --log=*)
                ENABLE_LOG=1
                LOG_FILE="${1#*=}"
                ;;
            --no-log)
                ENABLE_LOG=0
                LOG_FILE=""
                ;;
            --video|--video-mkv|--video-mp4|--video-subtitles|--video-playlist|--video-clips|--audio|--audio-playlist|--audio-channel|--music|--music-search|--audio-search|--chapters|--music-chapters)
                die "Old direct mode '$1' was removed. Put the item into $INBOX_FILE under the matching section and run: ytdl.sh"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                EXTRA_YTDLP_ARGS+=("$1")
                ;;
        esac

        shift
    done
}

main() {
    local rc

    parse_args "$@"
    require_cmds
    prepare_dirs
    setup_log
    ensure_firefox_profile
    ensure_bgutil_pot_server

    run_inbox
    rc=$?

    if [[ "$rc" -eq 0 ]]; then
        log_msg "✅ ytdl finished successfully."
    else
        log_msg "❌ ytdl failed with code $rc"
    fi

    log_msg "Finished at $(date)"
    return "$rc"
}

main "$@"
