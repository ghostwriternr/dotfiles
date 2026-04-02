#!/usr/bin/env bash
PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | head -1 | tr -d '%')
CHARGING=$(pmset -g batt | grep 'AC Power')
if [ -n "$CHARGING" ]; then
  ICON=$(printf '\xef\x83\xa7')
elif [ "${PERCENTAGE:-0}" -gt 80 ]; then ICON=$(printf '\xef\x89\x80')
elif [ "${PERCENTAGE:-0}" -gt 60 ]; then ICON=$(printf '\xef\x89\x81')
elif [ "${PERCENTAGE:-0}" -gt 40 ]; then ICON=$(printf '\xef\x89\x82')
elif [ "${PERCENTAGE:-0}" -gt 20 ]; then ICON=$(printf '\xef\x89\x83')
else ICON=$(printf '\xef\x89\x84')
fi
sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE:-?}%"
