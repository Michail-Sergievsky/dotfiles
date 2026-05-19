#!/bin/bash

# Input file containing YouTube links
INPUT_FILE="$HOME/Downloads/youtube/audio.txt"
OUTPUT_DIR="$HOME/Downloads/youtube/audio"
LOG_FILE="$HOME/Downloads/youtube/audio_download_log_$(date +%Y%m%d_%H%M%S).txt"

# Ensure the input file exists
if [[ ! -f $INPUT_FILE ]]; then
    echo "Error: Input file $INPUT_FILE not found."
    exit 1
fi

# Ensure the output directory exists
if [[ ! -d $OUTPUT_DIR ]]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Start logging
echo "Download log - $(date)" > "$LOG_FILE"

# Read the input file line by line
while IFS= read -r youtube_link; do
    # Skip empty lines
    if [[ -z "$youtube_link" ]]; then
        continue
    fi

    echo "Downloading: $youtube_link" | tee -a "$LOG_FILE"

    # Use yt-dlp to download audio
    output_file_template="$OUTPUT_DIR/%(title)s.%(ext)s"
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
        "$youtube_link" 2>>"$LOG_FILE")

    # Check if the download was successful
    if [[ $? -ne 0 ]]; then
        echo "Failed to download: $youtube_link" | tee -a "$LOG_FILE"
        continue
    else
        echo "Successfully downloaded: $youtube_link" | tee -a "$LOG_FILE"
        downloaded_count=$((downloaded_count + 1))
    fi

    # Replace .webm with .opus in the actual_file path
    actual_file=$(echo "$actual_file" | sed 's/\.webm$/.opus/')

    # Log the actual downloaded file
    echo "DEBUG: actual_file = '$actual_file'" | tee -a "$LOG_FILE"

    # Ensure the file exists
    if [[ -f "$actual_file" ]]; then
        track_name=$(mediainfo --Inform="General;%Title%" "$actual_file" | tr -d '\n')
        performer=$(mediainfo --Inform="General;%Performer%" "$actual_file" | tr -d '\n')

        # Log extracted metadata
        echo "Extracted metadata: Track Name='$track_name', Performer='$performer'" | tee -a "$LOG_FILE"

        # Generate the new filename
        if [[ "$track_name" == "$performer" ]]; then
            new_name="$OUTPUT_DIR/${track_name}.opus"
        else
            new_name="$OUTPUT_DIR/${performer} - ${track_name}.opus"
        fi

        # Rename the file
        mv "$actual_file" "$new_name"
        echo "Renamed $actual_file to $new_name" | tee -a "$LOG_FILE"
    else
        echo "DEBUG: File '$actual_file' does not exist. Metadata extraction skipped." | tee -a "$LOG_FILE"
    fi

done < "$INPUT_FILE"

# Final log entry
echo "Processing complete at $(date)" | tee -a "$LOG_FILE"
