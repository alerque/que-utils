#!/usr/bin/env bash

source PKGBUILD

set -x

ver=${epoch:+${epoch}:}$pkgver-$pkgrel

pkgs=()

flunk () {
    echo "ERROR: $1"
    exit 1
}

add_pkg () {
    if [[ -f $1 && -f $1.sig ]]; then
        pkgs+=("./$1")
        pkgs+=("./$1.sig")
    else
        flunk "Expected package and signature files for $1"
    fi
}

for pkgname in ${pkgname[@]}; do
    for parch in ${arch[@]}; do
        if [[ $parch == any || $parch == x86_64 ]]; then
            add_pkg $pkgname-$ver-$parch.pkg.tar.zst
        fi
    done
done

scp ${pkgs[@]} arch.alerque.com:x86_64
