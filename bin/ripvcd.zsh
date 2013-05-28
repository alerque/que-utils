#!/bin/zsh

id=$1

if [ "$id" = "" ]; then
	echo "Outout name or ID required"
	exit;
fi

mencoder vcd://2 -ovc x264 -x264encopts threads=auto:pass=1:turbo:bitrate=224:bframes=1:me=umh:partitions=all:trellis=1:qp_step=4:qcomp=0.7:direct_pred=auto:keyint=300 -vf scale=-10:-1,harddup -oac faac -faacopts br=192:mpeg=4:object=2 -channels 2 -srate 48000 -ofps 24000/1001 -o /dev/null
mencoder vcd://2 -ovc x264 -x264encopts threads=auto:pass=2:turbo:bitrate=224:bframes=1:me=umh:partitions=all:trellis=1:qp_step=4:qcomp=0.7:direct_pred=auto:keyint=300 -vf scale=-10:-1,harddup -oac faac -faacopts br=192:mpeg=4:object=2 -channels 2 -srate 48000 -ofps 24000/1001 -o $id.avi

eject /dev/cdrom

mplayer $id.avi -dumpaudio -dumpfile $id.aac
mplayer $id.avi -dumpvideo -dumpfile $id.h264

mp4creator -create=$id.aac $id.mp4
mp4creator -create=$id.h264 -rate=23.976 $id.mp4
mp4creator -hint=1 $id.mp4
mp4creator -hint=2 $id.mp4
mp4creator -optimize $id.mp4

rm *aac *.h264 *log
mkdir -p AVIs
mv *avi AVIs
