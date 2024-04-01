#	SMY Bash Aliases

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
alias upd='sudo pacman -Syu && yay -Syu'
alias vag='cd ~/Vagrant'
alias vpnon='wg-quick up wg-pc-client'
alias vpnoff='wg-quick down wg-pc-client'
alias conn='nmcli conn show'
alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'
alias con='$HOME/.scripts/connect_to_ssh.sh'
alias smarton='aft-mtp-mount ~/Phone'
alias smartoff='fusermount -u ~/Phone'
alias smartsync='$HOME/.scripts/rsync_music_phone.sh'
alias asciidoc2pdf='$HOME/.local/share/asciidoc2pdf/asciidoc2pdf'
alias la='awk "/#start/{s=NR;p=1;next}/#end/{p=0}p&&NR>s" ~/.bash_aliases'
alias mirr='mpv av://v4l2:/dev/video0 --profile=low-latency --untimed'
alias iwmh='grep -E "^bindsym" $HOME/.config/i3/config | less'
alias genpass='</dev/urandom tr -dc "1234567890-=!@#$%^&*()_=qwertyuiop[]QWERTYUIOP{}asdfghjkl;\ASDFGHJKL:zxcvbnm,./ZXCVBNM<>?" | head -c16; echo ""'
alias pstr='i3-gnome-pomodoro start'
alias pstop='i3-gnome-pomodoro stop'
alias ptog='i3-gnome-pomodoro toggle'
alias pres='i3-gnome-pomodoro reset'
alias pskip='i3-gnome-pomodoro skip'
alias pstat='i3-gnome-pomodoro status'
alias reflec='sudo reflector -c Russia -a 7 --sort rate --save /etc/pacman.d/mirrorlist'
#end_alias
