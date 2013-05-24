#!/bin/zsh

cd /tmp
fn="wm_$(date +%s).jpg"
curl http://www.opentopia.com/images/data/sunlight/world_sunlight_map_rectangular.jpg > $fn

case $(hostname) in
	sincap.local)
		bg="{default = {ImageFilePath = \"/tmp/$fn\"; };}"
		defaults write com.apple.desktop Background $bg
		killall Dock
		;;
	*)
		[[ -z $DISPLAY ]] && export DISPLAY=:0
		feh --bg-fill $fn
		;;
esac
