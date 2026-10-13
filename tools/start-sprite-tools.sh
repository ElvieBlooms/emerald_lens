#!/bin/sh
# Starts the sprite tools page on Linux: run it from a terminal
# (sh start-sprite-tools.sh), or allow it to run as a program in your
# file manager and double-click it. -Elvie
cd "$(dirname "$0")" || exit 1
exec sh ./launch/start.sh
