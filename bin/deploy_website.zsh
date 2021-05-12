#!/usr/bin/env zsh

set -e
set -x

srv=/srv/http

test -d "$srv"

basename $(pwd) | read site
git rev-parse --abbrev-ref HEAD | read branch

deploydir="$srv/$site"

sudo mkdir -p "$deploydir"
sudo chown -R caleb:http "$deploydir"
sudo chmod g+xs "$deploydir"

git --git-dir=.git --work-tree="$deploydir" checkout -f "$branch"
git --git-dir=.git --work-tree="$deploydir" reset --hard
