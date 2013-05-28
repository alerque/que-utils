#!/bin/zsh

COLOR_INIT=yes
. /etc/init.d/functions
INIT_COL=$(($COLUMNS-8))

clear=n
author=caleb
dst="/home/users/caleb/pictures"
src="/mnt/sdj1"
tags=""
date "+%Y-%m-%d" | read ts
dupcheck=false

function flunk () {
	sudo umount $src
	show "Operation failed: $*"; fail
	exit
}

while [ $# -gt 0 ]; do
	case $1 in
		-s|--source)
			shift
			src=$1
			shift
			;;
		-d|--dups)
			shift
			dupcheck=true
			;;
		-t|--tag)
			shift
			tags="$tags-$1"
			;;
		-c|--clear)
			clear=y
			;;
		-a|--author)
			shift
			author=$1
			;;
		-t|--date)
			shift
			ts=$1
			;;
	esac
	shift
done

is_yes $clear && cmd=mv || cmd=cp

show "Setting up transfer options. (cmd=$cmd author=$author tags=$tags)"; ok
show "Waiting for a disk"; busy
while ! mount $src 2> /dev/null; do
#while ! mount | grep -q $src 2> /dev/null; do
	echo "Waiting for mount of $src"
	sleep 1
done && ok

## All set go!
dir="$dst/$ts/$author$tags"

show "Preparing $dir"; busy
mkdir -p "$dir" && ok || flunk "Failed to make target directory"

count=0

show "Processing files"; busy

find $src -type f |
	pcregrep -i '\.(jpg|jpeg|png|wav|mov|tiff|raw|dcr|gif|bmp|cr2|avi|mpeg|mpg)$' |
	while read file; do
		stat=`printf "%4d" $count`
#		if [ "$dupcheck" = "true" ]; then
#			continue
#		fi
		$cmd "$file" "$dir" && progress $stat || flunk "Failed to $cmd $file to $dir"
		let count=$count+1
	done && ok

if [ $count -gt 0 ]; then
	show "Transfered $count files"; ok
else
	show "No files to transfer"; ok
fi

## Cleanup
chown -R caleb:users "$dir"
rmdir -p "$dir" 2> /dev/null
show "Unmounting disk"
sudo umount $src && ok || fail
