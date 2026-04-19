#!/bin/bash
rsync -urvP --delete --exclude '.thumbnails' /home/freeman/Music/music_sorted/ /home/freeman/Phone/Internal\ storage/Music/ | grep -E '^deleting|[^/]$'
