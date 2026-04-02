#!/usr/bin/env bash
# Source theme colors directly (plugins run as separate processes,
# not child shells of sketchybarrc -- exported vars aren't inherited)
source "$HOME/.config/theme/current.sh"
OCCUPIED="0xff${THEME_GREY2#\#}"
INACTIVE="0xff${THEME_GREY0#\#}"

if [ "$SELECTED" = "true" ]; then
  sketchybar --set "$NAME" icon.highlight=on
else
  # Check if space has windows (occupied vs empty)
  SPACE_ID="${NAME#space.}"
  WINDOWS=$(yabai -m query --spaces --space "$SPACE_ID" 2>/dev/null | jq '.windows | length' 2>/dev/null)
  if [ "${WINDOWS:-0}" -gt 0 ]; then
    sketchybar --set "$NAME" icon.highlight=off icon.color="$OCCUPIED"
  else
    sketchybar --set "$NAME" icon.highlight=off icon.color="$INACTIVE"
  fi
fi
