#!/bin/sh
# Double-click in Finder to start the sprite tools page. The first time,
# macOS may ask: right-click this file, choose Open, then Open again. -Elvie
cd "$(dirname "$0")" || exit 1
sh ./launch/start.sh
status=$?
if [ $status -ne 0 ]; then
  printf "Press Return to close this window."
  read -r _
fi
