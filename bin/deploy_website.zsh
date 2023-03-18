#!/usr/bin/env zsh

set -e
set -x

srv=/srv/http

test -d "$srv"

basename $(pwd) | read site
git rev-parse --abbrev-ref HEAD | read branch

if [[ $branch != master ]]; then
	site=$branch.$site
fi

deploydir=$srv/$site

sudo mkdir -p "$deploydir"
sudo chown -R caleb:http "$deploydir"
sudo chmod g+xs "$deploydir"

# Warm up and clean with rsync
rsync -crlpv --delete \
    --exclude ".git*" \
    --exclude "*~" \
    --exclude "tags" \
    --exclude "makefile" --exclude "Makefile" --exclude ".gitlab-ci.yml" \
    --include "wp-content/uploads/.htaccess" \
    --exclude "wp-content/uploads" \
    --include "wp-content/uploads-webpc/.htaccess" \
    --exclude "wp-content/uploads-webpc" \
    --exclude "wp-content/cache" \
    --exclude "wp-content/et-cache" \
    --include "wp-content/w3tc-config/master.php" \
    --exclude "wp-content/w3tc-config" \
    --include "wp-content/webp-express/.htaccess" \
    --include "wp-content/webp-express/webp-images/.htaccess" \
    --exclude "wp-content/webp-express" \
    --exclude "wp-content/gallery" \
    ./ "$deploydir/"

# Make sure we only deployed the committed state of things with Git
git --git-dir=.git --work-tree="$deploydir" checkout -f "$branch"
git --git-dir=.git --work-tree="$deploydir" reset --hard

pushd "$deploydir"

[[ -f wp-config.php ]] && mkdir -p wp-content/uploads ||:

for dir in wp-content/uploads wp-content/uploads-webpc wp-content/gallery wp-content/cache wp-content/w3tc-config wp-content/webp-express; do
    test -d "$dir" || continue
    sudo chown -R http:http "$dir"
    find "$dir" -type f -execdir sudo chmod -x {} \+
    test -f "$dir/.htaccess" && sudo chown $(id -u):$(id -g) "$dir/.htaccess"
done
