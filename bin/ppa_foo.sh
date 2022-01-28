#!/usr/bin/env bash

set -e
set -x

pkgname=$1
test -n "$pkgname"

# if grep -q "Ubuntu" /etc/lsb-release; then
if systemd-detect-virt | grep -Fxq lxc; then
	source /etc/lsb-release
	pkgver=$2
	test -n "$pkgver"
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
	bzr branch --use-existing-dir lp:$pkgname .
	exit
fi

# foo=(18.04 20.04 21.10) # 22.04

zoo=(bionic focal impish) # jammy
: ${ppa:="ppa:sile-typesetter/sile"}

exists () {
	lxc list -f json $1 | jq -r '.[].name' | grep -Fxq $1
}

launch () {
	lxc launch images:ubuntu/$1 $2 -c security.privileged=true
	lxc config device add $1 home disk source=$HOME path=/home/ubuntu
	printf "uid $(id -u) 1000\ngid $(id -g) 1000" |
		lxc config set $1 raw.idmap -
	freshen $1
}

freshen () {
	return
	lxc exec $1 -- add-apt-repository $ppa
	lxc exec $1 -- apt-get -y update
	lxc exec $1 -- apt-get -y dist-upgrade
	lxc exec $1 -- \
		apt-get install -y gpg curl bzr devscripts equivs software-properties-common
}

for animal in $zoo; do
	instance=$pkgname-$animal
	exists $instance && freshen $instance || launch $animal $instance
	lxc exec $instance -- su ubuntu -l -c "$0 $pkgname $2"
done
