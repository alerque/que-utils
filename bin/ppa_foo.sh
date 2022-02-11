#!/usr/bin/env bash

cd $HOME

set -euo pipefail
set -x

pkgname=$1
test -n "$pkgname"

pkgver=$2
test -n "$pkgver"

GPG="gpg --no-greeting --armor --use-agent --lock-never --no-permission-warning --no-autostart --pinentry-mode loopback"

if systemd-detect-virt | grep -Fxq lxc; then
	# GPG+=" --no-tty"
	source /etc/lsb-release
	source .bashrc
	env | grep -q DEBEMAIL
	bzr whoami | grep -q Caleb
	ssh-add -l | grep -q caleb
	env
	$GPG -s -o /dev/null <<< 'test'
	case $pkgname in
		lua-penlight)
			_pkgname=Penlight
			_archive=$_pkgname-$pkgver
			source=https://github.com/lunarmodules/$_pkgname/archive/refs/tags/$pkgver/$_archive.tar.gz
			orig=${pkgname}_$pkgver.orig.tar.gz
			;;
		*)
			exit 1
			;;
	esac
	cd projects/distro-packaging/ppa
	test -f $orig || curl -fsSL $source -o $orig
	test -d $_archive || tar xfva $orig
	cd $_archive
	test -d debian || bzr branch --use-existing-dir lp:$pkgname .
	exit 0
fi

# foo=(18.04 20.04 21.10) # 22.04

zoo=(bionic focal impish) # jammy
: ${ppa:="ppa:sile-typesetter/sile"}

makedepends=(gpg curl bzr devscripts equivs openssh-server software-properties-common)

ipof () {
	lxc list -f json $1 | jq -r '.[0].state.network.eth0.addresses[] | select(.family == "inet").address'
}

exists () {
	instance=$1
	lxc list -f json $instance | jq -r '.[].name' | grep -Fxq $instance
}

launch () {
	instance=$1
	animal=$2
	lxc launch images:ubuntu/$animal $instance -c security.privileged=true
	lxc config device add $instance home disk source=$HOME path=/home/ubuntu
	printf "uid $(id -u) 1000\ngid $(id -g) 1000" |
		lxc config set $animal raw.idmap -
}

freshen () {
	instance=$1
	# lxc exec $1 -- add-apt-repository -y $ppa
	# lxc exec $1 -- apt-get -y update
	# lxc exec $1 -- apt-get -y dist-upgrade
	# lxc exec $1 -- apt-get install -y $makedepends
	lxc exec $1 -- sed -i -e '/AllowAgentForwarding/s/^#//' /etc/ssh/sshd_config
	lxc exec $1 -- systemctl restart sshd
}

for animal in ${zoo[@]}; do
	instance=$pkgname-$animal
	# exists $instance || launch $instance $animal
	# freshen $instance
	ssh-add -l | grep -q caleb # confirm ssh agent before start
	$GPG -s -o /dev/null <<< 'test' # confirm current agent locally before trying remote
	script=${0##$HOME/}
	ssh $(ipof $instance) -l ubuntu -tt -A -- "$script $*"
done
