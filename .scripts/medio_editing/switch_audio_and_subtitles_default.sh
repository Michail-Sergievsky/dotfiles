#!/bin/bash
# Function to remove default and forced flags from tracks and set default audio and subtitle tracks
remove_flags_and_set_defaults() {
    filename="$1"
    audio_tracks=()
    subtitle_tracks=()

    # Collect track numbers for audio and subtitle tracks
    while IFS= read -r line; do
        track_number=$(echo "$line" | cut -d " " -f 6)
        track_type=$(mkvinfo "$filename" | grep -A 3 "Track number: $track_number" | grep "Track type" | cut -d " " -f 6)
        
        if [ "$track_type" == "audio" ]; then
            audio_tracks+=("$track_number")
        elif [ "$track_type" == "subtitles" ]; then
            subtitle_tracks+=("$track_number")
        fi
    done < <(mkvinfo "$filename" | grep -E "Track number: [0-9]+")

    # Remove default and forced flags from audio and subtitle tracks
    mkvpropedit_command="mkvpropedit \"$filename\""
    for track_number in "${audio_tracks[@]}" "${subtitle_tracks[@]}"; do
        mkvpropedit_command+=" --edit track:$track_number --set flag-default=0 --set flag-forced=0"
    done

    # Set default audio and subtitle tracks
    # mkvpropedit_command+=" --edit track:${audio_tracks[0]} --set flag-default=1"  # Set the first audio track as default
    # mkvpropedit_command+=" --edit track:${subtitle_tracks[0]} --set flag-default=1"  # Set the first subtitle track as default
    mkvpropedit_command+=" --edit track:$default_audio --set flag-default=1 --set flag-forced=0 --set language=$audio_lang"
    mkvpropedit_command+=" --edit track:$default_subtitles --set flag-default=1 --set flag-forced=0 --set language=$subs_lang"

    # Apply modifications using a single mkvpropedit command
    eval "$mkvpropedit_command"
    echo "Set track ${audio_tracks[0]} as default audio track"
    echo "Set track ${subtitle_tracks[0]} as default subtitle track"
}

select_tracks() {
    filename="$1"
    audio_tracks=()
    subtitle_tracks=()

    # Collect track number, language, title for audio and subtitle tracks
    echo "Audio Tracks:"
    while IFS= read -r line; do
        track_number=$(echo "$line" | cut -d " " -f 6)
        track_type=$(mkvinfo "$filename" | grep -A 3 "Track number: $track_number" | grep "Track type" | cut -d " " -f 6)
        track_language=$(mkvinfo "$filename" | grep -A 8 "Track number: $track_number" | grep "Language")   
        track_title=$(mkvinfo "$filename" | grep -A 12 "Track number: $track_number" | grep "Name" | cut -d " " -f 6)
        if [ "$track_type" == "audio" ]; then
            echo "Track number: $track_number, Language: $track_language, Title: $track_title"
            audio_tracks+=("$track_number")
        fi
    done < <(mkvinfo "$filename" | grep -E "Track number: [0-9]+")

    echo "Subtitles Tracks:"
    while IFS= read -r line; do
        track_number=$(echo "$line" | cut -d " " -f 6)
        track_type=$(mkvinfo "$filename" | grep -A 3 "Track number: $track_number" | grep "Track type" | cut -d " " -f 6)
        track_language=$(mkvinfo "$filename" | grep -A 8 "Track number: $track_number" | grep "Language")   
        track_title=$(mkvinfo "$filename" | grep -A 10 "Track number: $track_number" | grep "Name")
        if [ "$track_type" == "subtitles" ]; then
            echo "Track number: $track_number, Language: $track_language, Title: $track_title"
            subtitle_tracks+=("$track_number")
        fi
    done < <(mkvinfo "$filename" | grep -E "Track number: [0-9]+")

    # Prompt user to choose default audio and subtitle tracks
    echo "Select default audio track:"
    select audio_track_number in "${audio_tracks[@]}"; do
        if [[ " ${audio_tracks[@]} " =~ " $audio_track_number " ]]; then
        	default_audio=$audio_track_number 
        	echo $default_audio
            # mkvpropedit "$filename" --edit track:$audio_track_number --set flag-default=1
            # echo "Set track $audio_track_number as default audio track"
            break
        else
            echo "Invalid selection. Please choose a valid audio track."
        fi
    done

    echo "Print language code for audio"
	read -r audio_lang;
	if [ -z "$audio"  ]
	  then
	    audio_lang=jpn
	fi

    echo "Select default subtitle track (enter 0 for none):"
    select subtitle_track_number in "${subtitle_tracks[@]}" "0"; do
        if [[ "$subtitle_track_number" == "0" ]]; then
            echo "No default subtitle track selected"
            break
        elif [[ " ${subtitle_tracks[@]} " =~ " $subtitle_track_number " ]]; then
        	default_subtitles=$subtitle_track_number 
        	echo $default_subtitles
            # mkvpropedit "$filename" --edit track:$subtitle_track_number --set flag-default=1
            # echo "Set track $subtitle_track_number as default subtitle track"
            break
        else
            echo "Invalid selection. Please choose a valid subtitle track or enter 0 for none."
        fi
    done

	echo "Print language code for subtitles"
	read -r subs_lang;
	if [ -z "$subs_lang"  ]
	  then
	    subs_lang=eng
	fi

}

# Find all MKV files in the current directory
first_file=$(find . -maxdepth 1 -type f -name '*.mkv' | sort | head -n 1 | cut -c 3-)
select_tracks "$first_file"

# work on all mkv files in current dir
find . -maxdepth 1 -type f -name '*.mkv' | {
	while read -r file ; do
		echo $file
		remove_flags_and_set_defaults "$file"
	done
}


