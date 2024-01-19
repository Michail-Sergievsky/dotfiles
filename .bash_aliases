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

#everything
alias upd='sudo pacman -Syu && yay -Syu'
alias reload="source ~/.bashrc"
alias reloada="source ~/.bash_aliases"
alias vd='vifm .'
alias vimrc='vim $HOME/.vim/vimrc'
alias vifmrc='vim $HOME/.config/vifm/vifmrc'
alias vpn_on='wg-quick up wg-client'
alias vpn_off='wg-quick down wg-client'
alias vpnkr_on='sudo systemctl start openvpn-client@media-tel-vpn'
alias vpnkr_off='sudo systemctl stop openvpn-client@media-tel-vpn'
alias vpnkr_st='systemctl status openvpn-client@media-tel-vpn'
alias vag='cd $HOME/Vagrant'
alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'
alias con='$HOME/.scripts/connect_to_ssh.sh'
alias smarton='aft-mtp-mount ~/Phone'
alias smartoff='fusermount -u ~/Phone'
alias smartsync='$HOME/.scripts/rsync_music_phone.sh'
alias asciidoc2pdf='$HOME/.local/share/asciidoc2pdf/asciidoc2pdf'
alias la='awk "/#mark/{s=NR;p=1;next}/#/{p=0}p&&NR>s" .bash_aliases'
alias mirr='mpv av://v4l2:/dev/video0 --profile=low-latency --untimed'
alias i3h='grep -E "^bindsym" $HOME/.config/i3/config | less'
alias genpass='</dev/urandom tr -dc "1234567890-=!@#$%^&*()_=qwertyuiop[]QWERTYUIOP{}asdfghjkl;\ASDFGHJKL:zxcvbnm,./ZXCVBNM<>?" | head -c12; echo ""'
