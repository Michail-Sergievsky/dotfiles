#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#Enable Alias in separete file
if [ -f ~/.bash_aliases ]; then
. ~/.bash_aliases
fi

#ignore upper and lowercase when TAB completion
bind "set completion-ignore-case on"

export HISTCONTROL=ignoreboth
export PS1='\[\033[00;30m\]\u@\[\033[00;34m\]\h \[\033[00;31m\]\W \$ \[\033[00m\]'

#Arch pkgfile
# source /usr/share/doc/pkgfile/command-not-found.bash

#dircolors
[ ! -e ~/.dircolors ] && eval $(dircolors -p > ~/.dircolors)
[ -e /bin/dircolors ] && eval $(dircolors -b ~/.dircolors)

#FZF-------
#Fedora style
source /usr/share/fzf/shell/key-bindings.bash
source /usr/share/fzf/shell/completion.bash
#Arch style
# source /usr/share/fzf/key-bindings.bash
# source /usr/share/fzf/completion.bash
export FZF_DEFAULT_COMMAND="fd --hidden --follow --exclude '.git' --exclude 'node_modules'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="$FZF_DEFAULT_COMMAND --type d"
export FZF_DEFAULT_OPTS="
--layout=reverse
--info=inline
--height=80%
--multi
--preview-window=:hidden
--preview '([[ -f {} ]] && (bat --style=numbers --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200'
--color='hl:148,hl+:154,pointer:032,marker:010,bg+:237,gutter:008'
--prompt='~ ' --pointer='>' --marker='+'
--bind '?:toggle-preview'
--bind 'ctrl-a:select-all'
--bind 'ctrl-y:execute-silent(echo {+} | xclip -selection clipboard)'
--bind 'ctrl-e:execute(echo {+} | xargs -o vim)'
"

#functions

_fzf_compgen_path() {
    fd . "$1"
}

_fzf_compgen_dir() {
    fd --type d . "$1"
}
#---------fzf

#gvim-to-vim Fedora
export EDITOR="gvim -v"
export VISUAL="$EDITOR"

neofetch
