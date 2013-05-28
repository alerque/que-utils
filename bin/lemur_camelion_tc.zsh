#!/bin/zsh

dev=eth0

[ "$1" = "" ] && 1=400

/sbin/tc qdisc del dev $dev root
[ "$1" = "clear" ] && exit

function addfilter () {
	flow=$1
	ip=$2
	prio=1
	if [ "$3" != "" ]; then
		prio=20
	fi
	/sbin/tc filter add dev $dev parent 1:0 protocol ip prio $prio u32 match ip dst $ip flowid $flow $=3
	/sbin/tc filter add dev $dev parent 1:0 protocol ip prio $prio u32 match ip src $ip flowid $flow $=3
}

function setflow () {
	handle=$1
	flow=1:$handle
	kbps=$2
	burst=$3
	/sbin/tc class add dev $dev parent 1:1 classid $flow htb rate ${kbps}kbps ceil ${kbps}kbps burst ${burst}kb quantum 1500
	if [ "$handle" = "10" ]; then 
		/sbin/tc qdisc add dev $dev parent $flow handle $handle: pfifo
	else
		/sbin/tc qdisc add dev $dev parent $flow handle $handle: sfq perturb 10
	fi
}

/sbin/tc qdisc add dev $dev root handle 1: htb default 20

setflow 10 100000 1000
setflow 20 100000 1000
setflow 30 $1 100

# camelion
addfilter 1:30 75.101.155.225/32

# Everything Else
addfilter 1:20 0.0.0.0/0 "police mpu 0 action drop"
