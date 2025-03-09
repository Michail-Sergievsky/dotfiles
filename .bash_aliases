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
alias vivaon='nmcli conn up viva_online --ask'
alias vivaoff='nmcli conn down viva_online'
alias collon='nmcli conn up viva_collect --ask'
alias colloff='nmcli conn down viva_collect'
alias mksvon='nmcli conn up mediatel_msk'
alias mksvoff='nmcli conn down mediatel_msk'
alias krdvon='nmcli conn up mikhail.sergievsky-krd'
alias krdvoff='nmcli conn down mikhail.sergievsky-krd'
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
alias setx='setxkbmap "us,ru" ",winkeys" "grp:alt_space_toggle,grp_led:scroll"'
alias hosts='sudo vim /etc/hosts'
alias work='cd ~/Downloads/work'
alias viv='cd ~/Git_work/viva-it/'
alias tok='ssh-add -s /usr/lib64/librtpkcs11ecp.so'
alias a_down='$HOME/.scripts/youtube_only_audio_download.sh'
alias abatch_down='$HOME/.scripts/youtube_audio_batch_download.sh'
alias v_down='yt-dlp --cookies ~/.env_priv/max_yotebe_cookies.txt --add-metadata --parse-metadata "title:%(uploader)" -f 'bestvideo[height=1080]+bestaudio' -o "~/Downloads/youtube/video/%(title)s.%(ext)s" --batch-file=~/Downloads/youtube/your_links.txt'
alias fed="ssh fedora40lab1"
alias t="task"
#end_alias
