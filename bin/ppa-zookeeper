#!/usr/bin/env bash

: ${ppa:="ppa:sile-typesetter/sile"}

cd $HOME

set -euo pipefail
set -x

: ${zoo:=jammy mantic noble}
: ${pkgset:=$(eval echo lua-{compat53,repl,linenoise,vstruct,utf8,epnf,loadkit,penlight,cassowary,cldr,fluent} sile fontproof)}

makedepends=(gpg curl bzr devscripts equivs openssh-server software-properties-common quilt)

ipof () {
	instance=$1
	lxc list -f json name=$instance | jq -r '.[0].state.network.eth0.addresses[] | select(.family == "inet").address'
}

exists () {
	instance=$1
	lxc list -f json name=$instance | jq -r '.[].name' | grep -Fxq $instance
}

launch () {
	instance=$1
	animal=$2
	exists $instance && run $instance || create $instance $animal
}

run () {
	instance=$1
	lxc list -f json status=running | jq -r '.[].name' | grep -Fxq $instance || lxc start $instance
}

create () {
	instance=$1
	animal=$2
	lxc launch ubuntu-daily:$animal $instance -c security.privileged=true
	lxc config device add $instance home disk source=$HOME path=/home/ubuntu
	printf "uid $(id -u) 1000\ngid $(id -g) 1000" |
		lxc config set $instance raw.idmap -
	freshen $instance
}

freshen () {
	instance=$1
	lxc exec $1 -- apt-get -y update
	lxc exec $1 -- apt-get -y dist-upgrade
	lxc exec $1 -- apt-get install -y ${makedepends[@]}
	lxc exec $1 -- add-apt-repository -y $ppa ||:
	lxc exec $1 -- sed -i -e '/AllowAgentForwarding/s/^#//' /etc/ssh/sshd_config
	lxc exec $1 -- systemctl enable ssh
	lxc exec $1 -- systemctl restart ssh
}

if [[ -v 'FRESHEN' ]]; then
	# N=8; i=1
	(
	for animal in $zoo; do
		for pkgname in $pkgset; do
			# ((i=i%N)); ((i++==0)) && wait ||:
			(
			instance=$pkgname-$animal
			launch $instance $animal
			freshen $instance
			) &
		done
	done
	wait
	)
	exit 0
fi

pkgname=$1
test -n "$pkgname"

pkgver=$2
test -n "$pkgver"

: ${pkgrel:=1}
: ${scriptepoch:=1}

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
		lua-compat53)
			_tag=v$pkgver
			_pkgname=lua-compat-5.3
			archive=$_pkgname-$pkgver
			source=https://github.com/lunarmodules/$_pkgname/archive/$_tag/$archive.tar.gz
			;;
		lua-repl)
			archive=$pkgname-$pkgver
			source=https://github.com/hoelzro/$pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-linenoise)
			archive=$pkgname-$pkgver
			source=https://github.com/hoelzro/$pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-vstruct)
			_pkgname=vstruct
			archive=$_pkgname-$pkgver
			source=https://github/ToxicFog/$_pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-utf8)
			_pkgname=luautf8
			archive=$_pkgname-$pkgver
			source=https://github.com/starwing/$_pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-epnf)
			_pkgname=lua-luaepnf
			_tag=v$pkgver
			archive=$_pkgname-$pkgver
			source=https://github.com/siffiejoe/$pkgname/archive/$_tag/$archive.tag.gz
			;;
		lua-loadkit)
			_pkgname=loadkit
			_tag=v$pkgver
			archive=$_pkgname-$pkgver
			source=https://github.com/leafo/$_pkgname/archive/$_tag/$archive.tar.gz
			;;
		lua-penlight)
			_pkgname=Penlight
			archive=$_pkgname-$pkgver
			source=https://github.com/lunarmodules/$_pkgname/archive/$pkgver/$archive.tar.gz
			;;
		lua-cassowary)
			_tag=v$pkgver
			_pkgname=cassowary.lua
			archive=$_pkgname-$pkgver
			source=https://github.com/sile-typesetter/$_pkgname/archive/$_tag/$archive.tar.gz
			;;
		lua-cldr)
			_pkgname=cldr-lua
			_tag=v$pkgver
			archive=$_pkgname-$pkgver
			source=https://github.com/alerque/$_pkgname/archive/$_tag/$archive.tar.gz
			;;
		lua-fluent)
			_pkgname=fluent-lua
			_tag=v$pkgver
			archive=$_pkgname-$pkgver
			source=https://github.com/alerque/$_pkgname/archive/$_tag/$archive.tar.gz
			;;
		sile)
			_tag=v$pkgver
			archive=$pkgname-$pkgver
			source=https://github.com/sile-typesetter/$pkgname/releases/download/$_tag/$archive.tar.xz
			orig=${pkgname}_$pkgver.orig.tar.xz
			;;
		fontproof)
			_tag=v$pkgver
			archive=$pkgname-$pkgver
			source=https://github.com/sile-typesetter/$pkgname/archive/$_tag/$archive.tar.gz
			;;
		*)
			exit 1
			;;
	esac
	: ${orig:=${pkgname}_$pkgver.orig.tar.gz}
	cd projects/distro-packaging/ppa
	test -f $orig || curl -fsSL $source -o $orig
	rm -rf $archive
	test -d $archive || tar xfva $orig
	cd $archive
	test -d debian || bzr branch --use-existing-dir lp:$pkgname .
	_pkgver="$pkgver-${pkgrel}ppa${scriptepoch}~${DISTRIB_ID,,}$DISTRIB_RELEASE"
	: ${msg:=Build upstream release $pkgver for $DISTRIB_CODENAME}
	bzr revert debian/changelog
	dch -D $DISTRIB_CODENAME -b -v $_pkgver "$msg"
	yes | sudo mk-build-deps -i ||:
	rm -f $pkgname-build-deps_${_pkgver}_*
	debuild -S -sa
	bzr commit -m "$msg"
	bzr push :parent
	cd ..
	dput $ppa ${pkgname}_${_pkgver}_source.changes
	exit 0
fi

for animal in $zoo; do
	instance=$pkgname-$animal
	launch $instance $animal
	ssh-add -l | grep -q caleb # confirm ssh agent before start
	$GPG -s -o /dev/null <<< 'test' # confirm current agent locally before trying remote
	script=${0##$HOME/}
	ssh $(ipof $instance) -l ubuntu -tt -A -- "pkgrel=$pkgrel scriptepoch=$scriptepoch msg=\"${msg:=}\" $script $*" || continue
done
