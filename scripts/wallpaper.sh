#!/bin/bash

shopt -s nullglob
cd /mnt/ghost/Wallpapers/BoB

while true; do
	files=()
	for i in *.jpg *.png; do
		[[ -f $i ]] && files+=("$i")
	done
	range=${#files[@]}

	((range)) && feh --bg-fill "${files[RANDOM % range]}"

	sleep 15m
done
