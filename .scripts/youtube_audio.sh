#!/bin/bash
set -u

INPUT_FILE="$HOME/Downloads/youtube/audio.txt"
OUTPUT_DIR="$HOME/Downloads/youtube/audio"
MODE="url"

ENABLE_LOG=0
LOG_FILE=""

for arg in "$@"; do
    case "$arg" in
        --log) ENABLE_LOG=1 ;;
        --log=*) ENABLE_LOG=1; LOG_FILE="${arg#*=}" ;;
        -h|--help)
            echo "Usage: $0 [--log] [--log=/path/file]"
            exit 0
            ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

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

[[ -f "$INPUT_FILE" ]] || { echo "Input file not found: $INPUT_FILE"; exit 1; }
mkdir -p "$OUTPUT_DIR"

if [[ "$ENABLE_LOG" -eq 1 ]]; then
    [[ -z "$LOG_FILE" ]] && LOG_FILE="$OUTPUT_DIR/audio_url_log_$(date +%Y%m%d_%H%M%S).txt"
    : > "$LOG_FILE" || { echo "Cannot write log: $LOG_FILE"; exit 1; }
    log_msg "Download log - $(date)"
fi

downloaded_count=0
failed_count=0

while IFS= read -r item || [[ -n "$item" ]]; do
    [[ -z "$item" ]] && continue

    log_msg "Downloading URL: $item"

    output_file_template="$OUTPUT_DIR/%(upload_date)s - %(title)s.%(ext)s"

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
            "$item" 2>>"$LOG_FILE" | tail -n 1)
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
            "$item" | tail -n 1)
        rc=$?
    fi

    if [[ "$rc" -ne 0 ]]; then
        log_msg "Failed: $item"
        failed_count=$((failed_count + 1))
        continue
    fi

    actual_file=$(echo "$actual_file" | sed 's/\.webm$/.opus/I')
    log_msg "DEBUG: actual_file='$actual_file'"

    if [[ ! -f "$actual_file" ]]; then
        log_msg "File missing: $actual_file"
        failed_count=$((failed_count + 1))
        continue
    fi

    track_name=$(mediainfo --Inform="General;%Title%" "$actual_file" 2>/dev/null | tr -d '\n')
    performer=$(mediainfo --Inform="General;%Performer%" "$actual_file" 2>/dev/null | tr -d '\n')
    recorded_date=$(mediainfo --Inform="General;%Recorded_Date%" "$actual_file" 2>/dev/null | tr -d '\n')

    track_name="$(sanitize_filename "$track_name")"
    performer="$(sanitize_filename "$performer")"
    recorded_date="$(echo "$recorded_date" | tr -cd '0-9')"

    if [[ -z "$recorded_date" ]]; then
        base_name="$(basename "$actual_file")"
        [[ "$base_name" =~ ^([0-9]{8})[[:space:]]-[[:space:]] ]] && recorded_date="${BASH_REMATCH[1]}"
    fi

    [[ -z "$track_name" ]] && { log_msg "Empty title, skip rename"; continue; }

    prefix=""
    [[ -n "$recorded_date" ]] && prefix="$recorded_date - "

    if [[ -z "$performer" || "$track_name" == "$performer" ]]; then
        new_name="$OUTPUT_DIR/${prefix}${track_name}.opus"
    else
        new_name="$OUTPUT_DIR/${prefix}${performer} - ${track_name}.opus"
    fi

    if [[ "$actual_file" != "$new_name" && ! -e "$new_name" ]]; then
        mv -- "$actual_file" "$new_name"
        log_msg "Renamed → $new_name"
    else
        log_msg "Rename skipped"
    fi

    downloaded_count=$((downloaded_count + 1))

done < "$INPUT_FILE"

log_msg "Done at $(date)"
log_msg "Downloaded: $downloaded_count | Failed: $failed_count"
