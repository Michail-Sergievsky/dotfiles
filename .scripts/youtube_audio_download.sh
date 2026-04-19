#!/bin/bash

set -u

INPUT_FILE="$HOME/Downloads/youtube/audio.txt"
OUTPUT_DIR="$HOME/Downloads/youtube/audio"

ENABLE_LOG=0
LOG_FILE=""

usage() {
    cat <<'EOF'
Usage:
  youtube_audio_download.sh [--log] [--log=/path/to/logfile]

Options:
  --log                 Enable logging to a default log file in OUTPUT_DIR
  --log=/path/to/file   Enable logging to a specific file
  -h, --help            Show this help
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

# Parse arguments
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
            echo "Unknown option: $arg" >&2
            usage
            exit 1
            ;;
    esac
done

# Ensure input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file $INPUT_FILE not found." >&2
    exit 1
fi

# Ensure output dir exists
mkdir -p "$OUTPUT_DIR"

# Setup log file
if [[ "$ENABLE_LOG" -eq 1 ]]; then
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="$OUTPUT_DIR/audio_download_log_$(date +%Y%m%d_%H%M%S).txt"
    fi
    : > "$LOG_FILE" || {
        echo "Error: Cannot write log file: $LOG_FILE" >&2
        exit 1
    }
    log_msg "Download log - $(date)"
fi

downloaded_count=0
failed_count=0

while IFS= read -r youtube_link || [[ -n "$youtube_link" ]]; do
    [[ -z "$youtube_link" ]] && continue

    log_msg "Downloading: $youtube_link"

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
            "$youtube_link" 2>>"$LOG_FILE" | tail -n 1)
        ytdlp_rc=$?
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
        ytdlp_rc=$?
    fi

    if [[ "$ytdlp_rc" -ne 0 ]]; then
        log_msg "Failed to download: $youtube_link"
        failed_count=$((failed_count + 1))
        continue
    fi

    log_msg "Successfully downloaded: $youtube_link"
    downloaded_count=$((downloaded_count + 1))

    actual_file=$(echo "$actual_file" | sed 's/\.webm$/.opus/I')
    log_msg "DEBUG: actual_file = '$actual_file'"

    if [[ ! -f "$actual_file" ]]; then
        log_msg "DEBUG: File '$actual_file' does not exist. Metadata extraction skipped."
        continue
    fi

    track_name=$(mediainfo --Inform="General;%Title%" "$actual_file" 2>/dev/null | tr -d '\n')
    performer=$(mediainfo --Inform="General;%Performer%" "$actual_file" 2>/dev/null | tr -d '\n')
    recorded_date=$(mediainfo --Inform="General;%Recorded_Date%" "$actual_file" 2>/dev/null | tr -d '\n')

    log_msg "Extracted metadata: Track Name='$track_name', Performer='$performer', RecordedDate='$recorded_date'"

    track_name="$(sanitize_filename "$track_name")"
    performer="$(sanitize_filename "$performer")"
    recorded_date="$(echo "$recorded_date" | tr -cd '0-9')"

    # Fallback: if metadata date is missing, try to keep the existing prefix from filename
    if [[ -z "$recorded_date" ]]; then
        base_name="$(basename "$actual_file")"
        if [[ "$base_name" =~ ^([0-9]{8})[[:space:]]-[[:space:]] ]]; then
            recorded_date="${BASH_REMATCH[1]}"
        fi
    fi

    if [[ -z "$track_name" ]]; then
        log_msg "DEBUG: Track name empty, skipping rename for '$actual_file'"
        continue
    fi

    if [[ -n "$recorded_date" ]]; then
        prefix="$recorded_date - "
    else
        prefix=""
    fi

    if [[ -z "$performer" || "$track_name" == "$performer" ]]; then
        new_name="$OUTPUT_DIR/${prefix}${track_name}.opus"
    else
        new_name="$OUTPUT_DIR/${prefix}${performer} - ${track_name}.opus"
    fi

    if [[ "$actual_file" == "$new_name" ]]; then
        log_msg "DEBUG: File already has target name."
        continue
    fi

    if [[ -e "$new_name" ]]; then
        log_msg "DEBUG: Target file already exists, skipping rename: $new_name"
        continue
    fi

    mv -- "$actual_file" "$new_name"
    log_msg "Renamed $actual_file to $new_name"

done < "$INPUT_FILE"

log_msg "Processing complete at $(date)"
log_msg "Downloaded: $downloaded_count | Failed: $failed_count"
