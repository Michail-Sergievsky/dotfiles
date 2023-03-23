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

alias upd='sudo pacman -Syu && yay -Syu'
alias reload="source ~/.bashrc"
alias reloada="source ~/.bash_aliases"
alias vd='vifm .'
alias vimrc='vim /home/freeman/.vim/vimrc'
alias vifmrc='vim /home/freeman/.config/vifm/vifmrc'
alias vpn_on='wg-quick up wg-client'
alias vpn_off='wg-quick down wg-client'
alias vpnkr_on='sudo systemctl start openvpn-client@media-tel-vpn'
alias vpnkr_off='sudo systemctl stop openvpn-client@media-tel-vpn'
alias vpnkr_st='systemctl status openvpn-client@media-tel-vpn'
alias vag='cd /home/freeman/Vagrant'
alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'
alias con='/home/freeman/.scripts/connect.sh'
alias smarton='aft-mtp-mount ~/Phone'
alias smartoff='fusermount -u ~/Phone'
alias smartsync='/home/freeman/.scripts/sync_music_phone.sh'
alias asciidoc2pdf='/home/freeman/.local/share/asciidoc2pdf/asciidoc2pdf'

