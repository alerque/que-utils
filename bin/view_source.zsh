#!/bin/zsh

file=$1

cat $file |
	tidy -f /dev/null -i -wrap 4000 -bq -asxhtml |
	perl -pne 's/  /	/g' |
	grep -v '^$' |
	vim - -R "+map q :qa!<enter>" "+unmap <C-c><C-c>" "+map <C-c> :qa!<enter>" "+set ft=html ts=2" "+vsplit $file" "+set mouse=a"
