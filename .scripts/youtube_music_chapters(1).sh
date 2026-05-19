#!/bin/bash
set -u

WORK_DIR="$HOME/Downloads/youtube/music"
INPUT_FILE="$HOME/Downloads/youtube/music_chapters.txt"
COOKIES="$HOME/.env_priv/max_yotebe_cookies.txt"

ENABLE_LOG=0
LOG_FILE=""

usage() {
cat <<EOF
Usage:
  youtube_music_album_chapters.sh [--log]

Reads URLs from:
  $INPUT_FILE

Supports:
  - single videos
  - playlists

Downloads:
  - audio as opus
  - chapters split into separate files
  - metadata
EOF
}

for arg in "$@"; do
    case "$arg" in
        --log)
            ENABLE_LOG=1
            ;;
        --log=*)
            ENABLE_LOG=1
            LOG_FILE="${arg#*=}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

mkdir -p "$WORK_DIR"

if [[ "$ENABLE_LOG" -eq 1 ]]; then
    [[ -z "$LOG_FILE" ]] && \
        LOG_FILE="$WORK_DIR/music_chapters_log_$(date +%Y%m%d_%H%M%S).txt"

    : > "$LOG_FILE" || {
        echo "Cannot write log file: $LOG_FILE"
        exit 1
    }
fi

log_msg() {
    echo "$1"
    [[ "$ENABLE_LOG" -eq 1 ]] && echo "$1" >> "$LOG_FILE"
}

sanitize_filename() {
    local s="$1"

    s="${s//$'\n'/ }"
    s="${s//\//-}"
    s="${s//:/ -}"
    s="${s//\?/}"
    s="${s//\"/}"
    s="${s//</}"
    s="${s//>/}"
    s="${s//|/-}"
    s="${s//\*/-}"

    s="$(echo "$s" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"

    printf '%s' "$s"
}

[[ -f "$INPUT_FILE" ]] || {
    echo "Input file not found: $INPUT_FILE"
    exit 1
}

downloaded_count=0
failed_count=0

while IFS= read -r url || [[ -n "$url" ]]; do
    [[ -z "$url" ]] && continue

    log_msg "=================================================="
    log_msg "Processing URL: $url"

    if [[ "$ENABLE_LOG" -eq 1 ]]; then

        yt-dlp \
            --cookies "$COOKIES" \
            --ignore-errors \
            --yes-playlist \
            --paths "$WORK_DIR" \
            -f bestaudio \
            --extract-audio \
            --audio-format opus \
            --audio-quality 0 \
            --add-metadata \
            --embed-metadata \
            --embed-chapters \
            --split-chapters \
            -o "%(title)s/_full.%(ext)s" \
            -o "chapter:%(title)s/%(section_number)02d - %(section_title)s.%(ext)s" \
            "$url" \
            2>&1 | tee -a "$LOG_FILE"

        rc=${PIPESTATUS[0]}
    else

        yt-dlp \
            --cookies "$COOKIES" \
            --ignore-errors \
            --yes-playlist \
            --paths "$WORK_DIR" \
            -f bestaudio \
            --extract-audio \
            --audio-format opus \
            --audio-quality 0 \
            --add-metadata \
            --embed-metadata \
            --embed-chapters \
            --split-chapters \
            -o "%(title)s/_full.%(ext)s" \
            -o "chapter:%(title)s/%(section_number)02d - %(section_title)s.%(ext)s" \
            "$url"

        rc=$?
    fi

    if [[ "$rc" -ne 0 ]]; then
        log_msg "FAILED: $url"
        failed_count=$((failed_count + 1))
        continue
    fi

    # Remove unsplit full files
    find "$WORK_DIR" -type f \( -name "_full.opus" -o -name "_full.webm" \) -delete

    downloaded_count=$((downloaded_count + 1))

    log_msg "DONE: $url"

done < "$INPUT_FILE"

log_msg "=================================================="
log_msg "Finished at $(date)"
log_msg "Processed: $downloaded_count"
log_msg "Failed: $failed_count"
