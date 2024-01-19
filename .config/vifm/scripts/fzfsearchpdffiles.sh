#!/bin/bash
pdfgrep --with-filename -r "$1" * | fzf 2> /dev/tty | awk -F '.pdf:' '{print $1}' | sed 's/$/.pdf/'
