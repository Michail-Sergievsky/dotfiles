#!/bin/bash
awk '/^#start_alias$/{f=1; c=0} f; /#end_alias$/ && ++c==1{f=0}' ~/.bash_aliases\
	| sed 's/^alias/command!/g'\
	| sed "s/='/ :!!/g"\
	| sed 's/="/ :!!/g'\
	| sed "s/'$//"\
	| sed '/^command! config/d'\
	| sed -e '1 d' -e'$ d' > ~/.config/vifm/vifm_aliases
