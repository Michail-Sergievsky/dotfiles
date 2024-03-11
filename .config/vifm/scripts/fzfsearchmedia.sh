#!/bin/bash
rg -i --files-with-matches --no-messages "/home/freeman/Dropbox/Look.out.for.them.all/" | fzf --preview "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 '$1' || rg --ignore-case --pretty --context 10 '$1' {}"
