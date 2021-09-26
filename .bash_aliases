#	Aliases

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
alias reload="source .bashrc"
alias reloada="source .bash_alias"
alias dirh='cat ~/help'
alias vd='vifm .'
alias vimrc='vim /home/freeman/.vim/vimrc'
alias vifmrc='vim /home/freeman/.config/vifm/vifmrc'

alias vpn_on='systemctl start openvpn-client@media-tel-vpn'
alias vpn_off='systemctl stop openvpn-client@media-tel-vpn'
alias vpn_st='systemctl status openvpn-client@media-tel-vpn'

alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'

alias nt="task add $1"
alias tl="task list"

taskprojectfunction () {
    task $1 modify project:$2
}
alias tproj=taskprojectfunction 

tasktagfunction () {

 task $1 modify +$2 +$3 +$4
}
alias ttag=tasktagfunction
