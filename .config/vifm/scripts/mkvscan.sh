#!/bin/bash
name=$(file "$1")
title=$(mediainfo "$1" | awk '/^General$/{f=1} f; /^Video$/ && ++c==1{exit}'\
						| grep -E '^File size|^Duration|^Overall bit rate|^Frame rate\s\s|^Encoded date|^Attachments ')
video1=$(mkvinfo "$1" | grep -E "Track type: video" -B5 -A9 | sed\
					-e '/+ Color matrix coefficients:/d'\
					-e '/+ Color primaries:/d'\
					-e '/+ Color transfer:/d'\
					-e '/+ "Forced display"/d'\
					-e '/+ Language/d'\
					-e '/+ Track type/d'\
					-e '/+ Video color information/d'\
					-e '/Codec.s private data./d'\
					-e '/Lacing/d'\
					-e '/Minimum cache/d'\
					-e '/Track UID/d'\
					-e '/Video track/d'\
					-e '/|   + Display height:/d'\
					-e '/|   + Display width:/d'\
					-e '/|  + "Default track" flag/d'\
					-e '/| + Segment UID/d'\
					-e '/| + Track/d'\
					-e '/|+ Tracks/d'\
					)
video2=$(mediainfo "$1" | grep -E "^Video$" -A18 | grep -E "^Stream size|^Frame rate" | sed '/^Frame rate mode/d')
audio1=$(mkvinfo "$1" | grep -E "Track type: audio" -B8 -A10 | sed\
					-e '/+ "Lacing" flag:/d'\
					-e '/+ "Lacing/d'\
					-e '/+ Attached$/d'\
					-e '/+ Attachments$/d'\
					-e '/+ Codec-inherent delay/d'\
					-e '/+ Color matrix coefficients/d'\
					-e '/+ Color primaries:/d'\
					-e '/+ Color range:/d'\
					-e '/+ Color transfer:/d'\
					-e '/+ EBML void:/d'\
					-e '/+ Maximum block additional/d'\
					-e '/+ Output sampling frequency/d'\
					-e '/+ Sampling frequency:/d'\
					-e '/+ Seek pre-roll/d'\
					-e '/+ Track type/d'\
					-e '/+ Video color information/d'\
					-e '/Codec.s private data./d'\
					-e '/Track UID/d'\
					-e '/^|   + Display height: /d'\
					-e '/^|   + Display width: /d'\
					-e '/^|   + Pixel height: /d'\
					-e '/^|   + Pixel width: /d'\
					-e '/^|  + Video track/d'\
					-e '/|    + Horizontal chroma siting:/d'\
					-e '/|    + Vertical chroma siting:/d'\
					-e '/|  + Audio track/d'\
					-e '/| + Track/d'\
					)
audio2=$(mediainfo "$1" | awk '/^Audio/{f=1} f; /^Text/ && ++c==1{exit}' | grep -E "^Stream size")
subs=$(mkvinfo "$1" | grep -E "Track type: subtitles" -B7 -A7 | sed\
					-e '/+ "Lacing" flag/d'\
					-e '/+ Codec.s private data/d'\
					-e '/+ Content compression/d'\
					-e '/+ Content encoding/d'\
					-e '/+ Maximum block additional/d'\
					-e '/+ Output sampling frequency/d'\
					-e '/+ Track type/d'\
					-e '/^Chapters$/d'\
					-e '/^|   + Channels:/d'\
					-e '/^|   + Sampling frequency:/d'\
					-e '/^|  + Audio track/d'\
					-e '/^|  + Track UID:/d'\
					-e '/^|+ Chapters/d'\
					-e '/|   + Name:/d'\
					-e '/|  + Simple/d'\
					-e '/|  + Targets/d'\
					-e '/| + Tag/d'\
					-e '/| + Track/d'\
					-e '/|+ Cluster/d'\
					-e '/|+ EBML void/d'\
					-e '/|+ Tags/d'\
					)
chapters=$(mediainfo "$1" | grep -E "^Menu$" -A1000\
					    )
echo -e "General\n$title"
echo -e "Video\n$video1\n$video2"
echo -e "Audio\n$audio1\n$audio2"
echo -e "Subtitles\n$subs"
echo -e "$chapters"
