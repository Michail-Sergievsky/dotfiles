#	Ataru Bash Aliases

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# alias ll='ls -AHlhg'
alias ll='ls --group-directories-first -lHAv'
# -v                         natural sort of (version) numbers within text
# -H, --dereference-command-line
#                            follow symbolic links listed on the command line
# -A, --almost-all           do not list implied . and ..
# -l                         use a long listing format


#start_alias
alias br='. ~/.bashrc'
alias s1='cd ~/Work/simpleone/simple_work/'
alias upd='sudo pacman -Syu && yay -Syu'
alias ssh='kitten ssh'
alias vag='cd ~/Vagrant'
alias conn='nmcli conn show'
alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'
alias smarton='aft-mtp-mount ~/Phone'
alias smartoff='fusermount -u ~/Phone'
alias smartsync='$HOME/.scripts/files_rsync_music_phone.sh'
alias asciidoc2pdf='$HOME/.local/share/asciidoc2pdf/asciidoc2pdf'
alias la='awk "/#start/{s=NR;p=1;next}/#end/{p=0}p&&NR>s" ~/.bash_aliases'
alias mirr='mpv av://v4l2:/dev/video0 --profile=low-latency --untimed'
alias genpass='pwgen -n 16 1 | tee >(wl-copy) > /dev/null'
alias reflec='sudo reflector -c Russia -a 10 --sort rate --save /etc/pacman.d/mirrorlist'
alias hosts='sudo nvim /etc/hosts'
alias work='cd ~/Downloads/work'
alias cdx='cd ~/Codex/home-admin && ~/.scripts/codex resume --last'
alias cdxn='cd ~/Codex/home-admin && ~/.scripts/codex'
alias viv='cd ~/Git_work/viva-it/'
alias tok='ssh-add -s /usr/lib64/librtpkcs11ecp.so'
alias y_down='$HOME/.scripts/download_ytdl.sh'
alias yedit='nvim ~/Downloads/youtube/inbox.txt'
alias ydone='less ~/Downloads/youtube/inbox.done.txt'
alias yfail='less ~/Downloads/youtube/inbox.failed.txt'
alias yhist='less ~/Downloads/youtube/inbox.history.tsv'
alias atog='~/.scripts/audio_toggle_notebook.sh'
alias fed='cd ~/Vagrant/fedora && vagrant ssh fedora40work'
#end_alias
