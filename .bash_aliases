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
alias vpn_on='sudo systemctl start openvpn-client@media-tel-vpn'
alias vpn_off='sudo systemctl stop openvpn-client@media-tel-vpn'
alias vpn_st='systemctl status openvpn-client@media-tel-vpn'
alias vag='cd /home/freeman/Vagrant'
alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'
alias con='/home/freeman/.scripts/connect.sh'
alias smarton='aft-mtp-mount ~/Phone'
alias smartoff='fusermount -u ~/Phone'
alias smartsync='/home/freeman/.scripts/sync_music_phone.sh'
alias asciidoc2pdf='/home/freeman/.local/share/asciidoc2pdf/asciidoc2pdf'

# alias nt="task add $1"
# alias tl="task list"

taskprojectfunction () {
    task $1 modify project:$2
}
alias tproj=taskprojectfunction 

tasktagfunction () {

 task $1 modify +$2 +$3 +$4
}
alias ttag=tasktagfunction
