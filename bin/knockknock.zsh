#!/bin/zsh
#
# Tripwire script to keep a running log of when and were from I login. I expect
# looking at this data to help make better security decisions such as mangeing
# ssh keys and firewall rules.
#

type mail 2> /dev/null || exit

date | read d
whoami | read u

function h () {
	echo
	echo "---------- Output of $1 ----------"
	echo
}

function show_out() {
	h "$*"
	$*
}

function show_env() {
#	h "$*"
	env | grep "^$1" 
}

(
	show_env SSH_
	show_env TTY
	show_env STY
	show_out last -n 10
	show_out last -n 10 $u
	show_out who
	show_out ps -ejH
	show_out tmux ls
) |
	iconv -f UTF8 -t LATIN1 - |
	perl -pne 's/[^-_:;.=+\/a-z0-9 \n\(\)]//ig' |
	mail -s "Knock Knock $u@$HOSTNAME: $d" caleb@camelion.alerque.com
