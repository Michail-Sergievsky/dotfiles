#
# SMY bashrc
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#Enable Alias in separete file
if [ -f ~/.bash_aliases ]; then
. ~/.bash_aliases
fi

#export private variables
if [ -f  ~/.env_priv/.env_priv_lines ]; then
. ~/.env_priv/.env_priv_lines
fi

#ignore upper and lowercase when TAB completion
bind "set completion-ignore-case on"

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=2000

# show timestamp in history
# export HISTTIMEFORMAT="%F %T "

#for vifm [bash aliases] NOT working
# shopt -s expand_aliases
# unset BASH_ENV
# set shellcmdflag=-lc

#Prompt
# export PS1='\[\033[00;30m\]\u@\[\033[00;34m\]\h \[\033[00;31m\]\W \$ \[\033[00m\]'
# 30m - color
PS1="\[\033[00;30m\]\u\
\[$(tput sgr0)\]\[\033[00;34m\]@\
\[$(tput sgr0)\]\[\033[00;31m\]\h\
\[$(tput sgr0)\]\[\033[00;15m\]\
 [\[$(tput sgr0)\]\[\033[38;5;30m\]\W\
\[$(tput sgr0)\]\[\033[00;15m\]]\
 \[\033[38;5;30m\]\$(parse_git_branch)\[\033[38;5;15m\]\[\033[00m\]\
\[$(tput sgr0)\]\[\033[38;5;9m\]>\
\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]"

# idicate - shell session is running inside vifm
if [ -n "$INSIDE_VIFM" ]; then
    PS1="[V]$PS1"
    unset INSIDE_VIFM
fi

#Arch pkgfile
source /usr/share/doc/pkgfile/command-not-found.bash

#dircolors
[ ! -e ~/.dircolors ] && eval $(dircolors -p > ~/.dircolors)
[ -e /bin/dircolors ] && eval $(dircolors -b ~/.dircolors)

#FZF-------
source /usr/share/fzf/key-bindings.bash
source /usr/share/fzf/completion.bash
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
# Shell-GPT integration BASH v0.2
_sgpt_bash() {
if [[ -n "$READLINE_LINE" ]]; then
    READLINE_LINE=$(sgpt --shell <<< "$READLINE_LINE" --no-interaction)
    READLINE_POINT=${#READLINE_LINE}
fi
}
# bind -x '"\C-i": _sgpt_bash'
# Shell-GPT integration BASH v0.2

#functions
_fzf_compgen_path() {
    fd . "$1"
}

_fzf_compgen_dir() {
    fd --type d . "$1"
}
_fzf_complete_git() {
  _fzf_complete -- "$@" < <(
    git --help -a | grep -E '^\s+' | awk '{print $1}'
  )
}

# Git command line
function parse_git_branch() 
{
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1) /'
}

neofetch

# The next line updates PATH for CLI.
if [ -f '/home/freeman/yandex-cloud/path.bash.inc' ]; then source '/home/freeman/yandex-cloud/path.bash.inc'; fi

# The next line enables shell command completion for yc.
if [ -f '/home/freeman/yandex-cloud/completion.bash.inc' ]; then source '/home/freeman/yandex-cloud/completion.bash.inc'; fi


#ssh-agent - only one process
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    ssh-agent -t 1h > "$XDG_RUNTIME_DIR/ssh-agent.env"
fi
if [[ ! -f "$SSH_AUTH_SOCK" ]]; then
    source "$XDG_RUNTIME_DIR/ssh-agent.env" >/dev/null
fi

