#!/usr/bin/env bash

: ${ppa:="ppa:sile-typesetter/sile"}

cd $HOME

set -euo pipefail
set -x

pkgname=$1
test -n "$pkgname"

pkgver=$2
test -n "$pkgver"

: ${pkgrel:=0}
: ${scriptepoch:=2}

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
		lua-cassowary)
			_tag=v$pkgver
			_pkgname=cassowary.lua
			archive=$_pkgname-$pkgver
			source=https://github.com/sile-typesetter/$_pkgname/$_tag/$archive.tar.gz
			;;
		lua-compat53)
			_tag=v$pkgver
			_pkgname=lua-compat-5.3
			archive=$_pkgname-$pkgver
			source=https://github.com/keplerproject/$_pkgname/archive/$_tag/$archive.tar.gz
			;;
		lua-epnf)
			_pkgname=lua-luaepnf
			_tag=v$pkgver
			archive=$_pkgname-$pkgver
			source=https://github.com/siffiejoe/$pkgname/archive/$_tag/$archive.tag.gz
			;;
		lua-linenoise)
			archive=$pkgname-$pkgver
			source=https://github.com/hoelzro/$pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-penlight)
			_pkgname=Penlight
			archive=$_pkgname-$pkgver
			source=https://github.com/lunarmodules/$_pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-repl)
			archive=$pkgname-$pkgver
			source=https://github.com/hoelzro/$pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-stdlib)
			_tag=release-v$pkgver
			archive=$pkgname-$_tag
			source=https://github.com/$pkgname/$pkgname/archive/$_tag/$archive.tar.gz
			;;
		lua-utf8)
			_pkgname=luautf8
			archive=$_pkgname-$pkgver
			source=https://github.com/starwing/$_pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-vstruct)
			_pkgname=vstruct
			archive=$_pkgname-$pkgver
			source=https://github/ToxicFog/$_pkgname/archive/$pkgver/$archive.tar.gz
			;;
		*)
			exit 1
			;;
	esac
	orig=${pkgname}_$pkgver.orig.tar.gz
	cd projects/distro-packaging/ppa
	test -f $orig || curl -fsSL $source -o $orig
	rm -rf $archive
	test -d $archive || tar xfva $orig
	cd $archive
	test -d debian || bzr branch --use-existing-dir lp:$pkgname .
	_pkgver="$pkgver-${pkgrel}ppa${scriptepoch}~${DISTRIB_ID,,}$DISTRIB_RELEASE"
	_commit="Build upstream release $pkgver for $DISTRIB_CODENAME"
	bzr revert debian/changelog
	dch -D $DISTRIB_CODENAME -v $_pkgver "$_commit"
	yes | sudo mk-build-deps -i ||:
	rm -f $pkgname-build-deps_${_pkgver}_*
	debuild -S -sA
	bzr commit -m "$_commit"
	bzr push :parent
	cd ..
	dput $ppa ${pkgname}_${_pkgver}_source.changes
	exit 0
fi

: ${zoo:=bionic focal impish jammy}

makedepends=(gpg curl bzr devscripts equivs openssh-server software-properties-common quilt)

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
		lxc config set $instance raw.idmap -
}

freshen () {
	instance=$1
	lxc exec $1 -- apt-get -y update
	lxc exec $1 -- apt-get -y dist-upgrade
	lxc exec $1 -- apt-get install -y ${makedepends[@]}
	lxc exec $1 -- add-apt-repository -y $ppa
	lxc exec $1 -- sed -i -e '/AllowAgentForwarding/s/^#//' /etc/ssh/sshd_config
	lxc exec $1 -- systemctl restart sshd
}

for animal in $zoo; do
	instance=$pkgname-$animal
	exists $instance || launch $instance $animal
	freshen $instance
	ssh-add -l | grep -q caleb # confirm ssh agent before start
	$GPG -s -o /dev/null <<< 'test' # confirm current agent locally before trying remote
	script=${0##$HOME/}
	ssh $(ipof $instance) -l ubuntu -tt -A -- "pkgrel=$pkgrel scriptepoch=$scriptepoch $script $*" || continue
done
