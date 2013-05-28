#!/bin/sh

sudo -v
cd ~/rpm/packages/chromium-browser-bin/
rm chromium-browser-bin.spec
cvs up chromium-browser-bin.spec
./update-source.sh
./update-source.sh
builder -nn chromium-browser-bin
poldek -n home -u chromium-browser-bin\*
