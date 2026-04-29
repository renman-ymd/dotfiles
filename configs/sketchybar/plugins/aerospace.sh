#!/usr/bin/env bash
# Per-workspace highlight plugin.
# Invoked by SketchyBar for each workspace item on aerospace_workspace_change.
#
# $1                  = the workspace name baked into this item (e.g. "3-code")
# $NAME               = the sketchybar item name (e.g. "space.3-code")
# $FOCUSED_WORKSPACE  = name of the now-focused workspace (set by --trigger)

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set "$NAME" \
        background.drawing=on \
        label.color=0xff24273a \
        background.color=0xffc6a0f6
else
    sketchybar --set "$NAME" \
        background.drawing=off \
        label.color=0xffcad3f5
fi
