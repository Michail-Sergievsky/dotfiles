#!/bin/bash

set -u

INPUT_FILE="$HOME/Downloads/youtube/your_links.txt"
OUTPUT_DIR="$HOME/Downloads/youtube/video"

ENABLE_LOG=0
LOG_FILE=""

usage() {
    cat <<EOF
Usage:
  youtube_video_download.sh [--log] [--log=/path/file]

Options:
  --log                 Enable logging
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
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [[ "$ENABLE_LOG" -eq 1 ]]; then
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="$OUTPUT_DIR/video_download_log_$(date +%Y%m%d_%H%M%S).txt"
    fi
    : > "$LOG_FILE" || {
        echo "Cannot write log file: $LOG_FILE"
        exit 1
    }
    log_msg "Video download log - $(date)"
fi

# ---------- DOWNLOAD ----------
log_msg "Starting yt-dlp..."

if [[ "$ENABLE_LOG" -eq 1 ]]; then
    yt-dlp \
        --cookies "$HOME/.env_priv/max_yotebe_cookies.txt" \
        --add-metadata \
        --embed-metadata \
        --embed-chapters \
        --merge-output-format mkv \
        -o "$OUTPUT_DIR/%(upload_date)s - %(title)s.%(ext)s" \
        --batch-file="$INPUT_FILE" \
        2>&1 | tee -a "$LOG_FILE"
    rc=${PIPESTATUS[0]}
else
    yt-dlp \
        --cookies "$HOME/.env_priv/max_yotebe_cookies.txt" \
        --add-metadata \
        --embed-metadata \
        --embed-chapters \
        --merge-output-format mkv \
        -o "$OUTPUT_DIR/%(upload_date)s - %(title)s.%(ext)s" \
        --batch-file="$INPUT_FILE"
    rc=$?
fi

# ---------- RESULT ----------
if [[ "$rc" -eq 0 ]]; then
    log_msg "✅ Download complete."
else
    log_msg "❌ yt-dlp exited with code $rc"
fi

log_msg "Finished at $(date)"
