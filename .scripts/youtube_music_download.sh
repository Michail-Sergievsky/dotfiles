#!/bin/bash

set -u

INPUT_FILE="$HOME/Downloads/youtube/music.txt"
OUTPUT_DIR="$HOME/Downloads/youtube/music"

ENABLE_LOG=0
LOG_FILE=""

usage() {
    cat <<EOF
Usage:
  youtube_music_download.sh [--log] [--log=/path/file]

Options:
  --log                 Enable logging (default file in OUTPUT_DIR)
  --log=/path/file      Custom log file
  -h, --help            Show help
EOF
}

log_msg() {
    local msg="$1"
    echo "$msg"
    if [[ "$ENABLE_LOG" -eq 1 ]]; then
        echo "$msg" >> "$LOG_FILE"
    fi
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

# ---------- ARGUMENTS ----------
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
            usage
            exit 1
            ;;
    esac
done

# ---------- PREP ----------
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file $INPUT_FILE not found."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [[ "$ENABLE_LOG" -eq 1 ]]; then
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="$OUTPUT_DIR/music_download_log_$(date +%Y%m%d_%H%M%S).txt"
    fi
    : > "$LOG_FILE" || { echo "Cannot write log file"; exit 1; }
    log_msg "Download log - $(date)"
fi

downloaded_count=0
failed_count=0

# ---------- MAIN LOOP ----------
while IFS= read -r youtube_link || [[ -n "$youtube_link" ]]; do
    [[ -z "$youtube_link" ]] && continue

    log_msg "Downloading: $youtube_link"

    output_file_template="$OUTPUT_DIR/%(title)s.%(ext)s"

    if [[ "$ENABLE_LOG" -eq 1 ]]; then
        actual_file=$(yt-dlp \
            --cookies "$HOME/.env_priv/max_yotebe_cookies.txt" \
            -f bestaudio \
            --extract-audio \
            --audio-format opus \
            --audio-quality 0 \
            --add-metadata \
            --parse-metadata "title:%(uploader)s" \
            -o "$output_file_template" \
            --print after_move:filename \
            "$youtube_link" 2>>"$LOG_FILE" | tail -n 1)
        rc=$?
    else
        actual_file=$(yt-dlp \
            --cookies "$HOME/.env_priv/max_yotebe_cookies.txt" \
            -f bestaudio \
            --extract-audio \
            --audio-format opus \
            --audio-quality 0 \
            --add-metadata \
            --parse-metadata "title:%(uploader)s" \
            -o "$output_file_template" \
            --print after_move:filename \
            "$youtube_link" | tail -n 1)
        rc=$?
    fi

    if [[ "$rc" -ne 0 ]]; then
        log_msg "Failed: $youtube_link"
        failed_count=$((failed_count + 1))
        continue
    fi

    log_msg "Downloaded: $youtube_link"
    downloaded_count=$((downloaded_count + 1))

    actual_file=$(echo "$actual_file" | sed 's/\.webm$/.opus/I')

    if [[ ! -f "$actual_file" ]]; then
        log_msg "File missing: $actual_file"
        continue
    fi

    track_name=$(mediainfo --Inform="General;%Title%" "$actual_file" 2>/dev/null | tr -d '\n')
    performer=$(mediainfo --Inform="General;%Performer%" "$actual_file" 2>/dev/null | tr -d '\n')

    track_name="$(sanitize_filename "$track_name")"
    performer="$(sanitize_filename "$performer")"

    log_msg "Metadata: Title='$track_name' Performer='$performer'"

    if [[ -z "$track_name" ]]; then
        log_msg "Skipping rename (empty title)"
        continue
    fi

    if [[ -z "$performer" || "$track_name" == "$performer" ]]; then
        new_name="$OUTPUT_DIR/${track_name}.opus"
    else
        new_name="$OUTPUT_DIR/${performer} - ${track_name}.opus"
    fi

    if [[ "$actual_file" == "$new_name" ]]; then
        log_msg "Already correct name"
        continue
    fi

    if [[ -e "$new_name" ]]; then
        log_msg "Target exists, skipping: $new_name"
        continue
    fi

    mv -- "$actual_file" "$new_name"
    log_msg "Renamed → $new_name"

done < "$INPUT_FILE"

# ---------- SUMMARY ----------
log_msg "Done at $(date)"
log_msg "Downloaded: $downloaded_count | Failed: $failed_count"
