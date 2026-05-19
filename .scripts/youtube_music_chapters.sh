#!/bin/bash

WORK_DIR="$HOME/Downloads/youtube/music"
INPUT_FILE="$HOME/Downloads/youtube/music_chapters.txt"
COOKIES="$HOME/.env_priv/max_yotebe_cookies.txt"

mkdir -p "$WORK_DIR"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Input file not found: $INPUT_FILE"
    exit 1
fi

fix_metadata() {
    local album_dir="$1"
    local album_title="$2"

    find "$album_dir" -maxdepth 1 -type f -name "*.opus" | sort | while IFS= read -r file; do
        local base title

        base="$(basename "$file" .opus)"
        title="$base"

        python3 - "$file" "$title" "$album_title" <<'PY'
import sys
from mutagen.oggopus import OggOpus

path = sys.argv[1]
title = sys.argv[2]
album = sys.argv[3]

audio = OggOpus(path)

# Remove all old inherited YouTube / yt-dlp tags
audio.clear()

# Write only clean useful tags
audio["title"] = [title]
audio["album"] = [album]

audio.save()
PY

        if [[ $? -eq 0 ]]; then
            echo "Metadata fixed: $(basename "$file") -> title='$title'"
        else
            echo "Metadata rewrite FAILED: $file"
        fi
    done
}

while IFS= read -r url || [[ -n "$url" ]]; do
    [[ -z "$url" ]] && continue

    echo "=================================================="
    echo "Processing URL: $url"

    yt-dlp \
        --cookies "$COOKIES" \
        --ignore-errors \
        --yes-playlist \
        --paths "$WORK_DIR" \
        -f bestaudio \
        --extract-audio \
        --audio-format opus \
        --audio-quality 0 \
        --embed-chapters \
        --split-chapters \
        -o "%(title)s/_full.%(ext)s" \
        -o "chapter:%(title)s/%(section_number)02d - %(section_title)s.%(ext)s" \
        "$url"

    if [[ $? -ne 0 ]]; then
        echo "FAILED: $url"
        continue
    fi

    # Remove full unsplit files, keep only chapter files
    find "$WORK_DIR" -type f \( -name "_full.opus" -o -name "_full.webm" -o -name "_full.m4a" \) -delete

    # Fix metadata for all album folders with .opus files
    find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r album_dir; do
        if find "$album_dir" -maxdepth 1 -type f -name "*.opus" | grep -q .; then
            album_title="$(basename "$album_dir")"
            fix_metadata "$album_dir" "$album_title"
        fi
    done

    echo "DONE: $url"

done < "$INPUT_FILE"

echo "=================================================="
echo "Finished at $(date)"
